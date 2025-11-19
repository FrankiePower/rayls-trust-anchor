// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title TrustAnchor
 * @notice Ethereum mainnet contract that anchors Rayls L1 state roots
 *
 * This contract:
 * 1. Stores state root commitments from Rayls L1
 * 2. Validates submitter signatures
 * 3. Provides historical state queries
 * 4. Enables Merkle proof verification against anchored states
 * 5. Prevents double-anchoring and replay attacks
 */
contract TrustAnchor is Ownable, Pausable {
    using ECDSA for bytes32;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Commitment {
        bytes32 stateRoot;               // Rayls L1 state root (Merkle root)
        uint256 raylsBlockNumber;        // Rayls L1 block number
        uint256 raylsTimestamp;          // Rayls L1 timestamp
        uint256 ethereumBlockNumber;     // Ethereum block number at commitment
        uint256 ethereumTimestamp;       // Ethereum timestamp at commitment
        address submitter;               // Address that submitted
        bytes32 raylsTxHash;            // Rayls transaction hash (for reference)
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event StateRootAnchored(
        uint256 indexed raylsBlockNumber,
        bytes32 indexed stateRoot,
        address indexed submitter,
        uint256 ethereumBlockNumber,
        uint256 ethereumTimestamp
    );

    event StateProofVerified(
        uint256 indexed raylsBlockNumber,
        bytes32 indexed leafHash,
        address indexed verifier
    );

    event SubmitterAdded(address indexed submitter);
    event SubmitterRemoved(address indexed submitter);
    event MinCommitmentIntervalUpdated(uint256 oldInterval, uint256 newInterval);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    // Mapping from Rayls block number to commitment
    mapping(uint256 => Commitment) public commitments;

    // Array of all committed Rayls block numbers (for iteration)
    uint256[] public committedBlocks;

    // Latest committed Rayls block number
    uint256 public latestRaylsBlock;

    // Latest committed state root
    bytes32 public latestStateRoot;

    // Authorized submitters (relayers/validators)
    mapping(address => bool) public authorizedSubmitters;

    // Minimum Ethereum blocks between commitments (prevent spam)
    uint256 public minCommitmentInterval;

    // Last Ethereum block a commitment was made
    uint256 public lastCommitmentEthBlock;

    // Total commitment count
    uint256 public commitmentCount;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error InvalidStateRoot();
    error InvalidBlockNumber();
    error CommitmentTooSoon();
    error AlreadyCommitted();
    error CommitmentNotFound();
    error InvalidProof();
    error InvalidInterval();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param _initialSubmitter Initial authorized submitter
     * @param _minCommitmentInterval Minimum Ethereum blocks between commitments
     */
    constructor(address _initialSubmitter, uint256 _minCommitmentInterval)
        Ownable(msg.sender)
    {
        if (_initialSubmitter == address(0)) revert Unauthorized();

        authorizedSubmitters[_initialSubmitter] = true;
        minCommitmentInterval = _minCommitmentInterval;

        emit SubmitterAdded(_initialSubmitter);
        emit MinCommitmentIntervalUpdated(0, _minCommitmentInterval);
    }

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAuthorizedSubmitter() {
        if (!authorizedSubmitters[msg.sender]) revert Unauthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                         STATE ROOT ANCHORING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Submit a Rayls L1 state root commitment to Ethereum
     * @param _stateRoot Merkle root of Rayls L1 state
     * @param _raylsBlockNumber Rayls L1 block number
     * @param _raylsTimestamp Rayls L1 block timestamp
     * @param _raylsTxHash Rayls transaction hash (for reference)
     */
    function submitCommitment(
        bytes32 _stateRoot,
        uint256 _raylsBlockNumber,
        uint256 _raylsTimestamp,
        bytes32 _raylsTxHash
    ) external onlyAuthorizedSubmitter whenNotPaused {
        // Validation
        if (_stateRoot == bytes32(0)) revert InvalidStateRoot();
        if (_raylsBlockNumber == 0) revert InvalidBlockNumber();
        if (_raylsBlockNumber <= latestRaylsBlock) revert InvalidBlockNumber();

        // Check minimum interval (Ethereum blocks)
        if (lastCommitmentEthBlock > 0) {
            if (block.number - lastCommitmentEthBlock < minCommitmentInterval) {
                revert CommitmentTooSoon();
            }
        }

        // Check not already committed
        if (commitments[_raylsBlockNumber].stateRoot != bytes32(0)) {
            revert AlreadyCommitted();
        }

        // Create commitment
        Commitment memory commitment = Commitment({
            stateRoot: _stateRoot,
            raylsBlockNumber: _raylsBlockNumber,
            raylsTimestamp: _raylsTimestamp,
            ethereumBlockNumber: block.number,
            ethereumTimestamp: block.timestamp,
            submitter: msg.sender,
            raylsTxHash: _raylsTxHash
        });

        // Store commitment
        commitments[_raylsBlockNumber] = commitment;
        committedBlocks.push(_raylsBlockNumber);

        // Update state
        latestRaylsBlock = _raylsBlockNumber;
        latestStateRoot = _stateRoot;
        lastCommitmentEthBlock = block.number;
        commitmentCount++;

        emit StateRootAnchored(
            _raylsBlockNumber,
            _stateRoot,
            msg.sender,
            block.number,
            block.timestamp
        );
    }

    /*//////////////////////////////////////////////////////////////
                         STATE PROOF VERIFICATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verify a Merkle proof against an anchored state root
     * @param _raylsBlockNumber Rayls block number to verify against
     * @param _proof Merkle proof
     * @param _leaf Leaf to prove inclusion of
     * @return valid Whether proof is valid
     */
    function verifyStateProof(
        uint256 _raylsBlockNumber,
        bytes32[] calldata _proof,
        bytes32 _leaf
    ) external returns (bool valid) {
        if (commitments[_raylsBlockNumber].stateRoot == bytes32(0)) {
            revert CommitmentNotFound();
        }

        bytes32 root = commitments[_raylsBlockNumber].stateRoot;
        valid = MerkleProof.verify(_proof, root, _leaf);

        if (!valid) revert InvalidProof();

        emit StateProofVerified(_raylsBlockNumber, _leaf, msg.sender);

        return valid;
    }

    /**
     * @notice View function to verify proof (no state changes)
     * @param _raylsBlockNumber Rayls block number
     * @param _proof Merkle proof
     * @param _leaf Leaf to verify
     * @return valid Whether proof is valid
     */
    function verifyStateProofView(
        uint256 _raylsBlockNumber,
        bytes32[] calldata _proof,
        bytes32 _leaf
    ) external view returns (bool) {
        if (commitments[_raylsBlockNumber].stateRoot == bytes32(0)) {
            return false;
        }

        bytes32 root = commitments[_raylsBlockNumber].stateRoot;
        return MerkleProof.verify(_proof, root, _leaf);
    }

    /**
     * @notice Verify proof against latest committed state
     * @param _proof Merkle proof
     * @param _leaf Leaf to verify
     * @return valid Whether proof is valid
     */
    function verifyLatestStateProof(bytes32[] calldata _proof, bytes32 _leaf)
        external
        view
        returns (bool)
    {
        if (latestStateRoot == bytes32(0)) return false;
        return MerkleProof.verify(_proof, latestStateRoot, _leaf);
    }

    /*//////////////////////////////////////////////////////////////
                         ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add authorized submitter
     * @param _submitter Address to authorize
     */
    function addSubmitter(address _submitter) external onlyOwner {
        if (_submitter == address(0)) revert Unauthorized();
        authorizedSubmitters[_submitter] = true;
        emit SubmitterAdded(_submitter);
    }

    /**
     * @notice Remove authorized submitter
     * @param _submitter Address to deauthorize
     */
    function removeSubmitter(address _submitter) external onlyOwner {
        authorizedSubmitters[_submitter] = false;
        emit SubmitterRemoved(_submitter);
    }

    /**
     * @notice Update minimum commitment interval
     * @param _newInterval New interval in Ethereum blocks
     */
    function setMinCommitmentInterval(uint256 _newInterval) external onlyOwner {
        uint256 oldInterval = minCommitmentInterval;
        minCommitmentInterval = _newInterval;
        emit MinCommitmentIntervalUpdated(oldInterval, _newInterval);
    }

    /**
     * @notice Pause commitments (emergency)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause commitments
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                         VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get commitment for a Rayls block
     * @param _raylsBlockNumber Rayls block number
     * @return commitment Commitment struct
     */
    function getCommitment(uint256 _raylsBlockNumber)
        external
        view
        returns (Commitment memory)
    {
        return commitments[_raylsBlockNumber];
    }

    /**
     * @notice Get all committed Rayls block numbers
     * @return blocks Array of block numbers
     */
    function getCommittedBlocks() external view returns (uint256[] memory) {
        return committedBlocks;
    }

    /**
     * @notice Get latest commitment
     * @return commitment Latest commitment struct
     */
    function getLatestCommitment() external view returns (Commitment memory) {
        if (latestRaylsBlock == 0) {
            return Commitment({
                stateRoot: bytes32(0),
                raylsBlockNumber: 0,
                raylsTimestamp: 0,
                ethereumBlockNumber: 0,
                ethereumTimestamp: 0,
                submitter: address(0),
                raylsTxHash: bytes32(0)
            });
        }
        return commitments[latestRaylsBlock];
    }

    /**
     * @notice Get commitment count
     * @return count Total commitments
     */
    function getCommitmentCount() external view returns (uint256) {
        return commitmentCount;
    }

    /**
     * @notice Check if address is authorized submitter
     * @param _address Address to check
     * @return authorized Whether address is authorized
     */
    function isAuthorizedSubmitter(address _address)
        external
        view
        returns (bool)
    {
        return authorizedSubmitters[_address];
    }

    /**
     * @notice Get state root for a Rayls block
     * @param _raylsBlockNumber Rayls block number
     * @return stateRoot State root
     */
    function getStateRoot(uint256 _raylsBlockNumber)
        external
        view
        returns (bytes32)
    {
        return commitments[_raylsBlockNumber].stateRoot;
    }
}
