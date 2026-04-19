// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Phase 2: Known Risks Triage Tests
// Tests for TESTABLE risks identified in BUILD-REPORT.md

import "forge-std/Test.sol";
import "../src/PaymentRegistry.sol";
import "../src/StreamSender.sol";
import "../src/StreamReceiver.sol";

contract KnownRisksTest is Test {
    PaymentRegistry public registry;
    StreamSender public sender;
    StreamReceiver public receiver;

    address constant ICOSMOS = 0x00000000000000000000000000000000000000f1;
    address public alice = makeAddr("alice");
    address public senderAddr;
    address public receiverContract;
    address public mockEvmAddr = makeAddr("receiverEvm");

    function setUp() public {
        // Deploy receiver first (PaymentRegistry needs its address)
        receiver = new StreamReceiver("umin");
        receiverContract = address(receiver);

        // Deploy registry with oracle at address(0) to simulate inactive oracle
        registry = new PaymentRegistry("umin", address(0), "ETH/USD", receiverContract);

        // Deploy sender
        sender = new StreamSender("umin", address(registry));
        senderAddr = address(sender);

        // Wire access control
        registry.setStreamSender(senderAddr);
        receiver.setPaymentRegistry(address(registry));

        // Mock ICosmos precompile
        vm.mockCall(ICOSMOS, abi.encodeWithSignature("execute_cosmos(string,uint64)"), abi.encode(true));
        vm.mockCall(ICOSMOS, abi.encodeWithSignature("to_cosmos_address(address)"), abi.encode("init1mock..."));
        vm.mockCall(ICOSMOS, abi.encodeWithSignature("to_evm_address(string)"), abi.encode(mockEvmAddr));
    }

    // =========================================================================
    // RISK 1: Oracle feed inactive — price=0 graceful degradation
    // =========================================================================

    function test_risk1_oracleInactive_returnsZeroUsd() public {
        // Registry was created with oracleAddress=address(0)
        // processPayment should succeed and usdValue should be 0
        bytes32 streamId = keccak256("risk1");

        vm.prank(senderAddr);
        registry.processPayment(
            streamId, "init1s...", "init1r...", "channel-1",
            10 ether, block.timestamp + 300, 1 ether, 1, 1 ether
        );

        PaymentRegistry.Stream memory s = registry.getStream(streamId);
        assertEq(s.usdValueTotal, 0, "USD value should be 0 when oracle inactive");
        assertEq(s.amountSent, 1 ether, "Payment should still process");
    }

    function test_risk1_oracleReverts_gracefulDegradation() public {
        // Deploy a separate receiver + registry with a mock oracle that reverts
        address fakeOracle = makeAddr("fakeOracle");
        StreamReceiver recv2 = new StreamReceiver("umin");
        PaymentRegistry reg2 = new PaymentRegistry("umin", fakeOracle, "ETH/USD", address(recv2));
        reg2.setStreamSender(senderAddr);
        recv2.setPaymentRegistry(address(reg2));

        // Mock oracle to revert
        vm.mockCallRevert(fakeOracle, abi.encodeWithSignature("get_price(string)"), "oracle down");

        bytes32 streamId = keccak256("risk1b");
        vm.prank(senderAddr);
        reg2.processPayment(
            streamId, "init1s...", "init1r...", "channel-1",
            10 ether, block.timestamp + 300, 1 ether, 1, 1 ether
        );

        PaymentRegistry.Stream memory s = reg2.getStream(streamId);
        assertEq(s.usdValueTotal, 0, "USD value should be 0 when oracle reverts");
        assertEq(s.amountSent, 1 ether, "Payment should still process despite oracle failure");
    }

    // =========================================================================
    // RISK 4: execute_cosmos queued execution — no mid-EVM cosmos state changes
    // (STRUCTURAL — verify code ordering is correct)
    // =========================================================================

    function test_risk4_sendTickCallOrder() public {
        // Verify: cosmos bank send is called BEFORE processPayment
        // In _sendToRegistry: execute_cosmos (bank send) then processPayment
        // This is correct because cosmos msgs queue but EVM state is immediate.
        // The test verifies the full sendTick flow completes without reverting.

        vm.prank(alice);
        bytes32 streamId = sender.createStream(
            "init1alice...", "init1receiver...", "channel-1", 10 ether, 300
        );

        vm.mockCall(address(registry), abi.encodeWithSignature("streamReceiverAddress()"), abi.encode(receiverContract));
        vm.mockCall(
            address(registry),
            abi.encodeWithSignature("processPayment(bytes32,string,string,string,uint256,uint256,uint256,uint256,uint256)"),
            abi.encode()
        );

        vm.warp(block.timestamp + 30);
        vm.prank(alice);
        sender.sendTick(streamId);

        StreamSender.StreamInfo memory info = sender.getStreamInfo(streamId);
        assertEq(info.amountSent, 1 ether, "One tick sent");
        assertEq(info.tickCount, 1, "Tick count incremented");
    }

    // =========================================================================
    // RISK 5: StreamSender must be pre-funded (2-step flow)
    // Verify createStream does NOT transfer tokens — just books reservation
    // =========================================================================

    function test_risk5_createStream_noTransfer_justReservation() public {
        vm.prank(alice);
        bytes32 streamId = sender.createStream(
            "init1alice...", "init1receiver...", "channel-1", 10 ether, 300
        );

        // totalReserved tracks the reservation
        assertEq(sender.totalReserved(), 10 ether);

        // Stream is active but no tokens moved (amountSent = 0)
        StreamSender.StreamInfo memory info = sender.getStreamInfo(streamId);
        assertEq(info.amountSent, 0, "No tokens sent at creation - pre-funding model");
        assertTrue(info.active);
    }

    function test_risk5_multipleStreams_reservationsStack() public {
        vm.startPrank(alice);
        sender.createStream("init1a...", "init1r...", "ch-1", 5 ether, 300);
        sender.createStream("init1a...", "init1r...", "ch-1", 3 ether, 300);
        vm.stopPrank();

        assertEq(sender.totalReserved(), 8 ether, "Reservations stack across streams");
    }

    // =========================================================================
    // RISK 6: sendTick requires 2M gas (DEV-010)
    // Verify the call chain depth: sendTick → _sendToRegistry → execute_cosmos + processPayment → onReceivePayment
    // =========================================================================

    function test_risk6_sendTickFullCallChain() public {
        // Full integration: sender → registry → receiver
        // This verifies the entire call chain works in forge test (mocked cosmos)

        vm.prank(alice);
        bytes32 streamId = sender.createStream(
            "init1alice...", "init1receiver...", "channel-1", 10 ether, 300
        );

        vm.warp(block.timestamp + 30);
        vm.prank(alice);
        sender.sendTick(streamId);

        // Verify receiver got credited
        assertEq(receiver.getClaimable(mockEvmAddr), 1 ether, "Receiver credited via full call chain");

        // Verify registry bookkeeping
        PaymentRegistry.Stream memory s = registry.getStream(streamId);
        assertEq(s.amountSent, 1 ether, "Registry recorded the tick");
    }

    // =========================================================================
    // RISK 7: Deployer key derivation mismatch (DEV-012)
    // STRUCTURAL — verify contracts don't depend on deployer address at runtime
    // =========================================================================

    function test_risk7_contractsIndependentOfDeployer() public {
        // Deploy from a different address — verify all functionality still works
        address altDeployer = makeAddr("altDeployer");

        vm.startPrank(altDeployer);
        StreamReceiver recv2 = new StreamReceiver("umin");
        PaymentRegistry reg2 = new PaymentRegistry("umin", address(0), "ETH/USD", address(recv2));
        StreamSender send2 = new StreamSender("umin", address(reg2));

        reg2.setStreamSender(address(send2));
        recv2.setPaymentRegistry(address(reg2));
        vm.stopPrank();

        // Owner is altDeployer, not the original deployer
        assertEq(reg2.owner(), altDeployer);
        assertEq(recv2.owner(), altDeployer);

        // Can create streams from any address
        vm.prank(alice);
        bytes32 sid = send2.createStream("init1a...", "init1r...", "ch-1", 5 ether, 300);
        assertTrue(sid != bytes32(0));
    }

    // =========================================================================
    // Bonus: Access control tests (ensure StreamSender-only on registry)
    // =========================================================================

    function test_registryRejectsUnauthorizedCaller() public {
        bytes32 streamId = keccak256("unauth");
        vm.prank(alice); // alice is NOT streamSender
        vm.expectRevert("Only StreamSender");
        registry.processPayment(
            streamId, "init1s...", "init1r...", "channel-1",
            10 ether, block.timestamp + 300, 1 ether, 1, 1 ether
        );
    }

    function test_receiverRejectsUnauthorizedCaller() public {
        bytes32 streamId = keccak256("unauth");
        vm.prank(alice); // alice is NOT paymentRegistry
        vm.expectRevert("Only PaymentRegistry");
        receiver.onReceivePayment(streamId, "init1r...", 1 ether);
    }
}
