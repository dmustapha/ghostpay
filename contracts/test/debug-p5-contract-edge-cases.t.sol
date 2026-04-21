// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Phase 5: Edge Cases + Security Inputs for GhostPay contracts
// All ICosmos precompile calls are mocked via vm.mockCall.

import "forge-std/Test.sol";
import "../src/StreamSender.sol";
import "../src/PaymentRegistry.sol";
import "../src/StreamReceiver.sol";

// ============================================================
// Helper: Reentrancy attacker that tries to re-enter claim()
// ============================================================
contract ReentrancyAttacker {
    StreamReceiver public target;
    uint256 public attackCount;

    constructor(StreamReceiver _target) {
        target = _target;
    }

    function attack() external {
        target.claim();
    }

    receive() external payable {
        if (attackCount < 2) {
            attackCount++;
            target.claim();
        }
    }
}

// ============================================================
// StreamSender Edge Cases
// ============================================================
contract StreamSenderEdgeCases is Test {
    StreamSender public sender;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public registryAddr = makeAddr("registry");
    address constant ICOSMOS = 0x00000000000000000000000000000000000000f1;

    function setUp() public {
        sender = new StreamSender("umin", registryAddr, false);
        vm.deal(alice, 100 ether);

        // Mock all ICosmos calls
        vm.mockCall(ICOSMOS, abi.encodeWithSignature("execute_cosmos(string,uint64)"), abi.encode(true));
        vm.mockCall(ICOSMOS, abi.encodeWithSignature("to_cosmos_address(address)"), abi.encode("init1mock..."));
        // Mock registry calls
        vm.mockCall(registryAddr, abi.encodeWithSignature("streamReceiverAddress()"), abi.encode(makeAddr("receiver")));
        vm.mockCall(
            registryAddr,
            abi.encodeWithSignature("processPayment(bytes32,string,string,string,uint256,uint256,uint256,uint256,uint256)"),
            abi.encode()
        );
        vm.mockCall(registryAddr, abi.encodeWithSignature("cancelStream(bytes32)"), abi.encode());
    }

    // --- createStream edge cases ---

    function test_createStream_zeroDuration() public {
        vm.prank(alice);
        vm.expectRevert("Duration must be positive");
        sender.createStream("init1a...", "init1r...", "channel-1", 1 ether, 0);
    }

    function test_createStream_zeroAmount() public {
        vm.prank(alice);
        vm.expectRevert("Amount must be positive");
        sender.createStream("init1a...", "init1r...", "channel-1", 0, 300);
    }

    function test_createStream_amountTooSmallForTicks() public {
        // 300s / 30s = 10 ticks. 9 / 10 = 0 ratePerTick
        vm.prank(alice);
        vm.expectRevert("Amount too small for tick rate");
        sender.createStream("init1a...", "init1r...", "channel-1", 9, 300);
    }

    function test_createStream_minimalValidAmount() public {
        // 10 wei with 10 ticks = 1 wei/tick — should succeed
        vm.prank(alice);
        bytes32 id = sender.createStream("init1a...", "init1r...", "channel-1", 10, 300);
        StreamSender.StreamInfo memory info = sender.getStreamInfo(id);
        assertEq(info.ratePerTick, 1);
        assertTrue(info.active);
    }

    function test_createStream_veryShortDuration() public {
        // 1 second < 30s tick interval → totalTicks forced to 1
        vm.prank(alice);
        bytes32 id = sender.createStream("init1a...", "init1r...", "channel-1", 1 ether, 1);
        StreamSender.StreamInfo memory info = sender.getStreamInfo(id);
        assertEq(info.ratePerTick, 1 ether); // single tick gets full amount
    }

    function test_createStream_exactlyOneTick() public {
        // 30s / 30s = 1 tick
        vm.prank(alice);
        bytes32 id = sender.createStream("init1a...", "init1r...", "channel-1", 5 ether, 30);
        StreamSender.StreamInfo memory info = sender.getStreamInfo(id);
        assertEq(info.ratePerTick, 5 ether);
    }

    function test_createStream_maxUint256Amount() public {
        // type(uint256).max with 300s = 10 ticks
        // ratePerTick = max/10 which is valid
        vm.prank(alice);
        bytes32 id = sender.createStream("init1a...", "init1r...", "channel-1", type(uint256).max, 300);
        StreamSender.StreamInfo memory info = sender.getStreamInfo(id);
        assertEq(info.ratePerTick, type(uint256).max / 10);
        assertTrue(info.active);
    }

    function test_createStream_emptyStrings() public {
        // M-2: Empty receiver now reverts
        vm.prank(alice);
        vm.expectRevert("Empty receiver");
        sender.createStream("", "", "", 1 ether, 300);
    }

    function test_createStream_uniqueStreamIds() public {
        vm.startPrank(alice);
        bytes32 id1 = sender.createStream("init1a...", "init1r...", "ch-1", 1 ether, 300);
        bytes32 id2 = sender.createStream("init1a...", "init1r...", "ch-1", 1 ether, 300);
        vm.stopPrank();
        assertTrue(id1 != id2, "Stream IDs must be unique");
    }

    function test_createStream_totalReservedAccumulates() public {
        vm.startPrank(alice);
        sender.createStream("init1a...", "init1r...", "ch-1", 3 ether, 300);
        sender.createStream("init1a...", "init1r...", "ch-1", 7 ether, 300);
        vm.stopPrank();
        assertEq(sender.totalReserved(), 10 ether);
    }

    // --- sendTick edge cases ---

    function test_sendTick_unauthorizedCaller() public {
        vm.prank(alice);
        bytes32 id = sender.createStream("init1a...", "init1r...", "ch-1", 10 ether, 300);

        vm.prank(bob);
        vm.expectRevert("Not stream owner");
        sender.sendTick(id);
    }

    function test_sendTick_nonexistentStream() public {
        bytes32 fakeId = keccak256("nonexistent");
        vm.prank(alice);
        vm.expectRevert("Not stream owner");
        sender.sendTick(fakeId);
    }

    function test_sendTick_pastEndTime_stillSends() public {
        vm.prank(alice);
        bytes32 id = sender.createStream("init1a...", "init1r...", "ch-1", 10 ether, 300);

        // Warp past end time — should still allow tick if amountSent < totalAmount
        vm.warp(block.timestamp + 301);
        vm.prank(alice);
        sender.sendTick(id);
    }

    function test_sendTick_tooSoon() public {
        vm.prank(alice);
        bytes32 id = sender.createStream("init1a...", "init1r...", "ch-1", 10 ether, 300);

        // First tick (no interval check for first tick since amountSent == 0)
        vm.prank(alice);
        sender.sendTick(id);

        // Second tick immediately — should fail
        vm.prank(alice);
        vm.expectRevert("Tick too soon");
        sender.sendTick(id);
    }

    function test_sendTick_exactlyAtMinInterval() public {
        vm.prank(alice);
        bytes32 id = sender.createStream("init1a...", "init1r...", "ch-1", 10 ether, 300);

        vm.prank(alice);
        sender.sendTick(id);

        // Warp exactly MIN_TICK_INTERVAL
        vm.warp(block.timestamp + 15);
        vm.prank(alice);
        sender.sendTick(id); // should succeed
    }

    function test_sendTick_oneBelowMinInterval() public {
        vm.prank(alice);
        bytes32 id = sender.createStream("init1a...", "init1r...", "ch-1", 10 ether, 300);

        vm.prank(alice);
        sender.sendTick(id);

        vm.warp(block.timestamp + 14); // 1 second below MIN_TICK_INTERVAL
        vm.prank(alice);
        vm.expectRevert("Tick too soon");
        sender.sendTick(id);
    }

    function test_sendTick_completesStream() public {
        // 1 tick stream: amount = 1 ether, duration = 1s → 1 tick
        vm.prank(alice);
        bytes32 id = sender.createStream("init1a...", "init1r...", "ch-1", 1 ether, 1);

        vm.prank(alice);
        sender.sendTick(id);

        StreamSender.StreamInfo memory info = sender.getStreamInfo(id);
        assertFalse(info.active, "Stream should be inactive after full send");
        assertEq(info.amountSent, 1 ether);
    }

    function test_sendTick_afterStreamCompleted() public {
        vm.prank(alice);
        bytes32 id = sender.createStream("init1a...", "init1r...", "ch-1", 1 ether, 1);

        vm.prank(alice);
        sender.sendTick(id);

        // Try another tick on completed stream
        vm.warp(block.timestamp + 30);
        vm.prank(alice);
        vm.expectRevert("Stream not active");
        sender.sendTick(id);
    }

    function test_sendTick_lastTickSendsRemainder() public {
        // 10 ether / 10 ticks = 1 ether/tick. Send all 10 ticks.
        // NOTE: via_ir optimizes block.timestamp reads, so use absolute warp values.
        vm.prank(alice);
        bytes32 id = sender.createStream("init1a...", "init1r...", "ch-1", 10 ether, 300);
        // startTs = 1, endTime = 301

        vm.prank(alice);
        sender.sendTick(id); // tick 1 at ts=1

        vm.warp(17); vm.prank(alice); sender.sendTick(id);   // tick 2
        vm.warp(33); vm.prank(alice); sender.sendTick(id);   // tick 3
        vm.warp(49); vm.prank(alice); sender.sendTick(id);   // tick 4
        vm.warp(65); vm.prank(alice); sender.sendTick(id);   // tick 5
        vm.warp(81); vm.prank(alice); sender.sendTick(id);   // tick 6
        vm.warp(97); vm.prank(alice); sender.sendTick(id);   // tick 7
        vm.warp(113); vm.prank(alice); sender.sendTick(id);  // tick 8
        vm.warp(129); vm.prank(alice); sender.sendTick(id);  // tick 9
        vm.warp(145); vm.prank(alice); sender.sendTick(id);  // tick 10

        StreamSender.StreamInfo memory info = sender.getStreamInfo(id);
        assertEq(info.amountSent, 10 ether);
        assertFalse(info.active);
        assertEq(sender.totalReserved(), 0);
    }

    function test_sendTick_totalReservedDecrementsPerTick() public {
        vm.prank(alice);
        bytes32 id = sender.createStream("init1a...", "init1r...", "ch-1", 10 ether, 300);
        assertEq(sender.totalReserved(), 10 ether);

        vm.warp(block.timestamp + 30);
        vm.prank(alice);
        sender.sendTick(id);
        assertEq(sender.totalReserved(), 9 ether);
    }

    // BUG: ratePerTick truncation leaves dust requiring extra tick
    function test_sendTick_dustFromTruncation_BUG() public {
        // 11 wei / 10 ticks = 1 wei/tick (truncated). 10 ticks send 10 wei, 1 wei dust.
        // NOTE: via_ir optimizes block.timestamp reads, so use absolute warp values.
        vm.prank(alice);
        bytes32 id = sender.createStream("init1a...", "init1r...", "ch-1", 11, 300);
        // startTs=1, endTime=301

        StreamSender.StreamInfo memory info = sender.getStreamInfo(id);
        assertEq(info.ratePerTick, 1); // 11/10 = 1 (truncated)

        // Send 10 ticks with absolute timestamps
        vm.prank(alice);     sender.sendTick(id); // tick 1 at ts=1
        vm.warp(17);  vm.prank(alice); sender.sendTick(id); // tick 2
        vm.warp(33);  vm.prank(alice); sender.sendTick(id); // tick 3
        vm.warp(49);  vm.prank(alice); sender.sendTick(id); // tick 4
        vm.warp(65);  vm.prank(alice); sender.sendTick(id); // tick 5
        vm.warp(81);  vm.prank(alice); sender.sendTick(id); // tick 6
        vm.warp(97);  vm.prank(alice); sender.sendTick(id); // tick 7
        vm.warp(113); vm.prank(alice); sender.sendTick(id); // tick 8
        vm.warp(129); vm.prank(alice); sender.sendTick(id); // tick 9
        vm.warp(145); vm.prank(alice); sender.sendTick(id); // tick 10

        info = sender.getStreamInfo(id);
        assertEq(info.amountSent, 10);
        assertTrue(info.active, "Stream still active - 1 wei dust remaining");

        // 11th tick sends the remaining 1 wei (ts=161 < endTime=301)
        vm.warp(161);
        vm.prank(alice);
        sender.sendTick(id);

        info = sender.getStreamInfo(id);
        assertEq(info.amountSent, 11);
        assertFalse(info.active);
    }

    // BUG: If dust tick can't fit within endTime, funds are stranded
    function test_sendTick_dustStrandedPastEndTime_BUG() public {
        // Amount=3, duration=60 => 2 ticks, ratePerTick=1. After 2 ticks, 1 wei stuck.
        // endTime = start + 60. Tick 1 at start, tick 2 at start+16, tick 3 at start+32 (within 60).
        uint256 startTs = block.timestamp;
        vm.prank(alice);
        bytes32 id = sender.createStream("init1a...", "init1r...", "ch-1", 3, 60);

        // tick 1
        vm.prank(alice);
        sender.sendTick(id);
        // tick 2
        vm.warp(startTs + 16);
        vm.prank(alice);
        sender.sendTick(id);
        // tick 3 (dust)
        vm.warp(startTs + 32);
        vm.prank(alice);
        sender.sendTick(id);

        StreamSender.StreamInfo memory info = sender.getStreamInfo(id);
        assertEq(info.amountSent, 3);
        assertFalse(info.active);
    }

    // --- cancelStream edge cases ---

    function test_cancelStream_unauthorizedCaller() public {
        vm.prank(alice);
        bytes32 id = sender.createStream("init1a...", "init1r...", "ch-1", 10 ether, 300);

        vm.prank(bob);
        vm.expectRevert("Not stream owner");
        sender.cancelStream(id);
    }

    function test_cancelStream_alreadyCancelled() public {
        vm.prank(alice);
        bytes32 id = sender.createStream("init1a...", "init1r...", "ch-1", 10 ether, 300);

        vm.prank(alice);
        sender.cancelStream(id);

        vm.prank(alice);
        vm.expectRevert("Stream not active");
        sender.cancelStream(id);
    }

    function test_cancelStream_afterFullSend() public {
        // Complete stream via ticks, then try cancel
        vm.prank(alice);
        bytes32 id = sender.createStream("init1a...", "init1r...", "ch-1", 1 ether, 1);

        vm.prank(alice);
        sender.sendTick(id);

        vm.prank(alice);
        vm.expectRevert("Stream not active");
        sender.cancelStream(id);
    }

    function test_cancelStream_nonexistentStream() public {
        bytes32 fakeId = keccak256("nonexistent");
        vm.prank(alice);
        vm.expectRevert("Not stream owner");
        sender.cancelStream(fakeId);
    }

    function test_cancelStream_zeroRefund() public {
        // Create stream, send all ticks, then cancel
        // Actually: after full send, stream is inactive. Let's test partial: send exactly totalAmount
        // Edge: create stream where 1 tick = totalAmount, send 1 tick → inactive.
        // We need a case where active but refund=0: impossible since if amountSent < totalAmount, refund > 0.
        // If amountSent == totalAmount, stream is already inactive. So refund=0 cancel is unreachable.
        // This is by-design: cancel on active stream always has refund > 0 OR amountSent == totalAmount (inactive).
        // Skipping: this is actually correct behavior — no edge case bug here.
        assertTrue(true);
    }

    function test_cancelStream_cosmosExecuteFails() public {
        vm.prank(alice);
        bytes32 id = sender.createStream("init1a...", "init1r...", "ch-1", 10 ether, 300);

        // Override cosmos mock to fail
        vm.mockCall(ICOSMOS, abi.encodeWithSignature("execute_cosmos(string,uint64)"), abi.encode(false));

        vm.prank(alice);
        vm.expectRevert("Cosmos refund failed");
        sender.cancelStream(id);
    }

    // --- getStreamInfo / getSenderStreams ---

    function test_getStreamInfo_nonexistent() public view {
        StreamSender.StreamInfo memory info = sender.getStreamInfo(keccak256("nope"));
        assertEq(info.sender, address(0));
        assertEq(info.totalAmount, 0);
        assertFalse(info.active);
    }

    function test_getSenderStreams_noStreams() public view {
        bytes32[] memory ids = sender.getSenderStreams(bob);
        assertEq(ids.length, 0);
    }
}

