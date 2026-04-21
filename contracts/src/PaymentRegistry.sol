// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// File: contracts/src/PaymentRegistry.sol

import {ICosmos} from "./interfaces/ICosmos.sol";
import {IConnectOracle} from "./interfaces/IConnectOracle.sol";
import {HexUtils} from "./lib/HexUtils.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IStreamReceiver {
    function onReceivePayment(bytes32 streamId, string calldata sender, string calldata receiver, uint256 amount) external;
}

contract PaymentRegistry is Ownable2Step, Pausable, ReentrancyGuard {
    ICosmos constant COSMOS = ICosmos(0x00000000000000000000000000000000000000f1);

    enum StreamStatus { ACTIVE, COMPLETED, CANCELLED }

    struct Stream {
        bytes32 streamId;
        string sender;
        string receiver;
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
    address public streamSenderAddress;
    address public ibcHookCaller; // IBC mode: the minievm module account that executes hook memos
    bool public ibcMode; // false = DEV-007 single-chain, true = IBC cross-rollup
    uint256 public ibcTimeoutSeconds = 300;

    mapping(bytes32 => Stream) public streams;
    mapping(string => bytes32[]) public receiverStreams; // receiver addr → stream IDs
    mapping(string => bytes32[]) public senderStreams;   // sender addr → stream IDs

    event StreamRegistered(bytes32 indexed streamId, string sender, string receiver, uint256 totalAmount);
    event PaymentProcessed(bytes32 indexed streamId, uint256 amount, uint256 usdValue, uint256 tickNumber);
    event StreamCompleted(bytes32 indexed streamId, uint256 totalSent);
    event StreamCancelled(bytes32 indexed streamId, uint256 amountSent);
    event StreamSenderUpdated(address indexed oldSender, address indexed newSender);
    event OraclePairIdUpdated(string oldPairId, string newPairId);
    event DenomUpdated(string oldDenom, string newDenom);
    event IbcHookCallerUpdated(address indexed oldCaller, address indexed newCaller);
    event IbcTimeoutUpdated(uint256 oldTimeout, uint256 newTimeout);

    constructor(
        string memory _denom,
        address _oracleAddress,
        string memory _oraclePairId,
        address _streamReceiverAddress,
        bool _ibcMode
    ) Ownable(msg.sender) {
        denom = _denom;
        oracleAddress = _oracleAddress;
        oraclePairId = _oraclePairId;
        streamReceiverAddress = _streamReceiverAddress;
        ibcMode = _ibcMode;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
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
    ) external whenNotPaused nonReentrant {
        if (ibcMode) {
            // IBC mode: hook memo is executed by the minievm module account, not StreamSender
            require(msg.sender == ibcHookCaller, "Only IBC hook caller");
        } else {
            require(msg.sender == streamSenderAddress, "Only StreamSender");
        }
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

        // H-04: Compute actual recorded amount (cap at totalAmount)
        uint256 actualAmount = amount;
        s.amountSent += amount;
        if (s.amountSent > s.totalAmount) {
            actualAmount = amount - (s.amountSent - s.totalAmount);
            s.amountSent = s.totalAmount;
        }
        s.lastTickTime = block.timestamp;

        // Query oracle for USD value
        uint256 usdValue = _getUsdValue(actualAmount);
        s.usdValueTotal += usdValue;

        emit PaymentProcessed(streamId, actualAmount, usdValue, tickNumber);

        if (s.amountSent >= s.totalAmount) {
            s.status = StreamStatus.COMPLETED;
            emit StreamCompleted(streamId, s.amountSent);
        }

        if (ibcMode) {
            // IBC cross-rollup: forward tokens to StreamReceiver on destination rollup
            _forwardViaIbc(sender, receiver, destChannel, amount, streamId);
        } else {
            // DEV-009: Single-chain — StreamSender already sent tokens directly.
            // Just notify StreamReceiver for bookkeeping.
            require(streamReceiverAddress != address(0), "Receiver not set");
            IStreamReceiver(streamReceiverAddress).onReceivePayment(streamId, sender, receiver, amount);
        }
    }

    /// @notice Called by StreamSender when a stream is cancelled
    function cancelStream(bytes32 streamId) external whenNotPaused {
        if (ibcMode) {
            require(msg.sender == streamSenderAddress || msg.sender == ibcHookCaller, "Not authorized");
        } else {
            require(msg.sender == streamSenderAddress, "Not stream sender");
        }
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

    function getStreamsByReceiverPaginated(string calldata receiver, uint256 offset, uint256 limit) external view returns (bytes32[] memory) {
        bytes32[] storage ids = receiverStreams[receiver];
        if (offset >= ids.length) return new bytes32[](0);
        uint256 end = offset + limit > ids.length ? ids.length : offset + limit;
        bytes32[] memory result = new bytes32[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = ids[i];
        }
        return result;
    }

    function getStreamsBySenderPaginated(string calldata sender, uint256 offset, uint256 limit) external view returns (bytes32[] memory) {
        bytes32[] storage ids = senderStreams[sender];
        if (offset >= ids.length) return new bytes32[](0);
        uint256 end = offset + limit > ids.length ? ids.length : offset + limit;
        bytes32[] memory result = new bytes32[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = ids[i];
        }
        return result;
    }

    function setStreamSender(address _sender) external onlyOwner {
        require(_sender != address(0), "Zero address");
        emit StreamSenderUpdated(streamSenderAddress, _sender);
        streamSenderAddress = _sender;
    }

    function setOraclePairId(string calldata newPairId) external onlyOwner {
        emit OraclePairIdUpdated(oraclePairId, newPairId);
        oraclePairId = newPairId;
    }

    function setDenom(string calldata newDenom) external onlyOwner {
        emit DenomUpdated(denom, newDenom);
        denom = newDenom;
    }

    function setIbcHookCaller(address _caller) external onlyOwner {
        require(_caller != address(0), "Zero address");
        emit IbcHookCallerUpdated(ibcHookCaller, _caller);
        ibcHookCaller = _caller;
    }

    function setIbcTimeoutSeconds(uint256 _timeout) external onlyOwner {
        require(_timeout >= 60, "Too short");
        emit IbcTimeoutUpdated(ibcTimeoutSeconds, _timeout);
        ibcTimeoutSeconds = _timeout;
    }

    /// @notice IBC mode: forward tokens from Settlement to destination rollup via MsgTransfer
    /// @dev Hook memo triggers StreamReceiver.onReceivePayment on the destination chain
    function _forwardViaIbc(
        string memory sender,
        string memory receiver,
        string memory destChannel,
        uint256 amount,
        bytes32 streamId
    ) internal {
        string memory contractCosmos = COSMOS.to_cosmos_address(address(this));
        string memory memo = _buildIbcMemo(
            HexUtils.toHexString(streamReceiverAddress),
            HexUtils.toHexString(abi.encodeCall(
                IStreamReceiver.onReceivePayment, (streamId, sender, receiver, amount)
            ))
        );
        require(COSMOS.execute_cosmos(
            _buildMsgTransfer(destChannel, Strings.toString(amount), contractCosmos, memo),
            500000
        ), "IBC forward failed");
    }

    function _buildMsgTransfer(
        string memory channel, string memory amountStr,
        string memory senderAddr, string memory memo
    ) internal view returns (string memory) {
        string memory part1 = string(abi.encodePacked(
            '{"@type":"/ibc.applications.transfer.v1.MsgTransfer",',
            '"source_port":"transfer",',
            '"source_channel":"', channel, '",',
            '"token":{"denom":"', denom, '","amount":"', amountStr, '"},'
        ));
        return string(abi.encodePacked(
            part1,
            '"sender":"', senderAddr, '",',
            '"receiver":"', senderAddr, '",',
            '"timeout_timestamp":"', Strings.toString((block.timestamp + ibcTimeoutSeconds) * 1_000_000_000), '",',
            '"memo":"', memo, '"}'
        ));
    }

    function _buildIbcMemo(string memory contractHex, string memory calldataHex) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '{\\"evm\\":{\\"async_callback\\":{\\"id\\":0,\\"contract_addr\\":\\"',
            contractHex,
            '\\",\\"input\\":\\"0x',
            calldataHex,
            '\\"}}}'
        ));
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
}
