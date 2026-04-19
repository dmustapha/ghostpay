// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// File: contracts/src/StreamSender.sol
// DEV-007: Deployed on same chain as PaymentRegistry (Settlement) due to
// hub-and-spoke IBC topology. Direct EVM call replaces IBC hook for first leg.
// DEV-008: msg.value doesn't work on minievm (EVM balance always 0).
// Users pre-fund contract via cosmos bank send, then createStream with amount param.

import {ICosmos} from "./interfaces/ICosmos.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface IPaymentRegistry {
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
    ) external;
    function streamReceiverAddress() external view returns (address);
    function cancelStream(bytes32 streamId) external;
}

contract StreamSender {
    ICosmos constant COSMOS = ICosmos(0x00000000000000000000000000000000000000f1);

    struct StreamInfo {
        bytes32 streamId;
        address sender;
        string senderCosmos; // DEV-008: needed for refunds via cosmos bank send
        string receiver;
        string destChannel;
        uint256 totalAmount;
        uint256 amountSent;
        uint256 tickCount;
        uint256 ratePerTick;
        uint256 startTime;
        uint256 endTime;
        bool active;
    }

    string public denom;
    address public paymentRegistry;
    uint256 private _nonce;
    uint256 public totalReserved; // total tokens reserved across all active streams

    mapping(bytes32 => StreamInfo) public streams;
    mapping(address => bytes32[]) public senderStreams;
    mapping(bytes32 => uint256) private _lastTickTime;

    event StreamCreated(bytes32 indexed streamId, address indexed sender, string receiver, uint256 totalAmount, uint256 duration);
    event TickSent(bytes32 indexed streamId, uint256 amount, uint256 tickNumber);
    event StreamCancelled(bytes32 indexed streamId, uint256 refundAmount);

    constructor(string memory _denom, address _paymentRegistry) {
        denom = _denom;
        paymentRegistry = _paymentRegistry;
    }

    /// @notice Create a payment stream. Caller must pre-fund this contract via
    ///         cosmos bank send before calling. Amount is in base denom units.
    function createStream(
        string calldata senderCosmos,
        string calldata receiver,
        string calldata destChannel,
        uint256 amount,
        uint256 durationSeconds
    ) external returns (bytes32) {
        require(amount > 0, "Amount must be positive");
        require(durationSeconds > 0, "Duration must be positive");
        // Contract must have enough unreserved balance (checked via cosmos query would be ideal,
        // but for simplicity we trust the user pre-funded and track reservations)

        bytes32 streamId = keccak256(abi.encodePacked(msg.sender, _nonce++));
        uint256 tickInterval = 30; // 30 seconds per tick
        uint256 totalTicks = durationSeconds / tickInterval;
        if (totalTicks == 0) totalTicks = 1;
        uint256 ratePerTick = amount / totalTicks;
        require(ratePerTick > 0, "Amount too small for tick rate");

        streams[streamId] = StreamInfo({
            streamId: streamId,
            sender: msg.sender,
            senderCosmos: senderCosmos,
            receiver: receiver,
            destChannel: destChannel,
            totalAmount: amount,
            amountSent: 0,
            tickCount: 0,
            ratePerTick: ratePerTick,
            startTime: block.timestamp,
            endTime: block.timestamp + durationSeconds,
            active: true
        });
        senderStreams[msg.sender].push(streamId);
        totalReserved += amount;

        emit StreamCreated(streamId, msg.sender, receiver, amount, durationSeconds);
        return streamId;
    }

    uint256 public constant MIN_TICK_INTERVAL = 15; // seconds

    function sendTick(bytes32 streamId) external {
        StreamInfo storage s = streams[streamId];
        require(msg.sender == s.sender, "Not stream owner");
        require(s.active, "Stream not active");
        // Allow final tick even if slightly past endTime (timer drift tolerance)
        require(s.amountSent < s.totalAmount, "Stream fully sent");
        require(s.amountSent == 0 || block.timestamp >= _lastTickTime[streamId] + MIN_TICK_INTERVAL, "Tick too soon");

        uint256 remaining = s.totalAmount - s.amountSent;
        uint256 tickAmount = s.ratePerTick > remaining ? remaining : s.ratePerTick;
        require(tickAmount > 0, "Nothing to send");

        s.amountSent += tickAmount;
        _lastTickTime[streamId] = block.timestamp;
        s.tickCount += 1;
        uint256 tickNumber = s.tickCount;
        totalReserved -= tickAmount; // decrement per tick, not just on completion

        if (s.amountSent >= s.totalAmount) {
            s.active = false;
        }

        // DEV-007: Direct call to PaymentRegistry on same chain
        _sendToRegistry(s, tickAmount, tickNumber);
        emit TickSent(streamId, tickAmount, tickNumber);
    }

    function cancelStream(bytes32 streamId) external {
        StreamInfo storage s = streams[streamId];
        require(s.sender == msg.sender, "Not stream owner");
        require(s.active, "Stream not active");

        s.active = false;
        uint256 refund = s.totalAmount - s.amountSent;
        totalReserved -= (s.totalAmount - s.amountSent); // decrement remaining (not full amount — ticks already decremented their portion)

        if (refund > 0) {
            // DEV-008: Refund via cosmos bank send (not payable.transfer)
            string memory contractCosmos = COSMOS.to_cosmos_address(address(this));
            string memory msgSend = string(abi.encodePacked(
                '{"@type":"/cosmos.bank.v1beta1.MsgSend",',
                '"from_address":"', contractCosmos, '",',
                '"to_address":"', s.senderCosmos, '",',
                '"amount":[{"denom":"', denom, '","amount":"', Strings.toString(refund), '"}]}'
            ));
            require(COSMOS.execute_cosmos(msgSend, 500000), "Cosmos refund failed");
        }

        IPaymentRegistry(paymentRegistry).cancelStream(streamId);
        emit StreamCancelled(streamId, refund);
    }

    function getStreamInfo(bytes32 streamId) external view returns (StreamInfo memory) {
        return streams[streamId];
    }

    function getSenderStreams(address sender) external view returns (bytes32[] memory) {
        return senderStreams[sender];
    }

    function _sendToRegistry(StreamInfo storage s, uint256 amount, uint256 tickNumber) internal {
        // DEV-009: Cosmos execute_cosmos queues msgs, they execute AFTER EVM returns.
        // So we can't chain: send-to-Registry → Registry-send-to-Receiver (2nd fails, no balance yet).
        // Fix: StreamSender sends tokens directly to StreamReceiver, and calls
        // PaymentRegistry for bookkeeping only (no token movement in Registry).
        _sendTokensToReceiver(amount);
        _notifyRegistry(s, amount, tickNumber);
    }

    function _sendTokensToReceiver(uint256 amount) internal {
        string memory contractCosmos = COSMOS.to_cosmos_address(address(this));
        string memory receiverCosmos = COSMOS.to_cosmos_address(IPaymentRegistry(paymentRegistry).streamReceiverAddress());

        string memory msgSend = string(abi.encodePacked(
            '{"@type":"/cosmos.bank.v1beta1.MsgSend",',
            '"from_address":"', contractCosmos, '",',
            '"to_address":"', receiverCosmos, '",',
            '"amount":[{"denom":"', denom, '","amount":"', Strings.toString(amount), '"}]}'
        ));

        // DEV-003: execute_cosmos requires (string, uint64) on minievm v1.2.15
        require(COSMOS.execute_cosmos(msgSend, 500000), "Cosmos bank send failed");
    }

    function _notifyRegistry(StreamInfo storage s, uint256 amount, uint256 tickNumber) internal {
        // Split into two-phase call to avoid stack-too-deep with 9 params
        address reg = paymentRegistry;
        bytes memory payload = abi.encodeCall(
            IPaymentRegistry.processPayment,
            (s.streamId, s.senderCosmos, s.receiver, s.destChannel, s.totalAmount, s.endTime, amount, tickNumber, s.ratePerTick)
        );
        (bool ok,) = reg.call(payload);
        require(ok, "Registry processPayment failed");
    }

    receive() external payable {}
}
