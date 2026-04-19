// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Phase 3: Integration tests — Contract-to-Contract and Contract-to-Precompile
// All ICosmos precompile calls mocked. Split into multiple contracts to avoid Yul stack depth.

import "forge-std/Test.sol";
import "../src/StreamSender.sol";
import "../src/PaymentRegistry.sol";
import "../src/StreamReceiver.sol";

// ============================================================
// Base: shared setUp for all integration test contracts
// ============================================================
abstract contract IntegrationBase is Test {
    StreamSender public sender;
    PaymentRegistry public registry;
    StreamReceiver public receiver;

    address constant ICOSMOS = 0x00000000000000000000000000000000000000f1;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public mockEvmAddr = makeAddr("receiverEvm");

    function setUp() public virtual {
        receiver = new StreamReceiver("uinit");
        registry = new PaymentRegistry("uinit", address(0), "INIT/USD", address(receiver));
        sender = new StreamSender("uinit", address(registry));

        registry.setStreamSender(address(sender));
        receiver.setPaymentRegistry(address(registry));

        vm.mockCall(ICOSMOS, abi.encodeWithSignature("execute_cosmos(string,uint64)"), abi.encode(true));
        vm.mockCall(ICOSMOS, abi.encodeWithSignature("to_cosmos_address(address)"), abi.encode("init1mock..."));
        vm.mockCall(ICOSMOS, abi.encodeWithSignature("to_evm_address(string)"), abi.encode(mockEvmAddr));

        vm.deal(alice, 100 ether);
    }

    function _createDefaultStream() internal returns (bytes32) {
        vm.prank(alice);
        return sender.createStream("init1alice...", "init1bob...", "channel-1", 10 ether, 300);
    }

    function _sendTicks(bytes32 streamId, uint256 count) internal {
        uint256 ts = block.timestamp;
        for (uint256 i = 0; i < count; i++) {
            ts += 30;
            vm.warp(ts);
            vm.prank(alice);
            sender.sendTick(streamId);
        }
    }
}

// ============================================================
// 1. StreamSender -> PaymentRegistry connection
// ============================================================
contract P3_SenderToRegistry is IntegrationBase {

    function test_sendTick_callsRegistryProcessPayment() public {
        bytes32 streamId = _createDefaultStream();
        _sendTicks(streamId, 1);

        PaymentRegistry.Stream memory s = registry.getStream(streamId);
        assertEq(s.amountSent, 1 ether, "Registry should record 1 ether");
        assertEq(s.totalAmount, 10 ether);
        assertEq(uint(s.status), uint(PaymentRegistry.StreamStatus.ACTIVE));
    }

    function test_sendTick_multipleTicksAccumulate() public {
        bytes32 streamId = _createDefaultStream();
        _sendTicks(streamId, 3);

        PaymentRegistry.Stream memory s = registry.getStream(streamId);
        assertEq(s.amountSent, 3 ether, "Registry accumulates 3 ticks");
    }

    function test_sendTick_completesStream() public {
        bytes32 streamId = _createDefaultStream();
        _sendTicks(streamId, 10);

        PaymentRegistry.Stream memory rs = registry.getStream(streamId);
        assertEq(uint(rs.status), uint(PaymentRegistry.StreamStatus.COMPLETED));
        assertEq(rs.amountSent, 10 ether);

        StreamSender.StreamInfo memory si = sender.getStreamInfo(streamId);
        assertFalse(si.active);
    }

    function test_sendTick_revertNotOwner() public {
        bytes32 streamId = _createDefaultStream();
        vm.warp(block.timestamp + 30);
        vm.prank(bob);
        vm.expectRevert("Not stream owner");
        sender.sendTick(streamId);
    }

    function test_sendTick_allowsPastEndTime() public {
        bytes32 streamId = _createDefaultStream();
        vm.warp(block.timestamp + 301);
        vm.prank(alice);
        // After fix: sendTick allowed past endTime if amountSent < totalAmount (timer drift tolerance)
        sender.sendTick(streamId);
    }

    function test_sendTick_revertTooSoon() public {
        bytes32 streamId = _createDefaultStream();
        vm.prank(alice);
        sender.sendTick(streamId);
        vm.warp(block.timestamp + 10);
        vm.prank(alice);
        vm.expectRevert("Tick too soon");
        sender.sendTick(streamId);
    }
}

// ============================================================
// 2. PaymentRegistry -> StreamReceiver connection
// ============================================================
contract P3_RegistryToReceiver is IntegrationBase {

    function test_sendTick_creditsReceiverClaimable() public {
        bytes32 streamId = _createDefaultStream();
        _sendTicks(streamId, 1);
        assertEq(receiver.getClaimable(mockEvmAddr), 1 ether);
    }

    function test_sendTick_multipleTicksAccumulateInReceiver() public {
        bytes32 streamId = _createDefaultStream();
        _sendTicks(streamId, 5);
        assertEq(receiver.getClaimable(mockEvmAddr), 5 ether);

        StreamReceiver.IncomingStream memory is_ = receiver.getIncomingStream(streamId);
        assertEq(is_.totalReceived, 5 ether);
    }

    function test_receiverRejectsNonRegistry() public {
        vm.prank(alice);
        vm.expectRevert("Only PaymentRegistry");
        receiver.onReceivePayment(keccak256("fake"), "init1bob...", 1 ether);
    }
}

