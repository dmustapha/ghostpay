// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICosmos} from "../interfaces/ICosmos.sol";

contract HookToIbcTest {
    ICosmos constant COSMOS = ICosmos(0x00000000000000000000000000000000000000f1);
    event HookFired(bool ibcSent);
    event Debug(string step, string data);

    // This function will be called via IBC hook memo
    function onHookReceive(string calldata destChannel) external {
        string memory sender = COSMOS.to_cosmos_address(address(this));
        emit Debug("sender", sender);
        string memory msgTransfer = string(abi.encodePacked(
            '{"@type":"/ibc.applications.transfer.v1.MsgTransfer",',
            '"source_port":"transfer",',
            '"source_channel":"', destChannel, '",',
            '"token":{"denom":"umin","amount":"1"},',
            '"sender":"', sender, '",',
            '"receiver":"', sender, '",',
            '"timeout_timestamp":"1893456000000000000"}'
        ));
        emit Debug("msg", msgTransfer);
        bool result = COSMOS.execute_cosmos(msgTransfer, 300000);
        emit Debug("result", result ? "true" : "false");
        emit HookFired(true);
    }
}
