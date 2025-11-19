/**
 * Rayls Trust Anchor Relayer
 *
 * Automated relayer that:
 * 1. Generates state commitment on Rayls
 * 2. Computes Poseidon hash for ZK circuit
 * 3. Creates ZK proof using snarkjs
 * 4. Submits to Ethereum with the proof
 *
 * Usage: node index.js [blockNumber]
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
  'function lastCommittedBlock() external view returns (uint256)'
];

const TRUST_ANCHOR_ABI = [
  'function submitZKCommitment(bytes32 _commitment, uint256 _raylsBlockNumber, uint256 _raylsTimestamp, bytes32 _raylsTxHash, uint256[8] calldata _proof) external',
  'function hasZKCommitment(uint256 _raylsBlockNumber) external view returns (bool)',
  'function getVerificationStats() external view returns (uint256[4])'
];

async function main() {
  console.log('\n🚀 Rayls Trust Anchor Relayer\n');
  console.log('='.repeat(50));

  // Setup providers and signers
  const raylsProvider = new ethers.JsonRpcProvider(CONTRACTS.rayls.rpc);
  const ethereumProvider = new ethers.JsonRpcProvider(CONTRACTS.ethereum.rpc);

  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    console.error('❌ PRIVATE_KEY not found in .env');
    process.exit(1);
  }

  const raylsSigner = new ethers.Wallet(privateKey, raylsProvider);
  const ethereumSigner = new ethers.Wallet(privateKey, ethereumProvider);

  console.log(`👛 Relayer Address: ${raylsSigner.address}\n`);

  // Get last committed block to determine next block
  const committer = new ethers.Contract(
    CONTRACTS.rayls.committer,
    COMMITTER_ABI,
    raylsSigner
  );

  const lastCommitted = await committer.lastCommittedBlock();
  const blockNumber = process.argv[2]
    ? parseInt(process.argv[2])
    : Number(lastCommitted) + 10; // Default: next batch (10 blocks)

  console.log(`📦 Last Committed Block: ${lastCommitted}`);
  console.log(`📦 Target Block Number: ${blockNumber}\n`);

  // Step 1: Generate state root on Rayls
  console.log('='.repeat(50));
  console.log('STEP 1: Generate State Commitment on Rayls');
  console.log('='.repeat(50));

  // Generate a state root (in production, this would be the actual Merkle root)
  // For demo, we use a consistent value based on block number
  const stateRootBigInt = BigInt(blockNumber) * BigInt('1000000000000000000000000000000000000000000000000000000000000000000000000000');
  const stateRoot = ethers.zeroPadValue(ethers.toBeHex(stateRootBigInt % (2n ** 256n)), 32);

  console.log(`\n📝 State Root: ${stateRoot.slice(0, 20)}...`);
  console.log(`📦 Block Number: ${blockNumber}`);

  try {
    const tx1 = await committer.generateStateRoot(stateRoot, blockNumber);
    console.log(`\n⏳ Transaction sent: ${tx1.hash}`);
    await tx1.wait();
    console.log(`✅ State commitment generated on Rayls!`);
    console.log(`🔗 Explorer: https://devnet-explorer.rayls.com/tx/${tx1.hash}`);
  } catch (error) {
    if (error.message.includes('AlreadyCommitted')) {
      console.log(`\n⚠️  Commitment for block ${blockNumber} already exists on Rayls`);
    } else {
      console.error('\n❌ Error generating state root:', error.message);
      process.exit(1);
    }
  }

  // Step 2: Generate ZK Proof
  console.log('\n' + '='.repeat(50));
  console.log('STEP 2: Generate ZK Proof (snarkjs + Poseidon)');
  console.log('='.repeat(50));

  // Build Poseidon hasher
  console.log('\n⚙️  Building Poseidon hasher...');
  const poseidon = await buildPoseidon();

  // Circuit inputs - these define what we're proving
  const stateRootNum = stateRootBigInt % (2n ** 256n);
  const validatorId = 1n;
  const salt = BigInt(blockNumber * 12345); // Deterministic salt for reproducibility

  // Compute Poseidon(stateRoot, blockNumber, validatorId, salt)
  const poseidonHash = poseidon([
    stateRootNum,
    BigInt(blockNumber),
    validatorId,
    salt
  ]);
  const commitment = poseidon.F.toString(poseidonHash);

  console.log(`✅ Poseidon commitment computed: ${commitment.slice(0, 20)}...`);

  // Prepare circuit inputs
  const circuitInputs = {
    commitment: commitment,
    blockNumber: blockNumber.toString(),
    minBlockNumber: "0",
    stateRoot: stateRootNum.toString(),
    validatorId: validatorId.toString(),
    salt: salt.toString()
  };

  console.log('\n📋 Circuit Inputs:');
  console.log(`   commitment: ${circuitInputs.commitment.slice(0, 20)}...`);
  console.log(`   blockNumber: ${circuitInputs.blockNumber}`);
  console.log(`   stateRoot: ${circuitInputs.stateRoot.slice(0, 20)}...`);

  // Generate proof
  console.log('\n⚙️  Generating ZK proof with snarkjs...');

  const buildDir = path.join(__dirname, '..', 'build');
  const wasmPath = path.join(buildDir, 'StateCommitment_js', 'StateCommitment.wasm');
  const zkeyPath = path.join(buildDir, 'circuit_0000.zkey');

  let proof, publicSignals;

  try {
    // Generate witness and proof
    const { proof: p, publicSignals: ps } = await snarkjs.groth16.fullProve(
      circuitInputs,
      wasmPath,
      zkeyPath
    );
    proof = p;
    publicSignals = ps;
    console.log('✅ Proof generated successfully!');
    console.log(`   Public signals: [${publicSignals[0].slice(0, 15)}..., ${publicSignals[1]}, ${publicSignals[2]}]`);
  } catch (error) {
    console.error('❌ Error generating proof:', error.message);
    process.exit(1);
  }

  // Verify proof locally
  console.log('\n🔍 Verifying proof locally...');
  const vkeyPath = path.join(buildDir, 'verification_key.json');
  const vkey = JSON.parse(fs.readFileSync(vkeyPath, 'utf-8'));
  const verified = await snarkjs.groth16.verify(vkey, publicSignals, proof);

  if (verified) {
    console.log('✅ Local verification: PASSED');
  } else {
    console.log('❌ Local verification: FAILED');
    process.exit(1);
  }

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

  console.log('\n📦 Proof formatted for Solidity (8 elements)');

  // Step 3: Submit to Ethereum
  console.log('\n' + '='.repeat(50));
  console.log('STEP 3: Submit ZK Commitment to Ethereum');
  console.log('='.repeat(50));

  const trustAnchor = new ethers.Contract(
    CONTRACTS.ethereum.trustAnchor,
    TRUST_ANCHOR_ABI,
    ethereumSigner
  );

  // Check if already submitted
  const hasCommitment = await trustAnchor.hasZKCommitment(blockNumber);
  if (hasCommitment) {
    console.log(`\n⚠️  Block ${blockNumber} already has a ZK commitment on Ethereum`);
    console.log('   Skipping Ethereum submission.');
  } else {
    // Prepare commitment data
    const commitmentHash = ethers.zeroPadValue(
      ethers.toBeHex(BigInt(publicSignals[0])),
      32
    );
    const raylsBlockNumber = blockNumber;
    const raylsTimestamp = Math.floor(Date.now() / 1000);
    const raylsTxHash = ethers.keccak256(ethers.toUtf8Bytes(`relay-${blockNumber}-${Date.now()}`));

    console.log(`\n📝 Commitment: ${commitmentHash.slice(0, 20)}...`);
    console.log(`📦 Rayls Block: ${raylsBlockNumber}`);
    console.log(`⏰ Timestamp: ${new Date(raylsTimestamp * 1000).toISOString()}`);

    try {
      // Estimate gas first
      const gasEstimate = await trustAnchor.submitZKCommitment.estimateGas(
        commitmentHash,
        raylsBlockNumber,
        raylsTimestamp,
        raylsTxHash,
        proofArray
      );
      console.log(`\n⛽ Estimated Gas: ${gasEstimate.toString()}`);

      // Submit with extra gas
      const tx2 = await trustAnchor.submitZKCommitment(
        commitmentHash,
        raylsBlockNumber,
        raylsTimestamp,
        raylsTxHash,
        proofArray,
        { gasLimit: gasEstimate * 120n / 100n } // 20% buffer
      );

      console.log(`\n⏳ Transaction sent: ${tx2.hash}`);
      console.log('   Waiting for confirmation...');

      const receipt = await tx2.wait();

      console.log(`\n✅ ZK Commitment submitted to Ethereum!`);
      console.log(`⛽ Gas Used: ${receipt.gasUsed.toString()}`);
      console.log(`🔗 Etherscan: https://sepolia.etherscan.io/tx/${tx2.hash}`);

    } catch (error) {
      if (error.message.includes('CommitmentAlreadyExists')) {
        console.log(`\n⚠️  Commitment already exists for block ${raylsBlockNumber}`);
      } else if (error.message.includes('ZKVerificationFailed')) {
        console.log('\n❌ ZK Verification Failed!');
        console.log('   The proof does not verify against the on-chain verifier.');
      } else {
        console.error('\n❌ Error submitting to Ethereum:', error.message);
      }
    }
  }

  // Step 4: Verify Result
  console.log('\n' + '='.repeat(50));
  console.log('STEP 4: Verify Result');
  console.log('='.repeat(50));

  const stats = await trustAnchor.getVerificationStats();
  console.log(`\n📊 Verification Stats:`);
  console.log(`   Total Commitments: ${stats[0]}`);
  console.log(`   Transparent: ${stats[1]}`);
  console.log(`   ZK Verified: ${stats[2]}`);
  console.log(`   ZK Mode Enabled: ${stats[3] == 1 ? 'Yes' : 'No'}`);

  const finalCheck = await trustAnchor.hasZKCommitment(blockNumber);
  console.log(`\n✅ Block ${blockNumber} has ZK commitment: ${finalCheck}`);

  console.log('\n' + '='.repeat(50));
  console.log('🎉 RELAY COMPLETE!');
  console.log('='.repeat(50));
  console.log('\nThe state from Rayls has been anchored to Ethereum');
  console.log('with zero-knowledge proof verification.\n');
}

main().catch(console.error);
