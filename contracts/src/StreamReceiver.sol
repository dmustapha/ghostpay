// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// File: contracts/src/StreamReceiver.sol

import {ICosmos} from "./interfaces/ICosmos.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract StreamReceiver {
    ICosmos constant COSMOS = ICosmos(0x00000000000000000000000000000000000000f1);
    struct IncomingStream {
        bytes32 streamId;
        string sender;
        uint256 totalReceived;
        uint256 lastReceiveTime;
        bool active;
    }

    mapping(address => uint256) public claimable;
    mapping(bytes32 => IncomingStream) public incomingStreams;
    mapping(address => bytes32[]) public receiverStreamIds;

    event PaymentReceived(bytes32 indexed streamId, address indexed receiver, uint256 amount);
    event FundsClaimed(address indexed receiver, uint256 amount);

    string public denom; // Set to the IBC denom that arrives on this chain
    address public owner;
    address public paymentRegistry;

    constructor(string memory _denom) {
        denom = _denom;
        owner = msg.sender;
    }

    event DenomUpdated(string oldDenom, string newDenom);
    event PaymentRegistryUpdated(address indexed oldRegistry, address indexed newRegistry);

    function setDenom(string calldata newDenom) external {
        require(msg.sender == owner, "Not owner");
        emit DenomUpdated(denom, newDenom);
        denom = newDenom;
    }

    function setPaymentRegistry(address _paymentRegistry) external {
        require(msg.sender == owner, "Not owner");
        emit PaymentRegistryUpdated(paymentRegistry, _paymentRegistry);
        paymentRegistry = _paymentRegistry;
    }

    /// @notice Called by PaymentRegistry after processing a tick.
    /// @dev NOTE: claimable is credited optimistically upon receipt of the tick notification.
    /// The actual Cosmos bank send from StreamSender executes asynchronously after the EVM call.
    /// In practice the send completes before any subsequent claim tx due to block ordering.
    /// execute_cosmos dispatch success is verified with require() in StreamSender._sendToRegistry.
    function onReceivePayment(
        bytes32 streamId,
        string calldata receiver,
        uint256 amount
    ) external {
        require(msg.sender == paymentRegistry, "Only PaymentRegistry");
        // Convert bech32 receiver to EVM address for balance tracking
        address receiverAddr = _bech32ToAddress(receiver);

        // Update or create incoming stream record
        IncomingStream storage s = incomingStreams[streamId];
        if (s.lastReceiveTime == 0) {
            incomingStreams[streamId] = IncomingStream({
                streamId: streamId,
                sender: "",
                totalReceived: 0,
                lastReceiveTime: block.timestamp,
                active: true
            });
            s = incomingStreams[streamId];
            receiverStreamIds[receiverAddr].push(streamId);
        }

        s.totalReceived += amount;
        s.lastReceiveTime = block.timestamp;
        claimable[receiverAddr] += amount;

        emit PaymentReceived(streamId, receiverAddr, amount);
    }

    /// @notice Claim accumulated funds via Cosmos bank send
    function claim() external {
        uint256 amount = claimable[msg.sender];
        require(amount > 0, "Nothing to claim");
        claimable[msg.sender] = 0;

        string memory senderCosmos = COSMOS.to_cosmos_address(address(this));
        string memory receiverCosmos = COSMOS.to_cosmos_address(msg.sender);

        string memory msgSend = string(abi.encodePacked(
            '{"@type":"/cosmos.bank.v1beta1.MsgSend",',
            '"from_address":"', senderCosmos, '",',
            '"to_address":"', receiverCosmos, '",',
            '"amount":[{"denom":"', denom, '","amount":"', Strings.toString(amount), '"}]}'
        ));

        // DEV-003: execute_cosmos requires (string, uint64) on minievm v1.2.15
        require(COSMOS.execute_cosmos(msgSend, 500000), "Cosmos claim failed");

        emit FundsClaimed(msg.sender, amount);
    }

    function getClaimable(address account) external view returns (uint256) {
        return claimable[account];
    }

    function getIncomingStreams(address account) external view returns (bytes32[] memory) {
        return receiverStreamIds[account];
    }

    function getIncomingStream(bytes32 streamId) external view returns (IncomingStream memory) {
        return incomingStreams[streamId];
    }

    /// @dev Convert bech32 cosmos address to EVM address
    function _bech32ToAddress(string calldata bech32Addr) internal view returns (address) {
        try COSMOS.to_evm_address(bech32Addr) returns (address evmAddr) {
            return evmAddr;
        } catch {
            // Revert rather than silently misdirect funds to an unrecoverable keccak address
            revert("Address conversion unavailable");
        }
    }

    receive() external payable {}
}
