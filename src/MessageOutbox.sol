// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MessageOutbox
 * @notice Ethereum contract for sending censorship-resistant messages to Rayls L1
 *
 * This contract enables users to force transaction inclusion on Rayls L1
 * if validators attempt censorship.
 *
 * Flow:
 * 1. User calls sendMessage() on Ethereum
 * 2. Message is queued with unique ID
 * 3. Relayer observes event and calls MessageInbox.receiveMessage() on Rayls
 * 4. Message is processed on Rayls
 * 5. Relayer confirms by calling markProcessed()
 */
contract MessageOutbox is Ownable {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct OutboxMessage {
        uint256 messageId;           // Unique message ID
        address sender;              // Message sender
        address target;              // Target contract on Rayls
        bytes data;                  // Call data
        uint256 value;               // ETH value (future use)
        uint256 queuedAt;            // When message was queued
        uint256 processedAt;         // When message was processed (0 if not)
        bool processed;              // Whether message was processed on Rayls
        bytes32 raylsTxHash;        // Rayls tx hash that processed this
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event MessageQueued(
        uint256 indexed messageId,
        address indexed sender,
        address indexed target,
        bytes data,
        uint256 value
    );

    event MessageProcessed(
        uint256 indexed messageId,
        bytes32 indexed raylsTxHash
    );

    event RelayerAdded(address indexed relayer);
    event RelayerRemoved(address indexed relayer);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    // All outbox messages
    OutboxMessage[] public messages;

    // Next message ID
    uint256 public nextMessageId;

    // Authorized relayers (can mark messages as processed)
    mapping(address => bool) public authorizedRelayers;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error InvalidTarget();
    error MessageNotFound();
    error MessageAlreadyProcessed();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param _initialRelayer Initial authorized relayer
     */
    constructor(address _initialRelayer) Ownable(msg.sender) {
        authorizedRelayers[_initialRelayer] = true;
        emit RelayerAdded(_initialRelayer);
    }

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAuthorizedRelayer() {
        if (!authorizedRelayers[msg.sender]) revert Unauthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                         MESSAGE QUEUING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Send a message to Rayls L1 (censorship-resistant)
     * @param _target Target contract address on Rayls
     * @param _data Call data to execute on Rayls
     * @return messageId Unique message ID
     */
    function sendMessage(address _target, bytes calldata _data)
        external
        payable
        returns (uint256 messageId)
    {
        if (_target == address(0)) revert InvalidTarget();

        messageId = nextMessageId++;

        OutboxMessage memory message = OutboxMessage({
            messageId: messageId,
            sender: msg.sender,
            target: _target,
            data: _data,
            value: msg.value,
            queuedAt: block.timestamp,
            processedAt: 0,
            processed: false,
            raylsTxHash: bytes32(0)
        });

        messages.push(message);

        emit MessageQueued(messageId, msg.sender, _target, _data, msg.value);

        return messageId;
    }

    /*//////////////////////////////////////////////////////////////
                         MESSAGE PROCESSING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mark message as processed (called by relayer after Rayls execution)
     * @param _messageId Message ID that was processed
     * @param _raylsTxHash Rayls transaction hash
     */
    function markProcessed(uint256 _messageId, bytes32 _raylsTxHash)
        external
        onlyAuthorizedRelayer
    {
        if (_messageId >= messages.length) revert MessageNotFound();
        if (messages[_messageId].processed) revert MessageAlreadyProcessed();

        messages[_messageId].processed = true;
        messages[_messageId].processedAt = block.timestamp;
        messages[_messageId].raylsTxHash = _raylsTxHash;

        emit MessageProcessed(_messageId, _raylsTxHash);
    }

    /*//////////////////////////////////////////////////////////////
                         ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add authorized relayer
     * @param _relayer Address to authorize
     */
    function addRelayer(address _relayer) external onlyOwner {
        authorizedRelayers[_relayer] = true;
        emit RelayerAdded(_relayer);
    }

    /**
     * @notice Remove authorized relayer
     * @param _relayer Address to deauthorize
     */
    function removeRelayer(address _relayer) external onlyOwner {
        authorizedRelayers[_relayer] = false;
        emit RelayerRemoved(_relayer);
    }

    /*//////////////////////////////////////////////////////////////
                         VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get message by ID
     * @param _messageId Message ID
     * @return message Message struct
     */
    function getMessage(uint256 _messageId)
        external
        view
        returns (OutboxMessage memory)
    {
        if (_messageId >= messages.length) revert MessageNotFound();
        return messages[_messageId];
    }

    /**
     * @notice Get all messages
     * @return allMessages Array of all messages
     */
    function getAllMessages()
        external
        view
        returns (OutboxMessage[] memory)
    {
        return messages;
    }

    /**
     * @notice Get unprocessed messages
     * @return unprocessed Array of unprocessed messages
     */
    function getUnprocessedMessages()
        external
        view
        returns (OutboxMessage[] memory unprocessed)
    {
        // Count unprocessed
        uint256 count = 0;
        for (uint256 i = 0; i < messages.length; i++) {
            if (!messages[i].processed) count++;
        }

        // Build array
        unprocessed = new OutboxMessage[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < messages.length; i++) {
            if (!messages[i].processed) {
                unprocessed[index] = messages[i];
                index++;
            }
        }
    }

    /**
     * @notice Get total message count
     * @return count Total messages
     */
    function getMessageCount() external view returns (uint256) {
        return messages.length;
    }

    /**
     * @notice Check if message is processed
     * @param _messageId Message ID
     * @return processed Whether processed
     */
    function isMessageProcessed(uint256 _messageId)
        external
        view
        returns (bool)
    {
        if (_messageId >= messages.length) return false;
        return messages[_messageId].processed;
    }
}
