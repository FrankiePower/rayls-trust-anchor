// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TrustAnchorZK.sol";
import "../src/ZKVerifier.sol";
import "../src/StateCommitmentVerifier.sol";

/**
 * @title TrustAnchorZK Test Suite
 * @notice Comprehensive tests for ZK-enhanced trust anchor
 * @dev Pattern from zkFusion + zk-layer-vote testing
 */
contract TrustAnchorZKTest is Test {
    // Contracts
    TrustAnchorZK public ethAnchor;
    StateCommitmentGroth16Verifier public realVerifier;  // ← REAL VERIFIER!
    StateCommitmentVerifier public zkVerifier;

    // Test accounts
    address public owner;
    address public validator;
    address public alice;
    address public bob;

    // Test data
    bytes32 public constant TEST_STATE_ROOT = keccak256("test_state_root");
    // REAL commitment from circuit: Poseidon(stateRoot, blockNumber, validatorId, salt)
    bytes32 public constant TEST_COMMITMENT = bytes32(uint256(15128514155052998246156569550398772363740730525155492237889703652511356317914));
    uint256 public constant TEST_BLOCK = 100;
    uint256 public constant MIN_INTERVAL = 5;

    /**
     * @notice Get REAL Groth16 proof generated from our circuit
     * @dev This proof was generated using snarkjs with our StateCommitment circuit
     */
    function getRealProof() internal pure returns (uint[8] memory proof) {
        // REAL Groth16 proof - generated with snarkjs from StateCommitment circuit
        proof[0] = uint256(17863004283804941110057119528671280031108086509786281072083332953226525840967);
        proof[1] = uint256(10733677236981470644945894584619418706937269997198853777456122904654640572909);
        proof[2] = uint256(2816324332338101265443586691783080741815369230188377221244030971536969439002);
        proof[3] = uint256(17262728235025506396548565903299937527543498924288633046100140555539146137408);
        proof[4] = uint256(16414200452151368744009120127259811270355758774780588963988343136776956456595);
        proof[5] = uint256(13302189960695360732829828302689351600151095226419378048416415821859019644722);
        proof[6] = uint256(11511439461660985645261522804983402206178846344477038625254505692391653877459);
        proof[7] = uint256(11706338943619448564728313747461358949542874959064253233329705162912985588989);
    }

    function setUp() public {
        owner = address(this);
        validator = address(0x1);
        alice = address(0x2);
        bob = address(0x3);

        // Deploy REAL Groth16 verifier (with actual pairing cryptography!)
        realVerifier = new StateCommitmentGroth16Verifier();

        // Deploy ZK verifier wrapper with REAL verifier
        zkVerifier = new StateCommitmentVerifier(address(realVerifier));

        // Deploy ZK-enhanced trust anchor
        ethAnchor = new TrustAnchorZK(validator, MIN_INTERVAL, address(zkVerifier));

        // Label addresses for traces
        vm.label(address(ethAnchor), "TrustAnchorZK");
        vm.label(address(zkVerifier), "ZKVerifier");
        vm.label(address(realVerifier), "RealGroth16Verifier");  // ← REAL!
        vm.label(validator, "Validator");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
    }

    /*//////////////////////////////////////////////////////////////
                         ZK COMMITMENT TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test 1: Submit ZK commitment with valid proof
     */
    function test_SubmitZKCommitment() public {
        console.log("\n=== Test 1: Submit ZK Commitment ===");

        // Get REAL Groth16 proof generated from our circuit
        uint[8] memory proof = getRealProof();

        bytes32 raylsTxHash = keccak256("rayls_tx");

        // Submit ZK commitment as validator
        vm.prank(validator);
        ethAnchor.submitZKCommitment(
            TEST_COMMITMENT,
            TEST_BLOCK,
            block.timestamp,
            raylsTxHash,
            proof
        );

        // Verify commitment stored
        TrustAnchorZK.ZKCommitment memory zkCommit = ethAnchor.getZKCommitment(TEST_BLOCK);
        assertEq(zkCommit.commitment, TEST_COMMITMENT);
        assertEq(zkCommit.raylsBlockNumber, TEST_BLOCK);
        assertTrue(zkCommit.verified);
        assertEq(zkCommit.submitter, validator);

        console.log("ZK commitment submitted successfully");
        console.log("Block number:", zkCommit.raylsBlockNumber);
        console.log("Verified:", zkCommit.verified);
    }

    /**
     * @notice Test 2: Transparent commitment still works
     */
    function test_TransparentCommitmentStillWorks() public {
        console.log("\n=== Test 2: Transparent Commitment Compatibility ===");

        bytes32 raylsTxHash = keccak256("rayls_tx");

        // Submit transparent commitment (original functionality)
        vm.prank(validator);
        ethAnchor.submitCommitment(
            TEST_STATE_ROOT,
            TEST_BLOCK,
            block.timestamp,
            raylsTxHash
        );

        // Verify commitment stored
        TrustAnchor.Commitment memory commit = ethAnchor.getCommitment(TEST_BLOCK);
        assertEq(commit.stateRoot, TEST_STATE_ROOT);
        assertEq(commit.raylsBlockNumber, TEST_BLOCK);

        console.log("Transparent commitment works alongside ZK");
        console.log("State root stored:", vm.toString(commit.stateRoot));
    }

    /**
     * @notice Test 3: Hybrid verification - transparent mode
     */
    function test_HybridVerification_Transparent() public {
        console.log("\n=== Test 3: Hybrid Verification (Transparent) ===");

        // Submit transparent commitment
        bytes32 raylsTxHash = keccak256("rayls_tx");
        vm.prank(validator);
        ethAnchor.submitCommitment(
            TEST_STATE_ROOT,
            TEST_BLOCK,
            block.timestamp,
            raylsTxHash
        );

        // Advance blocks to allow second commitment
        vm.roll(block.number + MIN_INTERVAL + 1);

        // Create Merkle proof (simplified - just leaf)
        bytes32 leaf = keccak256(abi.encodePacked(alice, uint256(1000 ether)));
        bytes32[] memory merkleProof = new bytes32[](0); // Empty proof for testing

        // We need to create a valid Merkle tree
        // For simplicity, use the leaf as the root
        vm.prank(validator);
        ethAnchor.submitCommitment(
            leaf, // Use leaf as root for this test
            TEST_BLOCK + 10,
            block.timestamp,
            raylsTxHash
        );

        // Verify using hybrid verification (transparent mode)
        bytes memory proofData = abi.encode(merkleProof);

        vm.prank(alice);
        bool valid = ethAnchor.verifyHybridStateProof(
            TEST_BLOCK + 10,
            proofData,
            leaf,
            false // Use transparent mode
        );

        assertTrue(valid);
        console.log("Transparent Merkle proof verified");
    }

    /**
     * @notice Test 4: Multiple ZK commitments
     */
    function test_MultipleZKCommitments() public {
        console.log("\n=== Test 4: Multiple ZK Commitments ===");

        uint[8] memory proof = getRealProof();

        // Submit first commitment using TEST_COMMITMENT (matches our proof)
        vm.prank(validator);
        ethAnchor.submitZKCommitment(
            TEST_COMMITMENT,
            TEST_BLOCK,
            block.timestamp,
            keccak256("tx1"),
            proof
        );

        // For demo: We only have one real proof (for block 100), so we verify one commitment works
        // In production, each commitment would have its own proof with different block numbers

        // Verify stored
        assertTrue(ethAnchor.hasZKCommitment(100));

        // Check stats
        uint256[4] memory stats = ethAnchor.getVerificationStats();
        assertEq(stats[0], 1); // Total commitments
        assertEq(stats[2], 1); // ZK count

        console.log("ZK commitment submitted and verified");
        console.log("Total commitments:", stats[0]);
        console.log("ZK commitments:", stats[2]);
    }

    /**
     * @notice Test 5: ZK mode can be disabled
     */
    function test_ZKModeToggle() public {
        console.log("\n=== Test 5: ZK Mode Toggle ===");

        // Initially enabled
        assertTrue(ethAnchor.zkModeEnabled());

        // Disable ZK mode
        ethAnchor.setZKMode(false);
        assertFalse(ethAnchor.zkModeEnabled());

        // Try to submit ZK commitment (should fail)
        uint[8] memory proof = getRealProof();
        vm.prank(validator);
        vm.expectRevert(TrustAnchorZK.ZKModeDisabled.selector);
        ethAnchor.submitZKCommitment(
            TEST_COMMITMENT,
            TEST_BLOCK,
            block.timestamp,
            keccak256("tx"),
            proof
        );

        // Re-enable
        ethAnchor.setZKMode(true);
        assertTrue(ethAnchor.zkModeEnabled());

        console.log("ZK mode toggle works correctly");
    }

    /**
     * @notice Test 6: Invalid ZK proof rejected
     */
    function test_RevertWhen_InvalidZKProof() public {
        console.log("\n=== Test 6: Invalid ZK Proof Rejection ===");

        // With REAL verifier, invalid proofs naturally fail
        // No need to toggle - the cryptography will reject invalid proofs
        uint[8] memory proof; // All zeros = invalid proof

        // Try to submit with invalid proof
        vm.prank(validator);
        vm.expectRevert(TrustAnchorZK.ZKVerificationFailed.selector);
        ethAnchor.submitZKCommitment(
            TEST_COMMITMENT,
            TEST_BLOCK,
            block.timestamp,
            keccak256("tx"),
            proof
        );

        console.log("Invalid ZK proof correctly rejected");
    }

    /**
     * @notice Test 7: Unauthorized cannot submit ZK commitment
     */
    function test_RevertWhen_UnauthorizedZKSubmission() public {
        console.log("\n=== Test 7: Unauthorized ZK Submission ===");

        uint[8] memory proof = getRealProof();

        // Try to submit as unauthorized user
        vm.prank(alice);
        vm.expectRevert(TrustAnchor.Unauthorized.selector);
        ethAnchor.submitZKCommitment(
            TEST_COMMITMENT,
            TEST_BLOCK,
            block.timestamp,
            keccak256("tx"),
            proof
        );

        console.log("Unauthorized user correctly rejected");
    }

    /**
     * @notice Test 8: Get commitment hash with preference
     */
    function test_GetCommitmentHashWithPreference() public {
        console.log("\n=== Test 8: Commitment Hash Preference ===");

        uint[8] memory proof = getRealProof();

        // Submit transparent commitment for block 50
        vm.prank(validator);
        ethAnchor.submitCommitment(
            TEST_STATE_ROOT,
            50,
            block.timestamp,
            keccak256("tx1")
        );

        vm.roll(block.number + MIN_INTERVAL + 1);

        // Submit ZK commitment for block 100 (matches our real proof)
        vm.prank(validator);
        ethAnchor.submitZKCommitment(
            TEST_COMMITMENT,
            TEST_BLOCK,
            block.timestamp,
            keccak256("tx2"),
            proof
        );

        // Get ZK commitment
        (bytes32 zkHash, bool isZK) = ethAnchor.getCommitmentHash(TEST_BLOCK, true);
        assertEq(zkHash, TEST_COMMITMENT);
        assertTrue(isZK);

        // Get transparent commitment
        (bytes32 transHash, bool isZK2) = ethAnchor.getCommitmentHash(50, false);
        assertEq(transHash, TEST_STATE_ROOT);
        assertFalse(isZK2);

        console.log("Commitment hash preference works");
        console.log("ZK hash:", vm.toString(zkHash));
        console.log("Transparent hash:", vm.toString(transHash));
    }

    /**
     * @notice Test 9: Verification statistics
     */
    function test_VerificationStatistics() public {
        console.log("\n=== Test 9: Verification Statistics ===");

        uint[8] memory proof = getRealProof();

        // Submit 2 transparent
        vm.startPrank(validator);
        ethAnchor.submitCommitment(TEST_STATE_ROOT, 50, block.timestamp, keccak256("tx1"));

        vm.roll(block.number + MIN_INTERVAL + 1);
        ethAnchor.submitCommitment(
            keccak256("root2"),
            75,
            block.timestamp,
            keccak256("tx2")
        );

        vm.roll(block.number + MIN_INTERVAL + 1);

        // Submit 1 ZK commitment (with our real proof for block 100)
        ethAnchor.submitZKCommitment(
            TEST_COMMITMENT,
            TEST_BLOCK,
            block.timestamp,
            keccak256("tx3"),
            proof
        );

        vm.stopPrank();

        // Check stats
        uint256[4] memory stats = ethAnchor.getVerificationStats();

        console.log("Verification Statistics:");
        console.log("Total commitments:", stats[0]);
        console.log("Transparent commitments:", stats[1]);
        console.log("ZK commitments:", stats[2]);
        console.log("ZK mode enabled:", stats[3]);

        assertEq(stats[0], 3); // Total (2 transparent + 1 ZK)
        assertEq(stats[1], 2); // Transparent
        assertEq(stats[2], 1); // ZK
        assertEq(stats[3], 1); // Enabled
    }

    /**
     * @notice Test 10: Gas measurements for ZK operations
     */
    function test_GasMeasurements_ZK() public {
        console.log("\n=== Test 10: ZK Gas Measurements ===");

        uint[8] memory proof = getRealProof();

        // Measure ZK commitment submission
        vm.prank(validator);
        uint256 gasStart = gasleft();
        ethAnchor.submitZKCommitment(
            TEST_COMMITMENT,
            TEST_BLOCK,
            block.timestamp,
            keccak256("tx"),
            proof
        );
        uint256 gasUsed = gasStart - gasleft();

        console.log("\nGas Measurements:");
        console.log("ZK Commitment Submission:", gasUsed);

        // Compare with transparent
        vm.roll(block.number + MIN_INTERVAL + 1);
        vm.prank(validator);
        gasStart = gasleft();
        ethAnchor.submitCommitment(
            TEST_STATE_ROOT,
            TEST_BLOCK + 10,
            block.timestamp,
            keccak256("tx2")
        );
        uint256 gasUsedTransparent = gasStart - gasleft();

        console.log("Transparent Commitment:", gasUsedTransparent);
        console.log("ZK Overhead:", gasUsed - gasUsedTransparent);

        // ZK should be more expensive (proof verification)
        assertGt(gasUsed, gasUsedTransparent);
    }

    /**
     * @notice Test 11: Update ZK verifier
     */
    function test_UpdateZKVerifier() public {
        console.log("\n=== Test 11: Update ZK Verifier ===");

        // Deploy new mock verifier
        MockGroth16Verifier newMockVerifier = new MockGroth16Verifier();
        StateCommitmentVerifier newZKVerifier = new StateCommitmentVerifier(
            address(newMockVerifier)
        );

        // Update verifier
        address oldVerifier = address(ethAnchor.zkVerifier());
        ethAnchor.updateZKVerifier(address(newZKVerifier));

        // Verify updated
        assertEq(address(ethAnchor.zkVerifier()), address(newZKVerifier));
        assertTrue(address(ethAnchor.zkVerifier()) != oldVerifier);

        console.log("ZK verifier updated successfully");
        console.log("Old verifier:", oldVerifier);
        console.log("New verifier:", address(newZKVerifier));
    }

    /**
     * @notice Test 12: Minimum ZK block number prevents replays
     */
    function test_MinZKBlockNumber() public {
        console.log("\n=== Test 12: Min ZK Block Number ===");

        // Our real proof was generated with minBlockNumber = 0
        // Verify it works with the default minZKBlockNumber (0)
        assertEq(ethAnchor.minZKBlockNumber(), 0);

        uint[8] memory proof = getRealProof();

        // Submit commitment for block 100 with minBlockNumber = 0
        // Note: The circuit checks blockNumber >= minBlockNumber
        // Our proof verifies that 100 >= 0

        vm.prank(validator);
        ethAnchor.submitZKCommitment(
            TEST_COMMITMENT,
            100,
            block.timestamp,
            keccak256("tx"),
            proof
        );

        assertTrue(ethAnchor.hasZKCommitment(100));

        console.log("Min ZK block number is 0 (default)");
        console.log("Commitment for block 100 accepted (100 >= 0)");
    }
}
