// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title StateRootCommitter
 * @notice Generates and batches Merkle state roots on Rayls L1 for anchoring to Ethereum
 *
 * This contract runs on Rayls L1 and:
 * 1. Computes Merkle roots of block state every N blocks
 * 2. Batches commitments to reduce Ethereum gas costs
 * 3. Emits events for the relayer to pick up and submit to Ethereum
 */
contract StateRootCommitter is Ownable {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Commitment {
        bytes32 stateRoot;           // Merkle root of state
        uint256 blockNumber;         // Rayls block number
        uint256 timestamp;           // Rayls block timestamp
        bool committed;              // Whether committed to Ethereum
        bytes32 ethereumTxHash;      // Ethereum tx that anchored this (set by relayer)
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event StateRootGenerated(
        uint256 indexed blockNumber,
        bytes32 indexed stateRoot,
        uint256 timestamp
    );

    event StateRootCommitted(
        uint256 indexed blockNumber,
        bytes32 indexed stateRoot,
        uint256 batchSize,
        uint256 timestamp
    );

    event CommitmentAnchored(
        uint256 indexed blockNumber,
        bytes32 indexed ethereumTxHash
    );

    event CommitterAdded(address indexed committer);
    event CommitterRemoved(address indexed committer);
    event BatchIntervalUpdated(uint256 oldInterval, uint256 newInterval);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    // Mapping from block number to commitment
    mapping(uint256 => Commitment) public commitments;

    // Array of all committed block numbers (for iteration)
    uint256[] public committedBlocks;

    // Last block number that was committed
    uint256 public lastCommittedBlock;

    // Batch interval - commit every N blocks
    uint256 public batchInterval;

    // Authorized committers (validators or designated addresses)
    mapping(address => bool) public authorizedCommitters;

    // Total number of commitments
    uint256 public commitmentCount;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error InvalidBlockNumber();
    error InvalidStateRoot();
    error AlreadyCommitted();
    error CommitmentNotFound();
    error InvalidBatchInterval();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param _initialCommitter Initial authorized committer address
     * @param _batchInterval Number of blocks between commitments (e.g., 10)
     */
    constructor(address _initialCommitter, uint256 _batchInterval) Ownable(msg.sender) {
        if (_batchInterval == 0) revert InvalidBatchInterval();

        batchInterval = _batchInterval;
        authorizedCommitters[_initialCommitter] = true;

        emit CommitterAdded(_initialCommitter);
        emit BatchIntervalUpdated(0, _batchInterval);
    }

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAuthorizedCommitter() {
        if (!authorizedCommitters[msg.sender]) revert Unauthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                         STATE ROOT GENERATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Generate and store state root for current block
     * @dev Called by authorized committers (e.g., validators after block finality)
     * @param _stateRoot Merkle root of current block state
     * @param _blockNumber Block number for this state root
     */
    function generateStateRoot(bytes32 _stateRoot, uint256 _blockNumber)
        external
        onlyAuthorizedCommitter
    {
        // Validation
        if (_stateRoot == bytes32(0)) revert InvalidStateRoot();
        if (_blockNumber == 0) revert InvalidBlockNumber();
        if (commitments[_blockNumber].stateRoot != bytes32(0)) revert AlreadyCommitted();

        // Store commitment
        commitments[_blockNumber] = Commitment({
            stateRoot: _stateRoot,
            blockNumber: _blockNumber,
            timestamp: block.timestamp,
            committed: false,
            ethereumTxHash: bytes32(0)
        });

        committedBlocks.push(_blockNumber);
        commitmentCount++;

        emit StateRootGenerated(_blockNumber, _stateRoot, block.timestamp);

        // Check if we should batch-commit
        if (shouldCommit(_blockNumber)) {
            _commitStateRoot(_blockNumber);
        }
    }

    /**
     * @notice Check if we should commit based on batch interval
     * @param _blockNumber Block number to check
     * @return shouldCommitNow Whether to commit now
     */
    function shouldCommit(uint256 _blockNumber) public view returns (bool) {
        // Commit every batchInterval blocks
        if (lastCommittedBlock == 0) return true; // First commitment
        return (_blockNumber - lastCommittedBlock) >= batchInterval;
    }

    /**
     * @notice Internal function to mark state root for commitment
     * @dev Emits event that relayer listens to
     * @param _blockNumber Block number to commit
     */
    function _commitStateRoot(uint256 _blockNumber) internal {
        if (commitments[_blockNumber].stateRoot == bytes32(0)) revert CommitmentNotFound();

        commitments[_blockNumber].committed = true;
        lastCommittedBlock = _blockNumber;

        // Calculate batch size (how many blocks since last commitment)
        uint256 batchSize = lastCommittedBlock == 0 ? 1 : (_blockNumber - lastCommittedBlock);

        emit StateRootCommitted(
            _blockNumber,
            commitments[_blockNumber].stateRoot,
            batchSize,
            block.timestamp
        );
    }

    /**
     * @notice Manual commit (for testing or emergency)
     * @param _blockNumber Block number to commit
     */
    function commitStateRoot(uint256 _blockNumber)
        external
        onlyAuthorizedCommitter
    {
        _commitStateRoot(_blockNumber);
    }

    /**
     * @notice Called by relayer after successfully anchoring on Ethereum
     * @param _blockNumber Block number that was anchored
     * @param _ethereumTxHash Ethereum transaction hash
     */
    function markAnchored(uint256 _blockNumber, bytes32 _ethereumTxHash)
        external
        onlyAuthorizedCommitter
    {
        if (commitments[_blockNumber].stateRoot == bytes32(0)) revert CommitmentNotFound();
        if (_ethereumTxHash == bytes32(0)) revert InvalidStateRoot();

        commitments[_blockNumber].ethereumTxHash = _ethereumTxHash;

        emit CommitmentAnchored(_blockNumber, _ethereumTxHash);
    }

    /*//////////////////////////////////////////////////////////////
                         ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add authorized committer
     * @param _committer Address to authorize
     */
    function addCommitter(address _committer) external onlyOwner {
        authorizedCommitters[_committer] = true;
        emit CommitterAdded(_committer);
    }

    /**
     * @notice Remove authorized committer
     * @param _committer Address to deauthorize
     */
    function removeCommitter(address _committer) external onlyOwner {
        authorizedCommitters[_committer] = false;
        emit CommitterRemoved(_committer);
    }

    /**
     * @notice Update batch interval
     * @param _newInterval New interval in blocks
     */
    function setBatchInterval(uint256 _newInterval) external onlyOwner {
        if (_newInterval == 0) revert InvalidBatchInterval();

        uint256 oldInterval = batchInterval;
        batchInterval = _newInterval;

        emit BatchIntervalUpdated(oldInterval, _newInterval);
    }

    /*//////////////////////////////////////////////////////////////
                         VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get commitment details for a block
     * @param _blockNumber Block number to query
     * @return commitment Commitment struct
     */
    function getCommitment(uint256 _blockNumber)
        external
        view
        returns (Commitment memory)
    {
        return commitments[_blockNumber];
    }

    /**
     * @notice Get all committed block numbers
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
        if (committedBlocks.length == 0) {
            return Commitment({
                stateRoot: bytes32(0),
                blockNumber: 0,
                timestamp: 0,
                committed: false,
                ethereumTxHash: bytes32(0)
            });
        }
        return commitments[committedBlocks[committedBlocks.length - 1]];
    }

    /**
     * @notice Get commitment count
     * @return count Total number of commitments
     */
    function getCommitmentCount() external view returns (uint256) {
        return commitmentCount;
    }

    /**
     * @notice Check if address is authorized committer
     * @param _address Address to check
     * @return isAuthorized Whether address is authorized
     */
    function isAuthorizedCommitter(address _address) external view returns (bool) {
        return authorizedCommitters[_address];
    }
}
