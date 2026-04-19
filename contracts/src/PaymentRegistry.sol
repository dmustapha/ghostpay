// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// File: contracts/src/PaymentRegistry.sol

import {ICosmos} from "./interfaces/ICosmos.sol";
import {IConnectOracle} from "./interfaces/IConnectOracle.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface IStreamReceiver {
    function onReceivePayment(bytes32 streamId, string calldata receiver, uint256 amount) external;
}

contract PaymentRegistry {
    ICosmos constant COSMOS = ICosmos(0x00000000000000000000000000000000000000f1);

    enum StreamStatus { ACTIVE, COMPLETED, CANCELLED }

    struct Stream {
        bytes32 streamId;
        string sender;
        string receiver;
        string sourceChannel;
        string destChannel;
        uint256 totalAmount;
        uint256 amountSent;
        uint256 ratePerTick;
        uint256 startTime;
        uint256 endTime;
        uint256 lastTickTime;
        uint256 usdValueTotal;
        StreamStatus status;
    }

    string public denom;
    address public oracleAddress;
    string public oraclePairId;
    address public streamReceiverAddress; // EVM address on Rollup B (for hook memo)
    address public owner;
    address public streamSenderAddress;

    mapping(bytes32 => Stream) public streams;
    mapping(string => bytes32[]) public receiverStreams; // receiver addr → stream IDs
    mapping(string => bytes32[]) public senderStreams;   // sender addr → stream IDs

    event StreamRegistered(bytes32 indexed streamId, string sender, string receiver, uint256 totalAmount);
    event PaymentProcessed(bytes32 indexed streamId, uint256 amount, uint256 usdValue, uint256 tickNumber);
    event StreamCompleted(bytes32 indexed streamId, uint256 totalSent);
    event StreamCancelled(bytes32 indexed streamId, uint256 amountSent);

    constructor(
        string memory _denom,
        address _oracleAddress,
        string memory _oraclePairId,
        address _streamReceiverAddress
    ) {
        denom = _denom;
        oracleAddress = _oracleAddress;
        oraclePairId = _oraclePairId;
        streamReceiverAddress = _streamReceiverAddress;
        owner = msg.sender;
    }

    /// @notice Called by StreamSender on same chain (DEV-007: direct call, not IBC hook)
    /// @dev Restricted to streamSenderAddress to prevent fake stream injection
    function processPayment(
        bytes32 streamId,
        string calldata sender,
        string calldata receiver,
        string calldata destChannel,
        uint256 totalAmount_,
        uint256 endTime_,
        uint256 amount,
        uint256 tickNumber,
        uint256 ratePerTick_
    ) external {
        require(msg.sender == streamSenderAddress, "Only StreamSender");
        require(amount > 0, "Zero amount");
        Stream storage s = streams[streamId];

        // Reject ticks on already-completed/cancelled streams
        if (s.startTime != 0) {
            require(s.status == StreamStatus.ACTIVE, "Stream not active");
        }

        // Register stream on first tick
        if (s.startTime == 0) {
            streams[streamId] = Stream({
                streamId: streamId,
                sender: sender,
                receiver: receiver,
                sourceChannel: "",
                destChannel: destChannel,
                totalAmount: totalAmount_,
                amountSent: 0,
                ratePerTick: ratePerTick_,
                startTime: block.timestamp,
                endTime: endTime_,
                lastTickTime: block.timestamp,
                usdValueTotal: 0,
                status: StreamStatus.ACTIVE
            });
            s = streams[streamId];
            receiverStreams[receiver].push(streamId);
            senderStreams[sender].push(streamId);
            emit StreamRegistered(streamId, sender, receiver, totalAmount_);
        }

        s.amountSent += amount;
        s.lastTickTime = block.timestamp;

        // Query oracle for USD value
        uint256 usdValue = _getUsdValue(amount);
        s.usdValueTotal += usdValue;

        emit PaymentProcessed(streamId, amount, usdValue, tickNumber);

        if (s.amountSent >= s.totalAmount) {
            s.status = StreamStatus.COMPLETED;
            emit StreamCompleted(streamId, s.amountSent);
        }

        // DEV-009: StreamSender sends tokens directly to StreamReceiver.
        // PaymentRegistry just notifies StreamReceiver for bookkeeping.
        IStreamReceiver(streamReceiverAddress).onReceivePayment(streamId, receiver, amount);
    }

    /// @notice Called by StreamSender when a stream is cancelled
    function cancelStream(bytes32 streamId) external {
        require(msg.sender == streamSenderAddress, "Not stream sender");
        Stream storage s = streams[streamId];
        require(s.startTime != 0, "Stream not registered");
        require(s.status == StreamStatus.ACTIVE, "Stream not active");
        s.status = StreamStatus.CANCELLED;
        emit StreamCancelled(streamId, s.amountSent);
    }

    function getStream(bytes32 streamId) external view returns (Stream memory) {
        return streams[streamId];
    }

    function getStreamsByReceiver(string calldata receiver) external view returns (bytes32[] memory) {
        return receiverStreams[receiver];
    }

    function getStreamsBySender(string calldata sender) external view returns (bytes32[] memory) {
        return senderStreams[sender];
    }

    event StreamSenderUpdated(address indexed oldSender, address indexed newSender);
    event OraclePairIdUpdated(string oldPairId, string newPairId);
    event DenomUpdated(string oldDenom, string newDenom);

    function setStreamSender(address _sender) external {
        require(msg.sender == owner, "Not owner");
        require(_sender != address(0), "Zero address");
        emit StreamSenderUpdated(streamSenderAddress, _sender);
        streamSenderAddress = _sender;
    }

    function setOraclePairId(string calldata newPairId) external {
        require(msg.sender == owner, "Not owner");
        emit OraclePairIdUpdated(oraclePairId, newPairId);
        oraclePairId = newPairId;
    }

    function setDenom(string calldata newDenom) external {
        require(msg.sender == owner, "Not owner");
        emit DenomUpdated(denom, newDenom);
        denom = newDenom;
    }

    function _getUsdValue(uint256 amount) internal view returns (uint256) {
        if (oracleAddress == address(0)) return 0;

        try IConnectOracle(oracleAddress).get_price(oraclePairId) returns (IConnectOracle.Price memory price) {
            return (amount * price.price) / (10 ** price.decimal);
        } catch {
            // Oracle unavailable — return 0 USD value, don't block payment
            return 0;
        }
    }

    // DEV-009: Token forwarding removed from PaymentRegistry.
    // StreamSender sends tokens directly to StreamReceiver.
    // PaymentRegistry only handles bookkeeping + oracle queries.

    receive() external payable {}
}
