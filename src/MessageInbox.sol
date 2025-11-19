// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title MessageInbox
 * @notice Receives and processes cross-chain messages from Ethereum on Rayls L1
 *
 * This contract provides censorship resistance by allowing messages submitted
 * on Ethereum to be forcibly executed on Rayls L1.
 *
 * Flow:
 * 1. User submits message on Ethereum via MessageOutbox
 * 2. Relayer calls receiveMessage() to queue it on Rayls
 * 3. Message can be processed by anyone (or auto-processed)
 * 4. Prevents validator censorship
 */
contract MessageInbox is Ownable, ReentrancyGuard {
    /*/// STRUCTS ////*/

    struct Message {
        uint256 messageId;           // Unique message ID from Ethereum
        address sender;              // Original sender on Ethereum
        address target;              // Target contract on Rayls
        bytes data;                  // Call data to execute
        uint256 value;               // ETH value (for future use)
        uint256 receivedAt;          // When message was received
        uint256 processedAt;         // When message was processed (0 if not)
        bool processed;              // Whether message has been executed
        bool success;                // Whether execution succeeded
        bytes returnData;            // Return data from execution
    }

    /*/// EVENTS ///*/

    event MessageReceived(
        uint256 indexed messageId,
        address indexed sender,
        address indexed target,
        bytes data,
        uint256 value
    );

    event MessageProcessed(
        uint256 indexed messageId,
        bool success,
        bytes returnData
    );

    event RelayerAdded(address indexed relayer);
    event RelayerRemoved(address indexed relayer);

    /*/// STORAGE ///*/

    // All messages in order of arrival
    Message[] public messages;

    // Mapping from message ID to array index
    mapping(uint256 => uint256) public messageIndex;

    // Authorized relayers (can submit messages)
    mapping(address => bool) public authorizedRelayers;

    // Track which Ethereum message IDs have been received
    mapping(uint256 => bool) public receivedMessages;

    /*/// ERRORS ////*/

    error Unauthorized();
    error MessageAlreadyReceived();
    error MessageNotFound();
    error MessageAlreadyProcessed();
    error InvalidMessage();
    error ExecutionFailed();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param _initialRelayer Initial authorized relayer address
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
                         MESSAGE RECEPTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Receive a message from Ethereum
     * @dev Called by authorized relayer after observing MessageOutbox on Ethereum
     * @param _messageId Unique message ID from Ethereum
     * @param _sender Original sender on Ethereum
     * @param _target Target contract on Rayls
     * @param _data Call data to execute
     * @param _value ETH value to send (future use)
     */
    function receiveMessage(
        uint256 _messageId,
        address _sender,
        address _target,
        bytes calldata _data,
        uint256 _value
    ) external onlyAuthorizedRelayer {
        // Validation
        if (_sender == address(0)) revert InvalidMessage();
        if (_target == address(0)) revert InvalidMessage();
        if (receivedMessages[_messageId]) revert MessageAlreadyReceived();

        // Mark as received
        receivedMessages[_messageId] = true;

        // Create message
        Message memory message = Message({
            messageId: _messageId,
            sender: _sender,
            target: _target,
            data: _data,
            value: _value,
            receivedAt: block.timestamp,
            processedAt: 0,
            processed: false,
            success: false,
            returnData: ""
        });

        // Store message
        uint256 index = messages.length;
        messages.push(message);
        messageIndex[_messageId] = index;

        emit MessageReceived(_messageId, _sender, _target, _data, _value);
    }

    /*//////////////////////////////////////////////////////////////
                         MESSAGE PROCESSING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Process a received message
     * @dev Anyone can call this to execute queued messages
     * @param _messageId Message ID to process
     */
    function processMessage(uint256 _messageId)
        external
        nonReentrant
        returns (bool success, bytes memory returnData)
    {
        if (!receivedMessages[_messageId]) revert MessageNotFound();

        uint256 index = messageIndex[_messageId];
        Message storage message = messages[index];

        if (message.processed) revert MessageAlreadyProcessed();

        // Mark as processed
        message.processed = true;
        message.processedAt = block.timestamp;

        // Execute call to target contract
        (success, returnData) = message.target.call{value: message.value}(message.data);

        // Store result
        message.success = success;
        message.returnData = returnData;

        emit MessageProcessed(_messageId, success, returnData);

        return (success, returnData);
    }

    /**
     * @notice Batch process multiple messages
     * @param _messageIds Array of message IDs to process
     */
    function batchProcessMessages(uint256[] calldata _messageIds)
        external
        nonReentrant
    {
        for (uint256 i = 0; i < _messageIds.length; i++) {
            uint256 messageId = _messageIds[i];

            if (!receivedMessages[messageId]) continue;

            uint256 index = messageIndex[messageId];
            Message storage message = messages[index];

            if (message.processed) continue;

            // Mark as processed
            message.processed = true;
            message.processedAt = block.timestamp;

            // Execute call to target contract
            (bool success, bytes memory returnData) =
                message.target.call{value: message.value}(message.data);

            // Store result
            message.success = success;
            message.returnData = returnData;

            emit MessageProcessed(messageId, success, returnData);
        }
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
     * @param _messageId Message ID to query
     * @return message Message struct
     */
    function getMessage(uint256 _messageId)
        external
        view
        returns (Message memory)
    {
        if (!receivedMessages[_messageId]) revert MessageNotFound();
        return messages[messageIndex[_messageId]];
    }

    /**
     * @notice Get all messages
     * @return allMessages Array of all messages
     */
    function getAllMessages() external view returns (Message[] memory) {
        return messages;
    }

    /**
     * @notice Get unprocessed messages
     * @return unprocessed Array of unprocessed messages
     */
    function getUnprocessedMessages()
        external
        view
        returns (Message[] memory unprocessed)
    {
        // Count unprocessed
        uint256 count = 0;
        for (uint256 i = 0; i < messages.length; i++) {
            if (!messages[i].processed) count++;
        }

        // Build array
        unprocessed = new Message[](count);
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
     * @return count Total number of messages
     */
    function getMessageCount() external view returns (uint256) {
        return messages.length;
    }

    /**
     * @notice Check if message has been received
     * @param _messageId Message ID to check
     * @return received Whether message has been received
     */
    function isMessageReceived(uint256 _messageId) external view returns (bool) {
        return receivedMessages[_messageId];
    }

    /**
     * @notice Check if message has been processed
     * @param _messageId Message ID to check
     * @return processed Whether message has been processed
     */
    function isMessageProcessed(uint256 _messageId)
        external
        view
        returns (bool)
    {
        if (!receivedMessages[_messageId]) return false;
        return messages[messageIndex[_messageId]].processed;
    }
}
