// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// File: contracts/src/StreamSender.sol
// DEV-007: Deployed on same chain as PaymentRegistry (Settlement) due to
// hub-and-spoke IBC topology. Direct EVM call replaces IBC hook for first leg.
// DEV-008: msg.value doesn't work on minievm (EVM balance always 0).
// Users pre-fund contract via cosmos bank send, then createStream with amount param.

import {ICosmos} from "./interfaces/ICosmos.sol";
import {HexUtils} from "./lib/HexUtils.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

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

contract StreamSender is Ownable2Step, ReentrancyGuard, Pausable {
    ICosmos constant COSMOS = ICosmos(0x00000000000000000000000000000000000000f1);
    uint64 private constant COSMOS_GAS_LIMIT = 500_000;

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
    bool public ibcMode; // false = DEV-007 single-chain, true = IBC cross-rollup
    uint256 public ibcTimeoutSeconds = 300;
    uint256 private _nonce;
    uint256 public totalReserved; // total tokens reserved across all active streams

    mapping(bytes32 => StreamInfo) public streams;
    mapping(address => bytes32[]) public senderStreams;
    mapping(bytes32 => uint256) private _lastTickTime;

    event StreamCreated(bytes32 indexed streamId, address indexed sender, string receiver, uint256 totalAmount, uint256 duration);
    event TickSent(bytes32 indexed streamId, uint256 amount, uint256 tickNumber);
    event StreamCancelled(bytes32 indexed streamId, uint256 refundAmount);
    event IbcTimeoutUpdated(uint256 oldTimeout, uint256 newTimeout);

    constructor(string memory _denom, address _paymentRegistry, bool _ibcMode) Ownable(msg.sender) {
        denom = _denom;
        paymentRegistry = _paymentRegistry;
        ibcMode = _ibcMode;
    }

    function setIbcTimeoutSeconds(uint256 _timeout) external onlyOwner {
        require(_timeout >= 60, "Too short");
        emit IbcTimeoutUpdated(ibcTimeoutSeconds, _timeout);
        ibcTimeoutSeconds = _timeout;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Create a payment stream. Caller must pre-fund this contract via
    ///         cosmos bank send before calling. Amount is in base denom units.
    /// @dev C-5: On-chain balance verification is not possible because ICosmos.query_cosmos
    ///      returns protobuf-encoded responses that cannot be decoded in Solidity.
    ///      Safety net: execute_cosmos in sendTick will revert if the contract is underfunded,
    ///      preventing token sends that exceed the actual balance.
    function createStream(
        string calldata, // senderCosmos — ignored, derived from msg.sender for security
        string calldata receiver,
        string calldata destChannel,
        uint256 amount,
        uint256 durationSeconds
    ) external whenNotPaused returns (bytes32) {
        require(amount > 0, "Amount must be positive");
        require(durationSeconds > 0, "Duration must be positive");
        require(bytes(receiver).length > 0, "Empty receiver");
        require(bytes(destChannel).length > 0, "Empty channel");
        _validateSafeString(receiver);
        _validateSafeString(destChannel);
        // Derive senderCosmos from msg.sender to prevent refund address spoofing
        string memory senderCosmos_ = COSMOS.to_cosmos_address(msg.sender);

        bytes32 streamId = keccak256(abi.encodePacked(msg.sender, _nonce++));
        uint256 tickInterval = 30; // 30 seconds per tick
        uint256 totalTicks = durationSeconds / tickInterval;
        if (totalTicks == 0) totalTicks = 1;
        uint256 ratePerTick = amount / totalTicks;
        require(ratePerTick > 0, "Amount too small for tick rate");

        streams[streamId] = StreamInfo({
            streamId: streamId,
            sender: msg.sender,
            senderCosmos: senderCosmos_,
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

    function sendTick(bytes32 streamId) external nonReentrant whenNotPaused {
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

    function cancelStream(bytes32 streamId) external nonReentrant {
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
            require(COSMOS.execute_cosmos(msgSend, COSMOS_GAS_LIMIT), "Cosmos refund failed");
        }

        // H-2: Only call registry if stream was registered (ticks were sent)
        if (s.tickCount > 0) {
            IPaymentRegistry(paymentRegistry).cancelStream(streamId);
        }
        emit StreamCancelled(streamId, refund);
    }

    function getStreamInfo(bytes32 streamId) external view returns (StreamInfo memory) {
        return streams[streamId];
    }

    function getSenderStreams(address sender) external view returns (bytes32[] memory) {
        return senderStreams[sender];
    }

    function getSenderStreamsPaginated(address sender, uint256 offset, uint256 limit) external view returns (bytes32[] memory) {
        bytes32[] storage ids = senderStreams[sender];
        if (offset >= ids.length) return new bytes32[](0);
        uint256 end = offset + limit > ids.length ? ids.length : offset + limit;
        bytes32[] memory result = new bytes32[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = ids[i];
        }
        return result;
    }

    function _sendToRegistry(StreamInfo storage s, uint256 amount, uint256 tickNumber) internal {
        if (ibcMode) {
            // IBC cross-rollup: send tokens + hook memo via MsgTransfer to Settlement
            _sendTokensViaIbc(s, amount, tickNumber);
        } else {
            // DEV-007/009: Single-chain mode — direct bank send + EVM call
            _sendTokensToReceiver(amount);
            _notifyRegistry(s, amount, tickNumber);
        }
    }

    /// @notice IBC mode: send tokens to Settlement via MsgTransfer with EVM hook memo
    /// @dev Hook memo triggers PaymentRegistry.processPayment on the destination chain
    function _sendTokensViaIbc(StreamInfo storage s, uint256 amount, uint256 tickNumber) internal {
        // Copy storage to memory to avoid stack depth issues with via_ir
        StreamInfo memory m = s;
        string memory contractCosmos = COSMOS.to_cosmos_address(address(this));
        bytes memory calldata_ = _encodeProcessPayment(m, amount, tickNumber);
        string memory memo = _buildIbcMemo(
            HexUtils.toHexString(paymentRegistry),
            HexUtils.toHexString(calldata_)
        );
        require(COSMOS.execute_cosmos(
            _buildMsgTransfer(m.destChannel, Strings.toString(amount), contractCosmos, memo),
            COSMOS_GAS_LIMIT
        ), "IBC transfer failed");
    }

    function _encodeProcessPayment(StreamInfo memory m, uint256 amount, uint256 tickNumber) internal pure returns (bytes memory) {
        return abi.encodeCall(
            IPaymentRegistry.processPayment,
            (m.streamId, m.senderCosmos, m.receiver, m.destChannel, m.totalAmount, m.endTime, amount, tickNumber, m.ratePerTick)
        );
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

    /// @notice DEV-007: Direct bank send to StreamReceiver (single-chain mode)
    function _sendTokensToReceiver(uint256 amount) internal {
        string memory contractCosmos = COSMOS.to_cosmos_address(address(this));
        string memory receiverCosmos = COSMOS.to_cosmos_address(IPaymentRegistry(paymentRegistry).streamReceiverAddress());

        string memory msgSend = string(abi.encodePacked(
            '{"@type":"/cosmos.bank.v1beta1.MsgSend",',
            '"from_address":"', contractCosmos, '",',
            '"to_address":"', receiverCosmos, '",',
            '"amount":[{"denom":"', denom, '","amount":"', Strings.toString(amount), '"}]}'
        ));

        require(COSMOS.execute_cosmos(msgSend, COSMOS_GAS_LIMIT), "Cosmos bank send failed");
    }

    function _notifyRegistry(StreamInfo storage s, uint256 amount, uint256 tickNumber) internal {
        address reg = paymentRegistry;
        bytes memory payload = abi.encodeCall(
            IPaymentRegistry.processPayment,
            (s.streamId, s.senderCosmos, s.receiver, s.destChannel, s.totalAmount, s.endTime, amount, tickNumber, s.ratePerTick)
        );
        (bool ok, bytes memory returnData) = reg.call(payload);
        if (!ok) {
            if (returnData.length > 0) {
                assembly { revert(add(returnData, 32), mload(returnData)) }
            }
            revert("Registry processPayment failed");
        }
    }

    /// @dev Validates that a string does not contain JSON-unsafe characters
    function _validateSafeString(string calldata s) private pure {
        bytes calldata b = bytes(s);
        for (uint256 i = 0; i < b.length; i++) {
            bytes1 c = b[i];
            require(c != '"' && c != '\\' && c != '{' && c != '}', "Unsafe string character");
        }
    }
}
