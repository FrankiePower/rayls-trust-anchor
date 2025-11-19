/**
 * Rayls Trust Anchor - Automated Relayer (Watch Mode)
 *
 * Runs continuously and automatically:
 * 1. Watches for new blocks on Rayls
 * 2. Every 10 blocks, generates a state commitment
 * 3. Creates ZK proof using snarkjs + Poseidon
 * 4. Submits to Ethereum with the proof
 *
 * Usage: node watch.js [intervalSeconds]
 * Default interval: 30 seconds
 */

const { ethers } = require('ethers');
const snarkjs = require('snarkjs');
const { buildPoseidon } = require('circomlibjs');
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

// Contract addresses
const CONTRACTS = {
  rayls: {
    committer: '0x8a74cCE7275eF27306163210695f3039F820bc17',
    demoAsset: '0x509Cdd429D01C4aB64431A8b4db8735a26f031F2',
    rpc: 'https://devnet-rpc.rayls.com'
  },
  ethereum: {
    trustAnchor: '0xB512c3bf279c8222B55423f0D2375753F76dE2dC',
    rpc: 'https://eth-sepolia.g.alchemy.com/v2/xK5UUg_CThKPWlfCEDjuN_Es8wFFQ1zk'
  }
};

// ABIs
const COMMITTER_ABI = [
  'function generateStateRoot(bytes32 _stateRoot, uint256 _blockNumber) external',
  'function commitments(uint256) external view returns (bytes32 stateRoot, uint256 blockNumber, uint256 timestamp, bool committed, bytes32 ethereumTxHash)',
  'function lastCommittedBlock() external view returns (uint256)',
  'function batchInterval() external view returns (uint256)'
];

const TRUST_ANCHOR_ABI = [
  'function submitZKCommitment(bytes32 _commitment, uint256 _raylsBlockNumber, uint256 _raylsTimestamp, bytes32 _raylsTxHash, uint256[8] calldata _proof) external',
  'function hasZKCommitment(uint256 _raylsBlockNumber) external view returns (bool)',
  'function getVerificationStats() external view returns (uint256[4])',
  'function latestRaylsBlock() external view returns (uint256)'
];

// Global state
let poseidon;
let raylsSigner;
let ethereumSigner;
let committer;
let trustAnchor;
let buildDir;
let isProcessing = false;

async function initialize() {
  console.log('\n🚀 Rayls Trust Anchor - Automated Relayer\n');
  console.log('='.repeat(50));

  // Setup providers and signers
  const raylsProvider = new ethers.JsonRpcProvider(CONTRACTS.rayls.rpc);
  const ethereumProvider = new ethers.JsonRpcProvider(CONTRACTS.ethereum.rpc);

  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    console.error('❌ PRIVATE_KEY not found in .env');
    process.exit(1);
  }

  raylsSigner = new ethers.Wallet(privateKey, raylsProvider);
  ethereumSigner = new ethers.Wallet(privateKey, ethereumProvider);

  console.log(`👛 Relayer Address: ${raylsSigner.address}`);

  // Initialize contracts
  committer = new ethers.Contract(
    CONTRACTS.rayls.committer,
    COMMITTER_ABI,
    raylsSigner
  );

  trustAnchor = new ethers.Contract(
    CONTRACTS.ethereum.trustAnchor,
    TRUST_ANCHOR_ABI,
    ethereumSigner
  );

  // Build Poseidon hasher
  console.log('⚙️  Building Poseidon hasher...');
  poseidon = await buildPoseidon();

  // Set build directory
  buildDir = path.join(__dirname, '..', 'build');

  console.log('✅ Initialization complete!\n');
}

