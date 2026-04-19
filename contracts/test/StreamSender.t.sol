// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// File: contracts/test/StreamSender.t.sol
// CAUTION: ASSUMED PATTERN — ICosmos precompile is not available in forge test.
// These tests verify local logic only. Integration tested manually on testnet.
// DEV-007: StreamSender deploys on same chain as PaymentRegistry.
// DEV-008: No msg.value; uses amount parameter + cosmos bank pre-funding.

import "forge-std/Test.sol";
import "../src/StreamSender.sol";

contract StreamSenderTest is Test {
    StreamSender public sender;
    address public alice = makeAddr("alice");
    address public registryAddr = makeAddr("registry");

    function setUp() public {
        sender = new StreamSender("umin", registryAddr);
        vm.deal(alice, 100 ether);
    }

    function test_createStream() public {
        vm.prank(alice);
        bytes32 streamId = sender.createStream(
            "init1alice...",
            "init1receiver...",
            "channel-1",
            10 ether,
            300 // 5 minutes
        );
        assertTrue(streamId != bytes32(0));

        StreamSender.StreamInfo memory info = sender.getStreamInfo(streamId);
        assertEq(info.sender, alice);
        assertEq(info.totalAmount, 10 ether);
        assertTrue(info.active);
        assertEq(info.ratePerTick, 1 ether); // 10 ether / 10 ticks (300s / 30s)
        assertEq(sender.totalReserved(), 10 ether);
    }

    function test_createStream_revertZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert("Amount must be positive");
        sender.createStream("init1alice...", "init1receiver...", "channel-1", 0, 300);
    }

    function test_cancelStream() public {
        vm.prank(alice);
        bytes32 streamId = sender.createStream(
            "init1alice...",
            "init1receiver...",
            "channel-1",
            10 ether,
            300
        );

        assertEq(sender.totalReserved(), 10 ether);

        // Mock cosmos calls for cancel refund
        address ICOSMOS = 0x00000000000000000000000000000000000000f1;
        vm.mockCall(ICOSMOS, abi.encodeWithSignature("execute_cosmos(string,uint64)"), abi.encode(true));
        vm.mockCall(ICOSMOS, abi.encodeWithSignature("to_cosmos_address(address)"), abi.encode("init1mock..."));
        vm.mockCall(registryAddr, abi.encodeWithSignature("cancelStream(bytes32)", streamId), abi.encode());

        vm.prank(alice);
        sender.cancelStream(streamId);

        StreamSender.StreamInfo memory info = sender.getStreamInfo(streamId);
        assertFalse(info.active);
        assertEq(sender.totalReserved(), 0);
    }

    function test_cancelStream_revertNotOwner() public {
        vm.prank(alice);
        bytes32 streamId = sender.createStream(
            "init1alice...",
            "init1receiver...",
            "channel-1",
            10 ether,
            300
        );

        vm.prank(makeAddr("bob"));
        vm.expectRevert("Not stream owner");
        sender.cancelStream(streamId);
    }

    function test_createStream_revertAmountTooSmall() public {
        vm.prank(alice);
        vm.expectRevert("Amount too small for tick rate");
        // 300s / 30s = 10 ticks. 9 wei / 10 = 0 ratePerTick.
        sender.createStream("init1alice...", "init1r...", "channel-1", 9, 300);
    }

    function test_cancelStream_partialStream() public {
        address ICOSMOS = 0x00000000000000000000000000000000000000f1;
        vm.mockCall(ICOSMOS, abi.encodeWithSignature("execute_cosmos(string,uint64)"), abi.encode(true));
        vm.mockCall(ICOSMOS, abi.encodeWithSignature("to_cosmos_address(address)"), abi.encode("init1mock..."));
        vm.mockCall(registryAddr, abi.encodeWithSignature("streamReceiverAddress()"), abi.encode(makeAddr("receiver")));
        vm.mockCall(
            registryAddr,
            abi.encodeWithSignature("processPayment(bytes32,string,string,string,uint256,uint256,uint256,uint256,uint256)"),
            abi.encode()
        );
        vm.mockCall(registryAddr, abi.encodeWithSignature("cancelStream(bytes32)"), abi.encode());

        vm.prank(alice);
        bytes32 streamId = sender.createStream("init1alice...", "init1r...", "channel-1", 10 ether, 300);
        assertEq(sender.totalReserved(), 10 ether);

        // Send one tick: ratePerTick = 1 ether (10 ether / 10 ticks)
        vm.warp(block.timestamp + 30);
        vm.prank(alice);
        sender.sendTick(streamId);

        // Per-tick decrement: totalReserved should now be 9 ether
        assertEq(sender.totalReserved(), 9 ether);

        // Cancel: remaining = 10 - 1 = 9. totalReserved -= 9 → 0
        vm.prank(alice);
        sender.cancelStream(streamId);
        assertEq(sender.totalReserved(), 0);
    }

    function test_getSenderStreams() public {
        vm.startPrank(alice);
        sender.createStream("init1alice...", "init1a...", "channel-1", 5 ether, 300);
        sender.createStream("init1alice...", "init1b...", "channel-1", 5 ether, 300);
        vm.stopPrank();

        bytes32[] memory ids = sender.getSenderStreams(alice);
        assertEq(ids.length, 2);
    }
}
