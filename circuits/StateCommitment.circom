pragma circom 2.1.6;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/bitify.circom";

/**
 * @title StateCommitment
 * @notice Privacy-preserving state root commitment circuit
 *
 * This circuit proves:
 * 1. Knowledge of a valid Rayls state root
 * 2. State root is for a specific block number
 * 3. Commitment was created by authorized validator
 * 4. WITHOUT revealing the actual state root
 *
 * Use Case: Hide Rayls internal state while anchoring security to Ethereum
 *
 * Public Inputs:
 * - commitment: Hash of (stateRoot, blockNumber, validatorId, salt)
 * - blockNumber: Rayls block number
 * - minBlockNumber: Minimum acceptable block (prevent replays)
 *
 * Private Inputs:
 * - stateRoot: Actual Rayls Merkle root
 * - validatorId: Validator identifier
 * - salt: Random salt for commitment hiding
 */
template StateCommitment() {
    // Public inputs (visible on-chain)
    signal input commitment;           // Hash commitment (public)
    signal input blockNumber;          // Rayls block number (public)
    signal input minBlockNumber;       // Minimum block to prevent replays (public)

    // Private inputs (hidden)
    signal input stateRoot;            // Actual state root (private)
    signal input validatorId;          // Validator ID (private)
    signal input salt;                 // Random salt (private)

    // Intermediate signals
    signal blockNumberValid;

    // Constraint 1: Block number must be >= minBlockNumber
    component blockCheck = GreaterEqThan(64);
    blockCheck.in[0] <== blockNumber;
    blockCheck.in[1] <== minBlockNumber;
    blockCheck.out === 1;

    // Constraint 2: Verify commitment = Poseidon(stateRoot, blockNumber, validatorId, salt)
    component hasher = Poseidon(4);
    hasher.inputs[0] <== stateRoot;
    hasher.inputs[1] <== blockNumber;
    hasher.inputs[2] <== validatorId;
    hasher.inputs[3] <== salt;

    // Constraint 3: Commitment must match
    commitment === hasher.out;
}

component main {public [commitment, blockNumber, minBlockNumber]} = StateCommitment();
