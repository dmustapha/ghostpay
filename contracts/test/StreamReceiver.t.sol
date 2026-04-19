// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// File: contracts/test/StreamReceiver.t.sol
// Updated: to_evm_address now mocked to succeed (catch block reverts instead of keccak fallback).

import "forge-std/Test.sol";
import "../src/StreamReceiver.sol";

contract StreamReceiverTest is Test {
    StreamReceiver public receiver;
    address constant ICOSMOS = 0x00000000000000000000000000000000000000f1;
    address public paymentRegistryAddr = makeAddr("paymentRegistry");
    address public mockEvmAddr;

    function setUp() public {
        receiver = new StreamReceiver("ibc/TESTHASH");
        receiver.setPaymentRegistry(paymentRegistryAddr); // wire access control
        vm.deal(address(receiver), 100 ether); // Fund contract for claims
        // DEV-003: Mock the correct 2-param signature
        vm.mockCall(ICOSMOS, abi.encodeWithSignature("execute_cosmos(string,uint64)"), abi.encode(true));
        vm.mockCall(
            ICOSMOS,
            abi.encodeWithSignature("to_cosmos_address(address)"),
            abi.encode("init1mockaddr...")
        );
        // Mock to_evm_address to succeed (catch block now reverts instead of keccak fallback)
        mockEvmAddr = makeAddr("receiverEvm");
        vm.mockCall(
            ICOSMOS,
            abi.encodeWithSignature("to_evm_address(string)"),
            abi.encode(mockEvmAddr)
        );
    }

    function test_onReceivePayment_creditsBalance() public {
        bytes32 streamId = keccak256("stream1");
        vm.prank(paymentRegistryAddr);
        receiver.onReceivePayment(streamId, "init1testrecv...", 5 ether);

        assertEq(receiver.getClaimable(mockEvmAddr), 5 ether);
    }

    function test_claim() public {
        bytes32 streamId = keccak256("stream1");
        vm.prank(paymentRegistryAddr);
        receiver.onReceivePayment(streamId, "init1testrecv...", 5 ether);

        vm.prank(mockEvmAddr);
        receiver.claim();

        assertEq(receiver.getClaimable(mockEvmAddr), 0);
        // Balance not checked here — claim sends via Cosmos bank send, mocked as no-op
    }

    function test_claim_revertNothingToClaim() public {
        vm.expectRevert("Nothing to claim");
        receiver.claim();
    }

    function test_multiplePaymentsAccumulate() public {
        bytes32 streamId = keccak256("stream1");
        vm.prank(paymentRegistryAddr);
        receiver.onReceivePayment(streamId, "init1testrecv...", 2 ether);
        vm.prank(paymentRegistryAddr);
        receiver.onReceivePayment(streamId, "init1testrecv...", 3 ether);

        assertEq(receiver.getClaimable(mockEvmAddr), 5 ether);

        StreamReceiver.IncomingStream memory s = receiver.getIncomingStream(streamId);
        assertEq(s.totalReceived, 5 ether);
    }
}
