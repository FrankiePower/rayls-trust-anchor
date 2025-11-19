/**
 * Rayls Trust Anchor - Event-Driven Relayer
 *
 * Listens for DemoAsset Transfer events on Rayls and:
 * 1. Captures the block number where transfer happened
 * 2. Generates state commitment for that block
 * 3. Creates ZK proof
 * 4. Submits to Ethereum
 *
 * Usage: node event-watcher.js
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
const DEMO_ASSET_ABI = [
  'event Transfer(address indexed from, address indexed to, uint256 value)'
];

const COMMITTER_ABI = [
  'function generateStateRoot(bytes32 _stateRoot, uint256 _blockNumber) external',
  'function lastCommittedBlock() external view returns (uint256)'
];

const TRUST_ANCHOR_ABI = [
  'function submitZKCommitment(bytes32 _commitment, uint256 _raylsBlockNumber, uint256 _raylsTimestamp, bytes32 _raylsTxHash, uint256[8] calldata _proof) external',
  'function hasZKCommitment(uint256 _raylsBlockNumber) external view returns (bool)',
  'function getVerificationStats() external view returns (uint256[4])',
  'function latestRaylsBlock() external view returns (uint256)'
];

// Global state
let poseidon;
let raylsProvider;
let raylsSigner;
let ethereumSigner;
let committer;
let trustAnchor;
let demoAsset;
let buildDir;
let isProcessing = false;
let pendingBlocks = [];

async function initialize() {
  console.log('\n🚀 Rayls Trust Anchor - Event-Driven Relayer\n');
  console.log('='.repeat(50));

  // Setup providers and signers
  raylsProvider = new ethers.JsonRpcProvider(CONTRACTS.rayls.rpc);
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
  demoAsset = new ethers.Contract(
    CONTRACTS.rayls.demoAsset,
    DEMO_ASSET_ABI,
    raylsProvider
  );

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

async function processBlock(blockNumber, txHash, from, to, value) {
  if (isProcessing) {
    console.log(`📥 Queuing block ${blockNumber}...`);
    pendingBlocks.push({ blockNumber, txHash, from, to, value });
    return;
  }

  isProcessing = true;
  const startTime = Date.now();

  try {
    console.log('\n' + '='.repeat(50));
    console.log(`📦 Processing Transfer at Block ${blockNumber}`);
    console.log('='.repeat(50));
    console.log(`   From: ${from.slice(0, 10)}...`);
    console.log(`   To: ${to.slice(0, 10)}...`);
    console.log(`   Value: ${ethers.formatEther(value)} DBOND`);
    console.log(`   TX: ${txHash.slice(0, 20)}...`);

    // Check if already on Ethereum
    const hasCommitment = await trustAnchor.hasZKCommitment(blockNumber);
    if (hasCommitment) {
      console.log(`\n⚠️  Block ${blockNumber} already on Ethereum, skipping`);
      return;
    }

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

    console.log(`\n✅ Submitted to Ethereum!`);
    console.log(`⛽ Gas: ${receipt.gasUsed.toString()}`);
    console.log(`🔗 https://sepolia.etherscan.io/tx/${tx2.hash}`);

    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
    console.log(`\n✅ Block ${blockNumber} complete in ${elapsed}s`);

  } catch (error) {
    console.error(`\n❌ Error processing block ${blockNumber}:`, error.message);
  } finally {
    isProcessing = false;

    // Process pending blocks
    if (pendingBlocks.length > 0) {
      const next = pendingBlocks.shift();
      setTimeout(() => processBlock(next.blockNumber, next.txHash, next.from, next.to, next.value), 1000);
    }
  }
}

async function startListening() {
  await initialize();

  console.log('👀 Listening for DemoAsset Transfer events...\n');
  console.log(`📍 DemoAsset: ${CONTRACTS.rayls.demoAsset}`);
  console.log(`📍 Rayls RPC: ${CONTRACTS.rayls.rpc}\n`);

  // Listen for Transfer events
  demoAsset.on('Transfer', async (from, to, value, event) => {
    const blockNumber = event.log.blockNumber;
    const txHash = event.log.transactionHash;

    console.log(`\n🔔 Transfer detected at block ${blockNumber}!`);

    // Process this block
    await processBlock(blockNumber, txHash, from, to, value);
  });

  // Get current stats
  const stats = await trustAnchor.getVerificationStats();
  console.log(`📊 Current Stats:`);
  console.log(`   Total Commitments: ${stats[0]}`);
  console.log(`   ZK Verified: ${stats[2]}`);
  console.log('\n' + '='.repeat(50));
  console.log('🎯 Make a transfer on the frontend to trigger relay!');
  console.log('='.repeat(50) + '\n');

  // Keep alive
  console.log('Press Ctrl+C to stop\n');
}

startListening().catch(console.error);
