// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// File: contracts/script/Deploy.s.sol

import "forge-std/Script.sol";
import "../src/StreamSender.sol";
import "../src/PaymentRegistry.sol";
import "../src/StreamReceiver.sol";

contract DeployStreamSender is Script {
    function run() external {
        string memory denom = vm.envString("STREAM_DENOM");
        address paymentRegistry = vm.envAddress("PAYMENT_REGISTRY_ADDRESS");

        vm.startBroadcast();
        // DEV-007: StreamSender now deploys on same chain as PaymentRegistry (Settlement)
        StreamSender sender = new StreamSender(denom, paymentRegistry);
        vm.stopBroadcast();

        console.log("StreamSender deployed at:", address(sender));
    }
}

contract DeployPaymentRegistry is Script {
    function run() external {
        string memory denom = vm.envString("STREAM_DENOM");
        address oracleAddress = vm.envAddress("ORACLE_ADDRESS");
        string memory oraclePairId = vm.envString("ORACLE_PAIR_ID");
        address streamReceiverAddress = vm.envAddress("STREAM_RECEIVER_ADDRESS");

        vm.startBroadcast();
        PaymentRegistry registry = new PaymentRegistry(denom, oracleAddress, oraclePairId, streamReceiverAddress);
        vm.stopBroadcast();

        console.log("PaymentRegistry deployed at:", address(registry));
    }
}

contract DeployStreamReceiver is Script {
    function run() external {
        string memory denom = vm.envString("STREAM_DENOM");

        vm.startBroadcast();
        StreamReceiver receiver = new StreamReceiver(denom);
        vm.stopBroadcast();

        console.log("StreamReceiver deployed at:", address(receiver));
    }
}

/// @notice Deploys all three contracts in correct order and wires access control.
/// Usage: forge script script/Deploy.s.sol:DeployAll --rpc-url $RPC --with-gas-price 0 --skip-simulation --broadcast
contract DeployAll is Script {
    function run() external {
        string memory denom = vm.envString("STREAM_DENOM");
        address oracleAddress = vm.envAddress("ORACLE_ADDRESS");
        string memory oraclePairId = vm.envString("ORACLE_PAIR_ID");

        vm.startBroadcast();

        // Deploy in dependency order: Receiver → Registry(receiver) → Sender(registry)
        StreamReceiver receiver = new StreamReceiver(denom);
        PaymentRegistry registry = new PaymentRegistry(denom, oracleAddress, oraclePairId, address(receiver));
        StreamSender sender = new StreamSender(denom, address(registry));

        // Wire access control post-deploy
        receiver.setPaymentRegistry(address(registry));
        registry.setStreamSender(address(sender));

        vm.stopBroadcast();

        console.log("StreamReceiver:", address(receiver));
        console.log("PaymentRegistry:", address(registry));
        console.log("StreamSender:", address(sender));
    }
}