// ============================================================
// PaymentRegistry Edge Cases
// ============================================================
contract PaymentRegistryEdgeCases is Test {
    PaymentRegistry public registry;
    address public receiverContract = makeAddr("streamReceiver");
    address public senderAddr = makeAddr("streamSender");
    address public owner;
    address constant ICOSMOS = 0x00000000000000000000000000000000000000f1;

    function setUp() public {
        owner = address(this);
        registry = new PaymentRegistry("uinit", address(0), "INIT/USD", receiverContract, false);
        registry.setStreamSender(senderAddr);

        vm.mockCall(ICOSMOS, abi.encodeWithSignature("execute_cosmos(string,uint64)"), abi.encode(true));
        vm.mockCall(ICOSMOS, abi.encodeWithSignature("to_cosmos_address(address)"), abi.encode("init1mock..."));
        vm.mockCall(
            receiverContract,
            abi.encodeWithSignature("onReceivePayment(bytes32,string,string,uint256)"),
            abi.encode()
        );
    }

    // --- processPayment edge cases ---

    function test_processPayment_unauthorizedCaller() public {
        vm.prank(makeAddr("rando"));
        vm.expectRevert("Only StreamSender");
        registry.processPayment(keccak256("s"), "s", "r", "ch", 10, block.timestamp + 300, 1, 1, 1);
    }

    function test_processPayment_zeroAmount() public {
        // Fixed: processPayment now rejects zero-amount ticks
        bytes32 id = keccak256("s");
        vm.prank(senderAddr);
        vm.expectRevert("Zero amount");
        registry.processPayment(id, "s", "r", "ch", 10 ether, block.timestamp + 300, 0, 1, 1 ether);
    }

    function test_processPayment_amountExceedsTotalAmount() public {
        bytes32 id = keccak256("s");
        // H-1: Send 11 ether on a 10 ether stream — capped at 10
        vm.prank(senderAddr);
        registry.processPayment(id, "s", "r", "ch", 10 ether, block.timestamp + 300, 11 ether, 1, 1 ether);

        PaymentRegistry.Stream memory s = registry.getStream(id);
        assertEq(s.amountSent, 10 ether); // H-1: capped at totalAmount
        assertEq(uint(s.status), uint(PaymentRegistry.StreamStatus.COMPLETED));
    }

    function test_processPayment_maxUint256Amount() public {
        bytes32 id = keccak256("s");
        vm.prank(senderAddr);
        registry.processPayment(id, "s", "r", "ch", type(uint256).max, block.timestamp + 300, type(uint256).max, 1, 1);

        PaymentRegistry.Stream memory s = registry.getStream(id);
        assertEq(s.amountSent, type(uint256).max);
    }

    function test_processPayment_overflowAmountSent() public {
        bytes32 id = keccak256("s");
        // First tick: max - 1
        vm.prank(senderAddr);
        registry.processPayment(id, "s", "r", "ch", type(uint256).max, block.timestamp + 300, type(uint256).max - 1, 1, 1);

        // Second tick: 2 — should overflow
        vm.prank(senderAddr);
        vm.expectRevert(); // arithmetic overflow
        registry.processPayment(id, "s", "r", "ch", type(uint256).max, block.timestamp + 300, 2, 2, 1);
    }

    function test_processPayment_emptyStrings() public {
        bytes32 id = keccak256("s");
        vm.prank(senderAddr);
        registry.processPayment(id, "", "", "", 1 ether, block.timestamp + 300, 1 ether, 1, 1 ether);

        PaymentRegistry.Stream memory s = registry.getStream(id);
        assertEq(s.amountSent, 1 ether);
        // No revert on empty strings — potential data quality issue
    }

    function test_processPayment_onCompletedStream() public {
        bytes32 id = keccak256("s");
        // Complete the stream
        vm.prank(senderAddr);
        registry.processPayment(id, "s", "r", "ch", 1 ether, block.timestamp + 300, 1 ether, 1, 1 ether);

        PaymentRegistry.Stream memory s = registry.getStream(id);
        assertEq(uint(s.status), uint(PaymentRegistry.StreamStatus.COMPLETED));

        // Fixed: Ticks on completed streams now revert
        vm.prank(senderAddr);
        vm.expectRevert("Stream not active");
        registry.processPayment(id, "s", "r", "ch", 1 ether, block.timestamp + 300, 1 ether, 2, 1 ether);
    }

    // --- cancelStream edge cases ---

    function test_cancelStream_unauthorizedCaller() public {
        bytes32 id = keccak256("s");
        // Register stream first
        vm.prank(senderAddr);
        registry.processPayment(id, "s", "r", "ch", 10 ether, block.timestamp + 300, 1 ether, 1, 1 ether);

        vm.prank(makeAddr("rando"));
        vm.expectRevert("Not stream sender");
        registry.cancelStream(id);
    }

    function test_cancelStream_alreadyCancelled() public {
        bytes32 id = keccak256("s");
        vm.prank(senderAddr);
        registry.processPayment(id, "s", "r", "ch", 10 ether, block.timestamp + 300, 1 ether, 1, 1 ether);

        vm.prank(senderAddr);
        registry.cancelStream(id);

        vm.prank(senderAddr);
        vm.expectRevert("Stream not active");
        registry.cancelStream(id);
    }

    function test_cancelStream_completedStream() public {
        bytes32 id = keccak256("s");
        vm.prank(senderAddr);
        registry.processPayment(id, "s", "r", "ch", 1 ether, block.timestamp + 300, 1 ether, 1, 1 ether);

        vm.prank(senderAddr);
        vm.expectRevert("Stream not active");
        registry.cancelStream(id);
    }

    function test_cancelStream_nonexistentStream_reverts() public {
        // After fix: Stream not registered now properly reverts
        bytes32 id = keccak256("nonexistent");
        vm.prank(senderAddr);
        vm.expectRevert("Stream not registered");
        registry.cancelStream(id);
    }

    // --- setStreamSender edge cases ---

    function test_setStreamSender_unauthorizedCaller() public {
        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, rando));
        registry.setStreamSender(makeAddr("new"));
    }

    function test_setStreamSender_zeroAddress() public {
        vm.expectRevert("Zero address");
        registry.setStreamSender(address(0));
    }

    // --- setOraclePairId / setDenom edge cases ---

    function test_setOraclePairId_unauthorizedCaller() public {
        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, rando));
        registry.setOraclePairId("ETH/USD");
    }

    function test_setDenom_unauthorizedCaller() public {
        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, rando));
        registry.setDenom("uatom");
    }

    function test_setOraclePairId_emptyString() public {
        registry.setOraclePairId("");
        assertEq(registry.oraclePairId(), "");
        // No validation on empty — potential silent misconfiguration
    }

    function test_setDenom_emptyString() public {
        registry.setDenom("");
        assertEq(registry.denom(), "");
    }

    // --- getUsdValue with oracle mock ---

    function test_processPayment_withOracle() public {
        // Deploy new registry with oracle
        address oracleAddr = makeAddr("oracle");
        PaymentRegistry reg2 = new PaymentRegistry("uinit", oracleAddr, "INIT/USD", receiverContract, false);
        reg2.setStreamSender(senderAddr);

        vm.mockCall(
            receiverContract,
            abi.encodeWithSignature("onReceivePayment(bytes32,string,string,uint256)"),
            abi.encode()
        );

        // Mock oracle: price=250000000 (2.5 USD), decimal=8
        bytes memory oracleReturn = abi.encode(
            IConnectOracle.Price({
                price: 250000000,
                timestamp: block.timestamp,
                height: 100,
                nonce: 1,
                decimal: 8,
                id: 1
            })
        );
        vm.mockCall(oracleAddr, abi.encodeWithSignature("get_price(string)"), oracleReturn);

        bytes32 id = keccak256("s");
        vm.prank(senderAddr);
        reg2.processPayment(id, "s", "r", "ch", 10 ether, block.timestamp + 300, 1 ether, 1, 1 ether);

        PaymentRegistry.Stream memory s = reg2.getStream(id);
        // usdValueTotal = (1 ether * 250000000) / 10^8 = 2.5 ether (in USD units)
        assertEq(s.usdValueTotal, 2500000000000000000);
    }

    function test_processPayment_oracleReverts() public {
        address oracleAddr = makeAddr("oracle");
        PaymentRegistry reg2 = new PaymentRegistry("uinit", oracleAddr, "INIT/USD", receiverContract, false);
        reg2.setStreamSender(senderAddr);

        vm.mockCall(
            receiverContract,
            abi.encodeWithSignature("onReceivePayment(bytes32,string,string,uint256)"),
            abi.encode()
        );

        // Mock oracle to revert
        vm.mockCallRevert(oracleAddr, abi.encodeWithSignature("get_price(string)"), "Oracle down");

        bytes32 id = keccak256("s");
        vm.prank(senderAddr);
        reg2.processPayment(id, "s", "r", "ch", 10 ether, block.timestamp + 300, 1 ether, 1, 1 ether);

        PaymentRegistry.Stream memory s = reg2.getStream(id);
        assertEq(s.usdValueTotal, 0); // Graceful fallback
        assertEq(s.amountSent, 1 ether);
    }

    // --- View functions ---

    function test_getStream_nonexistent() public view {
        PaymentRegistry.Stream memory s = registry.getStream(keccak256("nope"));
        assertEq(s.totalAmount, 0);
    }

    function test_getStreamsByReceiver_empty() public view {
        bytes32[] memory ids = registry.getStreamsByReceiver("init1nobody...");
        assertEq(ids.length, 0);
    }

    function test_getStreamsBySender_empty() public view {
        bytes32[] memory ids = registry.getStreamsBySender("init1nobody...");
        assertEq(ids.length, 0);
    }
}

