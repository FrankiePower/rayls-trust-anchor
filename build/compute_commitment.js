const { buildPoseidon } = await import('circomlibjs');

const poseidon = await buildPoseidon();

// Inputs matching our test
const stateRoot = 115792089237316195423570985008687907853269984665640564039457584007913129639935n;
const blockNumber = 100n;
const validatorId = 1n;
const salt = 12345n;

// Calculate Poseidon hash
const commitment = poseidon.F.toObject(poseidon([stateRoot, blockNumber, validatorId, salt]));

console.log("Commitment:", commitment.toString());
console.log("\nFull input JSON:");
console.log(JSON.stringify({
  commitment: commitment.toString(),
  blockNumber: blockNumber.toString(),
  minBlockNumber: "0",
  stateRoot: stateRoot.toString(),
  validatorId: validatorId.toString(),
  salt: salt.toString()
}, null, 2));
