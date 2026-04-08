// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// File: contracts/src/interfaces/IConnectOracle.sol

interface IConnectOracle {
    struct Price {
        uint256 price;
        uint256 timestamp;
        uint256 height;
        uint256 nonce;
        uint256 decimal;
        uint256 id;
    }

    /// @notice Get the price for a currency pair
    /// @param pair_id The pair identifier (e.g., "INIT/USD", "ETH/USD")
    /// @return The price data
    function get_price(string memory pair_id) external view returns (Price memory);

    /// @notice Get all available currency pairs
    /// @return Array of pair ID strings
    function get_all_currency_pairs() external view returns (string[] memory);
}
