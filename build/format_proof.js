import { readFileSync } from 'fs';

const proof = JSON.parse(readFileSync('build/proof.json', 'utf8'));
const publicSignals = JSON.parse(readFileSync('build/public.json', 'utf8'));

// Format for Solidity uint[8] memory proof
const solidityProof = [
  proof.pi_a[0],
  proof.pi_a[1],
  proof.pi_b[0][1],  // Note: pi_b is in reverse order for Solidity
  proof.pi_b[0][0],
  proof.pi_b[1][1],
  proof.pi_b[1][0],
  proof.pi_c[0],
  proof.pi_c[1]
];

console.log("// REAL Groth16 Proof - Generated from StateCommitment circuit");
console.log("uint[8] memory proof = [");
solidityProof.forEach((p, i) => {
  const comma = i < solidityProof.length - 1 ? ',' : '';
  console.log(`    uint256(${p})${comma}`);
});
console.log("];");

console.log("\n// Public signals (commitment, blockNumber, minBlockNumber)");
console.log(`bytes32 TEST_COMMITMENT = bytes32(uint256(${publicSignals[0]}));`);
console.log(`uint256 TEST_BLOCK = ${publicSignals[1]};`);
console.log(`uint256 MIN_BLOCK = ${publicSignals[2]};`);

console.log("\n// For reference:");
console.log(`// stateRoot (private): ${JSON.parse(readFileSync('build/input.json', 'utf8')).stateRoot}`);
console.log(`// validatorId (private): ${JSON.parse(readFileSync('build/input.json', 'utf8')).validatorId}`);
console.log(`// salt (private): ${JSON.parse(readFileSync('build/input.json', 'utf8')).salt}`);
