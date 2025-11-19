pragma circom 2.1.6;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/mux1.circom";

/**
 * @title StateProofVerifier
 * @notice Merkle proof verification in zero-knowledge
 *
 * This circuit proves:
 * 1. A leaf exists in a Merkle tree with a given root
 * 2. WITHOUT revealing the leaf value or path
 *
 * Use Case: Prove account/state existence against anchored root privately
 *
 * Public Inputs:
 * - root: Merkle root (must match anchored commitment)
 * - nullifier: Unique identifier preventing double-proofs
 *
 * Private Inputs:
 * - leaf: Leaf value (account hash, balance, etc.)
 * - pathIndices: Binary path to leaf (0=left, 1=right)
 * - siblings: Sibling hashes along path
 * - secret: Secret for nullifier generation
 */
template MerkleProofVerifier(levels) {
    // Public inputs
    signal input root;                 // Merkle root (public)
    signal input nullifier;            // Prevents double-spending (public)

    // Private inputs
    signal input leaf;                 // Leaf to prove (private)
    signal input pathIndices[levels];  // Path bits (private)
    signal input siblings[levels];     // Sibling hashes (private)
    signal input secret;               // Secret for nullifier (private)

    // Intermediate signals
    signal computedHash[levels + 1];

    // Start with leaf
    computedHash[0] <== leaf;

    // Verify Merkle path
    component poseidons[levels];
    component muxes[levels];

    for (var i = 0; i < levels; i++) {
        // Determine left/right ordering
        muxes[i] = MultiMux1(2);
        muxes[i].c[0][0] <== computedHash[i];
        muxes[i].c[0][1] <== siblings[i];
        muxes[i].c[1][0] <== siblings[i];
        muxes[i].c[1][1] <== computedHash[i];
        muxes[i].s <== pathIndices[i];

        // Hash parent
        poseidons[i] = Poseidon(2);
        poseidons[i].inputs[0] <== muxes[i].out[0];
        poseidons[i].inputs[1] <== muxes[i].out[1];

        computedHash[i + 1] <== poseidons[i].out;
    }

    // Constraint 1: Computed root must match public root
    root === computedHash[levels];

    // Constraint 2: Nullifier = Poseidon(leaf, secret)
    component nullifierHasher = Poseidon(2);
    nullifierHasher.inputs[0] <== leaf;
    nullifierHasher.inputs[1] <== secret;
    nullifier === nullifierHasher.out;
}

component main {public [root, nullifier]} = MerkleProofVerifier(20);
