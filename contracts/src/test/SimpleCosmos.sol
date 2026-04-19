// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICosmos {
    function execute_cosmos(string memory msg, uint64 execGas) external returns (bool);
    function to_cosmos_address(address addr) external view returns (string memory);
}

contract SimpleCosmos {
    ICosmos constant COSMOS = ICosmos(0x00000000000000000000000000000000000000f1);

    event Debug(string step, string data);
    event ExecResult(bool success);

    function getMyCosmosAddr() external view returns (string memory) {
        return COSMOS.to_cosmos_address(address(this));
    }

    // Step-by-step debug
    function testBankSendDebug(string calldata toAddr) external {
        emit Debug("step1", "getting cosmos addr");
        string memory sender = COSMOS.to_cosmos_address(address(this));
        emit Debug("step2_sender", sender);

        string memory msg1 = string(abi.encodePacked(
            '{"@type":"/cosmos.bank.v1beta1.MsgSend",',
            '"from_address":"', sender, '",',
            '"to_address":"', toAddr, '",',
            '"amount":[{"denom":"umin","amount":"1"}]}'
        ));
        emit Debug("step3_msg", msg1);

        bool result = COSMOS.execute_cosmos(msg1, 300000);
        emit ExecResult(result);
    }
}
