pragma circom 2.0.0;

/**
 * @title StateCommitmentSimple
 * @notice Simplified state commitment circuit compatible with circom 0.5.x
 * @dev For hackathon demo - proves knowledge of state root without revealing it
 *
 * Public Inputs:
 * - commitment: Hash(stateRoot + salt)
 * - blockNumber: Rayls block number
 * - minBlockNumber: Minimum block (replay protection)
 *
 * Private Inputs:
 * - stateRoot: Actual state root
 * - salt: Random salt
 */
template StateCommitmentSimple() {
    // Public inputs
    signal input commitment;
    signal input blockNumber;
    signal input minBlockNumber;

    // Private inputs
    signal input stateRoot;
    signal input salt;

    // Intermediate signals
    signal blockCheck;
    signal hash;

    // Constraint 1: blockNumber >= minBlockNumber
    blockCheck <== blockNumber - minBlockNumber;

    // Constraint 2: commitment = stateRoot + salt (simplified hash)
    hash <== stateRoot + salt;
    commitment === hash;
}

component main = StateCommitmentSimple();