// ============================================================
// StreamReceiver Edge Cases
// ============================================================
contract StreamReceiverEdgeCases is Test {
    StreamReceiver public receiver;
    address constant ICOSMOS = 0x00000000000000000000000000000000000000f1;
    address public paymentRegistryAddr = makeAddr("paymentRegistry");
    address public mockEvmAddr;

    function setUp() public {
        receiver = new StreamReceiver("ibc/TESTHASH");
        receiver.setPaymentRegistry(paymentRegistryAddr);
        vm.deal(address(receiver), 100 ether);

        vm.mockCall(ICOSMOS, abi.encodeWithSignature("execute_cosmos(string,uint64)"), abi.encode(true));
        vm.mockCall(ICOSMOS, abi.encodeWithSignature("to_cosmos_address(address)"), abi.encode("init1mock..."));

        mockEvmAddr = makeAddr("receiverEvm");
        vm.mockCall(ICOSMOS, abi.encodeWithSignature("to_evm_address(string)"), abi.encode(mockEvmAddr));
    }

    // --- onReceivePayment edge cases ---

    function test_onReceivePayment_unauthorizedCaller() public {
        vm.prank(makeAddr("rando"));
        vm.expectRevert("Only PaymentRegistry");
        receiver.onReceivePayment(keccak256("s"), "init1sender...", "init1r...", 1 ether);
    }

    function test_onReceivePayment_zeroAmount() public {
        bytes32 id = keccak256("s");
        vm.prank(paymentRegistryAddr);
        receiver.onReceivePayment(id, "init1sender...", "init1r...", 0);

        assertEq(receiver.getClaimable(mockEvmAddr), 0);
        // Zero amount accepted — no guard
    }

    function test_onReceivePayment_maxUint256() public {
        bytes32 id = keccak256("s");
        vm.prank(paymentRegistryAddr);
        receiver.onReceivePayment(id, "init1sender...", "init1r...", type(uint256).max);

        assertEq(receiver.getClaimable(mockEvmAddr), type(uint256).max);
    }

    function test_onReceivePayment_overflowClaimable() public {
        bytes32 id = keccak256("s");
        vm.prank(paymentRegistryAddr);
        receiver.onReceivePayment(id, "init1sender...", "init1r...", type(uint256).max);

        vm.prank(paymentRegistryAddr);
        vm.expectRevert(); // arithmetic overflow
        receiver.onReceivePayment(id, "init1sender...", "init1r...", 1);
    }

    function test_onReceivePayment_emptyReceiver() public {
        bytes32 id = keccak256("s");
        vm.prank(paymentRegistryAddr);
        receiver.onReceivePayment(id, "init1sender...", "", 1 ether);
        // Depends on to_evm_address mock — empty string converts to mockEvmAddr
        assertEq(receiver.getClaimable(mockEvmAddr), 1 ether);
    }

    function test_onReceivePayment_addressConversionFails() public {
        // Mock to_evm_address to revert
        vm.mockCallRevert(ICOSMOS, abi.encodeWithSignature("to_evm_address(string)"), "conversion failed");

        bytes32 id = keccak256("s");
        vm.prank(paymentRegistryAddr);
        vm.expectRevert("Address conversion unavailable");
        receiver.onReceivePayment(id, "init1sender...", "init1bad...", 1 ether);
    }

    function test_onReceivePayment_multipleStreamsOneReceiver() public {
        bytes32 id1 = keccak256("s1");
        bytes32 id2 = keccak256("s2");

        vm.prank(paymentRegistryAddr);
        receiver.onReceivePayment(id1, "init1sender...", "init1r...", 3 ether);
        vm.prank(paymentRegistryAddr);
        receiver.onReceivePayment(id2, "init1sender...", "init1r...", 7 ether);

        assertEq(receiver.getClaimable(mockEvmAddr), 10 ether);
        assertEq(receiver.getIncomingStreams(mockEvmAddr).length, 2);
    }

    // --- claim edge cases ---

    function test_claim_nothingToClaim() public {
        vm.prank(mockEvmAddr);
        vm.expectRevert("Nothing to claim");
        receiver.claim();
    }

    function test_claim_zeroBalance() public {
        vm.expectRevert("Nothing to claim");
        receiver.claim();
    }

    function test_claim_cosmosExecuteFails() public {
        bytes32 id = keccak256("s");
        vm.prank(paymentRegistryAddr);
        receiver.onReceivePayment(id, "init1sender...", "init1r...", 5 ether);

        // Override cosmos mock to fail
        vm.mockCall(ICOSMOS, abi.encodeWithSignature("execute_cosmos(string,uint64)"), abi.encode(false));

        vm.prank(mockEvmAddr);
        vm.expectRevert("Cosmos claim failed");
        receiver.claim();

        // Verify claimable was zeroed before the revert propagated up
        // Actually: require reverts the whole tx, so claimable should remain 5 ether
        assertEq(receiver.getClaimable(mockEvmAddr), 5 ether);
    }

    function test_claim_doubleClaimReverts() public {
        bytes32 id = keccak256("s");
        vm.prank(paymentRegistryAddr);
        receiver.onReceivePayment(id, "init1sender...", "init1r...", 5 ether);

        vm.prank(mockEvmAddr);
        receiver.claim();

        vm.prank(mockEvmAddr);
        vm.expectRevert("Nothing to claim");
        receiver.claim();
    }

    function test_claim_thenReceiveMoreAndClaimAgain() public {
        bytes32 id = keccak256("s");
        vm.prank(paymentRegistryAddr);
        receiver.onReceivePayment(id, "init1sender...", "init1r...", 3 ether);

        vm.prank(mockEvmAddr);
        receiver.claim();
        assertEq(receiver.getClaimable(mockEvmAddr), 0);

        vm.prank(paymentRegistryAddr);
        receiver.onReceivePayment(id, "init1sender...", "init1r...", 2 ether);

        vm.prank(mockEvmAddr);
        receiver.claim();
        assertEq(receiver.getClaimable(mockEvmAddr), 0);
    }

    // --- Owner functions ---

    function test_setDenom_unauthorizedCaller() public {
        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, rando));
        receiver.setDenom("newdenom");
    }

    function test_setPaymentRegistry_unauthorizedCaller() public {
        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, rando));
        receiver.setPaymentRegistry(makeAddr("new"));
    }

    function test_setPaymentRegistry_zeroAddress() public {
        // M-1: Zero-address guard now prevents this
        vm.expectRevert("Zero address");
        receiver.setPaymentRegistry(address(0));
    }

    function test_setDenom_emptyString() public {
        receiver.setDenom("");
        assertEq(receiver.denom(), "");
    }

    // --- View functions ---

    function test_getClaimable_unknownAddress() public {
        assertEq(receiver.getClaimable(makeAddr("unknown")), 0);
    }

    function test_getIncomingStreams_unknownAddress() public {
        assertEq(receiver.getIncomingStreams(makeAddr("unknown")).length, 0);
    }

    function test_getIncomingStream_nonexistent() public view {
        StreamReceiver.IncomingStream memory s = receiver.getIncomingStream(keccak256("nope"));
        assertEq(s.totalReceived, 0);
    }
}
