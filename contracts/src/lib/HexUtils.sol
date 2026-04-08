// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// File: contracts/src/lib/HexUtils.sol

library HexUtils {
    bytes16 private constant HEX_DIGITS = "0123456789abcdef";

    /// @notice Convert bytes to a hex string (without 0x prefix)
    function toHexString(bytes memory data) internal pure returns (string memory) {
        bytes memory result = new bytes(data.length * 2);
        for (uint256 i = 0; i < data.length; i++) {
            result[i * 2] = HEX_DIGITS[uint8(data[i]) >> 4];
            result[i * 2 + 1] = HEX_DIGITS[uint8(data[i]) & 0x0f];
        }
        return string(result);
    }

    /// @notice Convert an address to a hex string (with 0x prefix)
    function toHexString(address addr) internal pure returns (string memory) {
        return string(abi.encodePacked("0x", toHexString(abi.encodePacked(addr))));
    }
}