async function relay(blockNumber) {
  if (isProcessing) {
    console.log('⏳ Already processing, skipping...');
    return;
  }

  isProcessing = true;
  const startTime = Date.now();

  try {
    console.log('\n' + '='.repeat(50));
    console.log(`📦 Processing Block ${blockNumber}`);
    console.log('='.repeat(50));

    // Step 1: Generate state root on Rayls
    const stateRootBigInt = BigInt(blockNumber) * BigInt('1000000000000000000000000000000000000000000000000000000000000000000000000000');
    const stateRoot = ethers.zeroPadValue(ethers.toBeHex(stateRootBigInt % (2n ** 256n)), 32);

    console.log(`\n📝 State Root: ${stateRoot.slice(0, 20)}...`);

    try {
      const tx1 = await committer.generateStateRoot(stateRoot, blockNumber);
      console.log(`⏳ Rayls TX: ${tx1.hash.slice(0, 20)}...`);
      await tx1.wait();
      console.log(`✅ State commitment on Rayls`);
    } catch (error) {
      if (error.message.includes('AlreadyCommitted')) {
        console.log(`⚠️  Already committed on Rayls`);
      } else {
        throw error;
      }
    }

    // Step 2: Generate ZK Proof
    const stateRootNum = stateRootBigInt % (2n ** 256n);
    const validatorId = 1n;
    const salt = BigInt(blockNumber * 12345);

    const poseidonHash = poseidon([
      stateRootNum,
      BigInt(blockNumber),
      validatorId,
      salt
    ]);
    const commitment = poseidon.F.toString(poseidonHash);

    const circuitInputs = {
      commitment: commitment,
      blockNumber: blockNumber.toString(),
      minBlockNumber: "0",
      stateRoot: stateRootNum.toString(),
      validatorId: validatorId.toString(),
      salt: salt.toString()
    };

    console.log(`\n⚙️  Generating ZK proof...`);

    const wasmPath = path.join(buildDir, 'StateCommitment_js', 'StateCommitment.wasm');
    const zkeyPath = path.join(buildDir, 'circuit_0000.zkey');

    const { proof, publicSignals } = await snarkjs.groth16.fullProve(
      circuitInputs,
      wasmPath,
      zkeyPath
    );

    console.log(`✅ Proof generated`);

    // Format proof for Solidity
    const proofArray = [
      proof.pi_a[0],
      proof.pi_a[1],
      proof.pi_b[0][1],
      proof.pi_b[0][0],
      proof.pi_b[1][1],
      proof.pi_b[1][0],
      proof.pi_c[0],
      proof.pi_c[1]
    ];

    // Step 3: Submit to Ethereum
    const hasCommitment = await trustAnchor.hasZKCommitment(blockNumber);
    if (hasCommitment) {
      console.log(`⚠️  Already on Ethereum`);
    } else {
      const commitmentHash = ethers.zeroPadValue(
        ethers.toBeHex(BigInt(publicSignals[0])),
        32
      );
      const raylsTimestamp = Math.floor(Date.now() / 1000);
      const raylsTxHash = ethers.keccak256(ethers.toUtf8Bytes(`relay-${blockNumber}-${Date.now()}`));

      console.log(`\n⚙️  Submitting to Ethereum...`);

      const tx2 = await trustAnchor.submitZKCommitment(
        commitmentHash,
        blockNumber,
        raylsTimestamp,
        raylsTxHash,
        proofArray
      );

      console.log(`⏳ Ethereum TX: ${tx2.hash.slice(0, 20)}...`);
      const receipt = await tx2.wait();

      console.log(`✅ Submitted to Ethereum!`);
      console.log(`⛽ Gas: ${receipt.gasUsed.toString()}`);
      console.log(`🔗 https://sepolia.etherscan.io/tx/${tx2.hash}`);
    }

    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
    console.log(`\n✅ Block ${blockNumber} complete in ${elapsed}s`);

  } catch (error) {
    console.error(`\n❌ Error processing block ${blockNumber}:`, error.message);
  } finally {
    isProcessing = false;
  }
}

async function watch(intervalSeconds) {
  await initialize();

  const batchInterval = await committer.batchInterval();
  console.log(`📊 Batch Interval: ${batchInterval} blocks`);
  console.log(`⏰ Check Interval: ${intervalSeconds} seconds`);
  console.log('\n🔄 Starting watch mode...\n');

  let lastProcessedBlock = 0;

  const checkAndRelay = async () => {
    try {
      // Get latest from Ethereum to avoid race conditions
      const latestOnEth = Number(await trustAnchor.latestRaylsBlock());
      const lastCommitted = Number(await committer.lastCommittedBlock());

      // Next block should be greater than both Rayls and Ethereum
      const nextBlock = Math.max(latestOnEth, lastCommitted) + Number(batchInterval);

      if (nextBlock > lastProcessedBlock) {
        console.log(`\n📊 Rayls: ${lastCommitted} | Ethereum: ${latestOnEth} | Next: ${nextBlock}`);

        // Check if already on Ethereum
        const hasCommitment = await trustAnchor.hasZKCommitment(nextBlock);
        if (!hasCommitment) {
          await relay(nextBlock);
          lastProcessedBlock = nextBlock;
        } else {
          console.log(`⏭️  Block ${nextBlock} already anchored`);
          lastProcessedBlock = nextBlock;
        }
      }
    } catch (error) {
      console.error('❌ Check error:', error.message);
    }
  };

  // Initial check
  await checkAndRelay();

  // Set up interval
  setInterval(checkAndRelay, intervalSeconds * 1000);

  // Keep alive
  console.log('\n👀 Watching for new blocks... (Ctrl+C to stop)\n');
}

// Get interval from args (default 30 seconds)
const intervalSeconds = process.argv[2] ? parseInt(process.argv[2]) : 30;

watch(intervalSeconds).catch(console.error);
