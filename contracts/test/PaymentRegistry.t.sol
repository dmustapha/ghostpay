// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// File: contracts/test/PaymentRegistry.t.sol
// CAUTION: ASSUMED PATTERN — ICosmos and Oracle not available in test.
// Tests verify state management logic only.

import "forge-std/Test.sol";
import "../src/PaymentRegistry.sol";

contract PaymentRegistryTest is Test {
    PaymentRegistry public registry;
    address public receiverContract = makeAddr("streamReceiver");
    address public senderAddr = makeAddr("streamSender");
    address constant ICOSMOS = 0x00000000000000000000000000000000000000f1;

    function setUp() public {
        registry = new PaymentRegistry(
            "uinit",
            address(0), // No oracle in test
            "INIT/USD",
            receiverContract,
            false // ibcMode=false for existing tests
        );
        registry.setStreamSender(senderAddr); // wire access control
        // DEV-003: Mock the correct 2-param signature
        vm.mockCall(ICOSMOS, abi.encodeWithSignature("execute_cosmos(string,uint64)"), abi.encode(true));
        vm.mockCall(
            ICOSMOS,
            abi.encodeWithSignature("to_cosmos_address(address)"),
            abi.encode("init1mockaddr...")
        );
        // DEV-007: Mock StreamReceiver.onReceivePayment call (L-6: 4-param signature)
        vm.mockCall(
            receiverContract,
            abi.encodeWithSignature("onReceivePayment(bytes32,string,string,uint256)"),
            abi.encode()
        );
    }

    function test_processPayment_registersStream() public {
        bytes32 streamId = keccak256("stream1");
        vm.prank(senderAddr);
        registry.processPayment(
            streamId,
            "init1sender...",
            "init1receiver...",
            "channel-1",
            10 ether, // totalAmount
            block.timestamp + 300, // endTime
            1 ether,
            1,
            1 ether // ratePerTick_
        );

        PaymentRegistry.Stream memory s = registry.getStream(streamId);
        assertEq(s.amountSent, 1 ether);
        assertEq(s.totalAmount, 10 ether);
        assertEq(uint(s.status), uint(PaymentRegistry.StreamStatus.ACTIVE));
    }

    function test_processPayment_multipleTicksAccumulate() public {
        bytes32 streamId = keccak256("stream1");

        vm.prank(senderAddr);
        registry.processPayment(streamId, "init1s...", "init1r...", "channel-1", 10 ether, block.timestamp + 300, 1 ether, 1, 1 ether);
        vm.prank(senderAddr);
        registry.processPayment(streamId, "init1s...", "init1r...", "channel-1", 10 ether, block.timestamp + 300, 1 ether, 2, 1 ether);
        vm.prank(senderAddr);
        registry.processPayment(streamId, "init1s...", "init1r...", "channel-1", 10 ether, block.timestamp + 300, 1 ether, 3, 1 ether);

        PaymentRegistry.Stream memory s = registry.getStream(streamId);
        assertEq(s.amountSent, 3 ether);
    }

    function test_processPayment_setsCompleted() public {
        bytes32 streamId = keccak256("stream1");
        // Send 10 ticks of 1 ether on a 10 ether stream → should complete
        for (uint256 i = 1; i <= 10; i++) {
            vm.prank(senderAddr);
            registry.processPayment(streamId, "init1s...", "init1r...", "channel-1", 10 ether, block.timestamp + 300, 1 ether, i, 1 ether);
        }
        PaymentRegistry.Stream memory s = registry.getStream(streamId);
        assertEq(s.amountSent, 10 ether);
        assertEq(uint(s.status), uint(PaymentRegistry.StreamStatus.COMPLETED));
    }

    function test_processPayment_capsOverpayment() public {
        bytes32 streamId = keccak256("stream-cap");
        // H-1: Single tick of 15 ether on a 10 ether stream — should cap at 10
        vm.prank(senderAddr);
        registry.processPayment(streamId, "init1s...", "init1r...", "channel-1", 10 ether, block.timestamp + 300, 15 ether, 1, 15 ether);

        PaymentRegistry.Stream memory s = registry.getStream(streamId);
        assertEq(s.amountSent, 10 ether); // capped, not 15 ether
        assertEq(uint(s.status), uint(PaymentRegistry.StreamStatus.COMPLETED));
    }

    function test_getStreamsByReceiver() public {
        bytes32 id1 = keccak256("s1");
        bytes32 id2 = keccak256("s2");

        vm.prank(senderAddr);
        registry.processPayment(id1, "init1s...", "init1r...", "channel-1", 10 ether, block.timestamp + 300, 1 ether, 1, 1 ether);
        vm.prank(senderAddr);
        registry.processPayment(id2, "init1s...", "init1r...", "channel-1", 10 ether, block.timestamp + 300, 1 ether, 1, 1 ether);

        bytes32[] memory ids = registry.getStreamsByReceiver("init1r...");
        assertEq(ids.length, 2);
    }
}

/// @notice Tests for IBC cross-rollup mode
contract PaymentRegistryIbcTest is Test {
    PaymentRegistry public registry;
    address public receiverContract = makeAddr("streamReceiver");
    address public senderAddr = makeAddr("streamSender");
    address public hookCaller = makeAddr("ibcHookCaller");
    address constant ICOSMOS = 0x00000000000000000000000000000000000000f1;

    function setUp() public {
        registry = new PaymentRegistry(
            "uinit",
            address(0),
            "INIT/USD",
            receiverContract,
            true // ibcMode=true
        );
        registry.setStreamSender(senderAddr);
        registry.setIbcHookCaller(hookCaller);
        vm.mockCall(ICOSMOS, abi.encodeWithSignature("execute_cosmos(string,uint64)"), abi.encode(true));
        vm.mockCall(ICOSMOS, abi.encodeWithSignature("to_cosmos_address(address)"), abi.encode("init1mockaddr..."));
    }

    function test_ibcMode_enabled() public view {
        assertTrue(registry.ibcMode());
    }

    function test_processPayment_ibcMode_forwards() public {
        bytes32 streamId = keccak256("ibc-stream");

        vm.prank(hookCaller);
        registry.processPayment(
            streamId, "init1s...", "init1r...", "channel-1",
            10 ether, block.timestamp + 300, 1 ether, 1, 1 ether
        );

        // Verify stream was registered and payment recorded
        PaymentRegistry.Stream memory s = registry.getStream(streamId);
        assertEq(s.amountSent, 1 ether);
        assertEq(uint(s.status), uint(PaymentRegistry.StreamStatus.ACTIVE));
    }

    function test_processPayment_ibcMode_completes() public {
        bytes32 streamId = keccak256("ibc-stream");

        for (uint256 i = 1; i <= 10; i++) {
            vm.prank(hookCaller);
            registry.processPayment(
                streamId, "init1s...", "init1r...", "channel-1",
                10 ether, block.timestamp + 300, 1 ether, i, 1 ether
            );
        }

        PaymentRegistry.Stream memory s = registry.getStream(streamId);
        assertEq(s.amountSent, 10 ether);
        assertEq(uint(s.status), uint(PaymentRegistry.StreamStatus.COMPLETED));
    }
}
