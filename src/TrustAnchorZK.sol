// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TrustAnchor.sol";
import "./ZKVerifier.sol";

/**
 * @title TrustAnchorZK
 * @notice Enhanced trust anchor with zero-knowledge proof support
 *
 * This contract extends TrustAnchor to support:
 * 1. Transparent state commitments (original functionality)
 * 2. Privacy-preserving ZK commitments (hides actual state root)
 * 3. Dual verification: Merkle proofs OR ZK proofs
 *
 * Use Cases:
 * - Transparent mode: Public auditing, debugging
 * - ZK mode: Private state anchoring, competitive advantage protection
 */
contract TrustAnchorZK is TrustAnchor {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct ZKCommitment {
        bytes32 commitment;              // Hash(stateRoot, blockNumber, validatorId, salt)
        uint256 raylsBlockNumber;        // Rayls L1 block number
        uint256 raylsTimestamp;          // Rayls L1 timestamp
        uint256 ethereumBlockNumber;     // Ethereum block number at commitment
        uint256 ethereumTimestamp;       // Ethereum timestamp at commitment
        address submitter;               // Address that submitted
        bool verified;                   // Whether ZK proof verified
        bytes32 raylsTxHash;            // Rayls transaction hash
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event ZKCommitmentSubmitted(
        uint256 indexed raylsBlockNumber,
        bytes32 indexed commitment,
        address indexed submitter,
        uint256 ethereumBlockNumber
    );

    event ZKProofVerified(
        uint256 indexed raylsBlockNumber,
        bytes32 indexed commitment,
        address indexed verifier
    );

    event VerificationModeUpdated(bool zkModeEnabled);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    // ZK commitments (private state roots)
    mapping(uint256 => ZKCommitment) public zkCommitments;

    // ZK verifier contract
    StateCommitmentVerifier public zkVerifier;

    // Whether ZK mode is enabled
    bool public zkModeEnabled;

    // Minimum block number for ZK proofs (prevents replays)
    uint256 public minZKBlockNumber;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZKModeDisabled();
    error ZKVerificationFailed();
    error ZKCommitmentNotFound();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param _initialSubmitter Initial authorized submitter
     * @param _minCommitmentInterval Minimum Ethereum blocks between commitments
     * @param _zkVerifier ZK verifier contract address
     */
    constructor(
        address _initialSubmitter,
        uint256 _minCommitmentInterval,
        address _zkVerifier
    ) TrustAnchor(_initialSubmitter, _minCommitmentInterval) {
        if (_zkVerifier != address(0)) {
            zkVerifier = StateCommitmentVerifier(_zkVerifier);
            zkModeEnabled = true;
            emit VerificationModeUpdated(true);
        }
    }

    /*//////////////////////////////////////////////////////////////
                         ZK COMMITMENT SUBMISSION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Submit a privacy-preserving ZK commitment
     * @param _commitment Hash(stateRoot, blockNumber, validatorId, salt)
     * @param _raylsBlockNumber Rayls L1 block number
     * @param _raylsTimestamp Rayls L1 block timestamp
     * @param _raylsTxHash Rayls transaction hash
     * @param _proof ZK proof of commitment validity
     */
    function submitZKCommitment(
        bytes32 _commitment,
        uint256 _raylsBlockNumber,
        uint256 _raylsTimestamp,
        bytes32 _raylsTxHash,
        uint[8] calldata _proof
    ) external onlyAuthorizedSubmitter whenNotPaused {
        if (!zkModeEnabled) revert ZKModeDisabled();

        // Validation
        if (_commitment == bytes32(0)) revert InvalidStateRoot();
        if (_raylsBlockNumber == 0) revert InvalidBlockNumber();
        if (_raylsBlockNumber <= latestRaylsBlock) revert InvalidBlockNumber();

        // Check minimum interval (Ethereum blocks)
        if (lastCommitmentEthBlock > 0) {
            if (block.number - lastCommitmentEthBlock < minCommitmentInterval) {
                revert CommitmentTooSoon();
            }
        }

        // Verify ZK proof
        bool valid = zkVerifier.verifyStateCommitmentView(
            _proof,
            _commitment,
            _raylsBlockNumber,
            minZKBlockNumber
        );

        if (!valid) revert ZKVerificationFailed();

        // Create ZK commitment
        ZKCommitment memory zkCommit = ZKCommitment({
            commitment: _commitment,
            raylsBlockNumber: _raylsBlockNumber,
            raylsTimestamp: _raylsTimestamp,
            ethereumBlockNumber: block.number,
            ethereumTimestamp: block.timestamp,
            submitter: msg.sender,
            verified: true,
            raylsTxHash: _raylsTxHash
        });

        // Store commitment
        zkCommitments[_raylsBlockNumber] = zkCommit;
        committedBlocks.push(_raylsBlockNumber);

        // Update state
        latestRaylsBlock = _raylsBlockNumber;
        lastCommitmentEthBlock = block.number;
        commitmentCount++;

        emit ZKCommitmentSubmitted(
            _raylsBlockNumber,
            _commitment,
            msg.sender,
            block.number
        );

        emit ZKProofVerified(_raylsBlockNumber, _commitment, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                         HYBRID VERIFICATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verify state proof against either transparent or ZK commitment
     * @dev Pattern from zk-layer-vote dual proof system
     * @param _raylsBlockNumber Rayls block number
     * @param _proof Merkle proof OR ZK proof
     * @param _leaf Leaf to prove (for Merkle) or nullifier (for ZK)
     * @param _useZK Whether to use ZK verification
     * @return valid Whether proof is valid
     */
    function verifyHybridStateProof(
        uint256 _raylsBlockNumber,
        bytes calldata _proof,
        bytes32 _leaf,
        bool _useZK
    ) external returns (bool valid) {
        if (_useZK) {
            // ZK mode: Verify against ZK commitment
            if (zkCommitments[_raylsBlockNumber].commitment == bytes32(0)) {
                revert ZKCommitmentNotFound();
            }

            // Decode ZK proof (8 uint256 values)
            uint[8] memory zkProof;
            for (uint i = 0; i < 8; i++) {
                zkProof[i] = abi.decode(_proof[i*32:(i+1)*32], (uint256));
            }

            bytes32 commitment = zkCommitments[_raylsBlockNumber].commitment;

            // Verify ZK Merkle proof with nullifier
            valid = zkVerifier.verifyMerkleProof(zkProof, commitment, _leaf);

            if (!valid) revert InvalidProof();

            emit StateProofVerified(_raylsBlockNumber, _leaf, msg.sender);
        } else {
            // Transparent mode: Use parent contract's Merkle verification
            if (commitments[_raylsBlockNumber].stateRoot == bytes32(0)) {
                revert CommitmentNotFound();
            }

            bytes32 root = commitments[_raylsBlockNumber].stateRoot;
            bytes32[] memory merkleProof = abi.decode(_proof, (bytes32[]));

            valid = MerkleProof.verify(merkleProof, root, _leaf);

            if (!valid) revert InvalidProof();

            emit StateProofVerified(_raylsBlockNumber, _leaf, msg.sender);
        }

        return valid;
    }

    /*//////////////////////////////////////////////////////////////
                         ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Enable/disable ZK mode
     * @param _enabled Whether to enable ZK mode
     */
    function setZKMode(bool _enabled) external onlyOwner {
        zkModeEnabled = _enabled;
        emit VerificationModeUpdated(_enabled);
    }

    /**
     * @notice Update ZK verifier contract
     * @param _newVerifier New verifier address
     */
    function updateZKVerifier(address _newVerifier) external onlyOwner {
        if (_newVerifier == address(0)) revert InvalidStateRoot();
        zkVerifier = StateCommitmentVerifier(_newVerifier);
    }

    /**
     * @notice Update minimum ZK block number
     * @param _newMinBlock New minimum block
     */
    function setMinZKBlockNumber(uint256 _newMinBlock) external onlyOwner {
        minZKBlockNumber = _newMinBlock;
    }

    /*//////////////////////////////////////////////////////////////
                         VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get ZK commitment for a Rayls block
     * @param _raylsBlockNumber Rayls block number
     * @return zkCommit ZK commitment struct
     */
    function getZKCommitment(uint256 _raylsBlockNumber)
        external
        view
        returns (ZKCommitment memory)
    {
        return zkCommitments[_raylsBlockNumber];
    }

    /**
     * @notice Check if block has ZK commitment
     * @param _raylsBlockNumber Rayls block number
     * @return hasZK Whether block has ZK commitment
     */
    function hasZKCommitment(uint256 _raylsBlockNumber)
        external
        view
        returns (bool)
    {
        return zkCommitments[_raylsBlockNumber].commitment != bytes32(0);
    }

    /**
     * @notice Get commitment (transparent or ZK)
     * @param _raylsBlockNumber Rayls block number
     * @param _preferZK Whether to prefer ZK commitment if both exist
     * @return commitment Commitment hash
     * @return isZK Whether returned commitment is ZK
     */
    function getCommitmentHash(uint256 _raylsBlockNumber, bool _preferZK)
        external
        view
        returns (bytes32 commitment, bool isZK)
    {
        if (_preferZK && zkCommitments[_raylsBlockNumber].commitment != bytes32(0)) {
            return (zkCommitments[_raylsBlockNumber].commitment, true);
        } else if (commitments[_raylsBlockNumber].stateRoot != bytes32(0)) {
            return (commitments[_raylsBlockNumber].stateRoot, false);
        } else {
            return (bytes32(0), false);
        }
    }

    /**
     * @notice Get verification statistics
     * @return stats [totalCommitments, transparentCount, zkCount, zkModeEnabled]
     */
    function getVerificationStats()
        external
        view
        returns (uint256[4] memory stats)
    {
        uint256 zkCount = 0;
        uint256 transparentCount = 0;

        for (uint256 i = 0; i < committedBlocks.length; i++) {
            uint256 blockNum = committedBlocks[i];
            if (zkCommitments[blockNum].commitment != bytes32(0)) {
                zkCount++;
            }
            if (commitments[blockNum].stateRoot != bytes32(0)) {
                transparentCount++;
            }
        }

        stats[0] = commitmentCount;
        stats[1] = transparentCount;
        stats[2] = zkCount;
        stats[3] = zkModeEnabled ? 1 : 0;

        return stats;
    }
}