// ============================================================
// 3. StreamSender cancel -> PaymentRegistry cancel
// ============================================================
contract P3_CancelFlow is IntegrationBase {

    function test_cancelStream_updatesRegistryStatus() public {
        bytes32 streamId = _createDefaultStream();
        _sendTicks(streamId, 1);

        vm.prank(alice);
        sender.cancelStream(streamId);

        PaymentRegistry.Stream memory s = registry.getStream(streamId);
        assertEq(uint(s.status), uint(PaymentRegistry.StreamStatus.CANCELLED));
        assertEq(s.amountSent, 1 ether);
    }

    // After fix: Cancel on never-registered stream now reverts because
    // PaymentRegistry.cancelStream requires startTime != 0 (stream must be registered).
    function test_cancelStream_noTicksSent_reverts() public {
        bytes32 streamId = _createDefaultStream();
        vm.prank(alice);
        // Registry revert propagates up through StreamSender.cancelStream
        vm.expectRevert("Stream not registered");
        sender.cancelStream(streamId);
    }

    function test_cancelStream_revertNotOwner() public {
        bytes32 streamId = _createDefaultStream();
        vm.prank(bob);
        vm.expectRevert("Not stream owner");
        sender.cancelStream(streamId);
    }
}

// ============================================================
// 4. Access control on PaymentRegistry
// ============================================================
contract P3_AccessControl is IntegrationBase {

    function test_registryRejectsNonSender() public {
        vm.prank(alice);
        vm.expectRevert("Only StreamSender");
        registry.processPayment(keccak256("x"), "s", "r", "ch", 10 ether, block.timestamp + 300, 1 ether, 1, 1 ether);
    }

    function test_registryCancelRejectsNonSender() public {
        vm.prank(alice);
        vm.expectRevert("Not stream sender");
        registry.cancelStream(keccak256("x"));
    }
}

// ============================================================
// 5. Contract <-> Precompile (ICosmos mock failures)
// ============================================================
contract P3_PrecompileFailures is IntegrationBase {

    function test_cosmosFailure_sendTickReverts() public {
        bytes32 streamId = _createDefaultStream();
        vm.mockCall(ICOSMOS, abi.encodeWithSignature("execute_cosmos(string,uint64)"), abi.encode(false));
        vm.warp(block.timestamp + 30);
        vm.prank(alice);
        vm.expectRevert("Cosmos bank send failed");
        sender.sendTick(streamId);
    }

    function test_cosmosFailure_cancelRefundReverts() public {
        bytes32 streamId = _createDefaultStream();
        _sendTicks(streamId, 1);

        vm.mockCall(ICOSMOS, abi.encodeWithSignature("execute_cosmos(string,uint64)"), abi.encode(false));
        vm.prank(alice);
        vm.expectRevert("Cosmos refund failed");
        sender.cancelStream(streamId);
    }

    function test_cosmosFailure_claimReverts() public {
        bytes32 streamId = _createDefaultStream();
        _sendTicks(streamId, 1);

        vm.mockCall(ICOSMOS, abi.encodeWithSignature("execute_cosmos(string,uint64)"), abi.encode(false));
        vm.prank(mockEvmAddr);
        vm.expectRevert("Cosmos claim failed");
        receiver.claim();
    }
}

// ============================================================
// 6. Full E2E flows
// ============================================================
contract P3_E2E is IntegrationBase {

    function test_fullFlow_createTicksClaim() public {
        bytes32 streamId = _createDefaultStream();
        _sendTicks(streamId, 10);

        StreamSender.StreamInfo memory si = sender.getStreamInfo(streamId);
        assertFalse(si.active);
        assertEq(si.amountSent, 10 ether);
        assertEq(sender.totalReserved(), 0);

        PaymentRegistry.Stream memory rs = registry.getStream(streamId);
        assertEq(rs.amountSent, 10 ether);
        assertEq(uint(rs.status), uint(PaymentRegistry.StreamStatus.COMPLETED));

        assertEq(receiver.getClaimable(mockEvmAddr), 10 ether);

        vm.prank(mockEvmAddr);
        receiver.claim();
        assertEq(receiver.getClaimable(mockEvmAddr), 0);
    }

    function test_partialThenCancel() public {
        bytes32 streamId = _createDefaultStream();
        _sendTicks(streamId, 3);

        vm.prank(alice);
        sender.cancelStream(streamId);

        assertFalse(sender.getStreamInfo(streamId).active);
        assertEq(sender.totalReserved(), 0);

        PaymentRegistry.Stream memory rs = registry.getStream(streamId);
        assertEq(uint(rs.status), uint(PaymentRegistry.StreamStatus.CANCELLED));
        assertEq(rs.amountSent, 3 ether);

        assertEq(receiver.getClaimable(mockEvmAddr), 3 ether);
    }

    function test_multipleStreams_independent() public {
        vm.prank(alice);
        bytes32 id1 = sender.createStream("init1alice...", "init1bob...", "channel-1", 6 ether, 180);
        vm.prank(alice);
        bytes32 id2 = sender.createStream("init1alice...", "init1carol...", "channel-1", 9 ether, 270);

        vm.warp(block.timestamp + 30);
        vm.prank(alice);
        sender.sendTick(id1);
        vm.prank(alice);
        sender.sendTick(id2);

        assertEq(registry.getStream(id1).amountSent, 1 ether);
        assertEq(registry.getStream(id2).amountSent, 1 ether);
        assertEq(receiver.getClaimable(mockEvmAddr), 2 ether);
    }
}
