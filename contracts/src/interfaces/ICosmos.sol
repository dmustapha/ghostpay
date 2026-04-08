// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// File: contracts/src/interfaces/ICosmos.sol

interface ICosmos {
    /// @notice Execute a Cosmos SDK message as JSON string
    /// @param msg The JSON-encoded Cosmos SDK message
    function execute_cosmos(string memory msg) external;

    /// @notice Convert an EVM address to its corresponding bech32 Cosmos address
    /// @param addr The EVM address to convert
    /// @return The bech32-encoded Cosmos address string
    function to_cosmos_address(address addr) external view returns (string memory);

    /// @notice Convert a bech32 Cosmos address to its corresponding EVM address
    /// @param addr The bech32-encoded Cosmos address
    /// @return The EVM address
    function to_evm_address(string memory addr) external view returns (address);

    /// @notice Query a Cosmos SDK module via Stargate
    /// @param path The query path
    /// @param req The protobuf-encoded query request
    /// @return The protobuf-encoded query response
    function query_cosmos(string memory path, string memory req) external view returns (string memory);
}
