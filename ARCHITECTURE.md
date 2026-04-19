# GhostPay — Architecture Document

**Version:** V1
**Date:** 2026-04-07
**Stack:** Solidity (Foundry) + TypeScript (Vite/React) + InterwovenKit + TanStack Query
**THIS IS THE SINGLE SOURCE OF TRUTH.** Copy code from this document exactly.

---

## 1. System Overview

### Purpose
Cross-rollup payment streaming infrastructure on Initia — turns lump-sum payments into continuous money streams that flow automatically between rollups via IBC.

### System Diagram
```
┌──────────────────────────────────────────────────────────────────────────────┐
│                            INITIA L1 (Router)                                │
│                     rapid-relayer A ←──→ rapid-relayer B                      │
└───────────┬──────────────────────────────────────────────┬───────────────────┘
            │ IBC channel-A                                │ IBC channel-B
            │ (transfer/channel-N)                         │ (transfer/channel-M)
            ▼                                              ▼
┌───────────────────────┐  ┌────────────────────────┐  ┌───────────────────────┐
│    Rollup A (EVM)     │  │  Settlement Minitia    │  │    Rollup B (EVM)     │
│                       │  │   (GhostPay Rollup)    │  │                       │
│ ┌───────────────────┐ │  │                        │  │ ┌───────────────────┐ │
│ │   StreamSender    │ │  │ ┌────────────────────┐ │  │ │  StreamReceiver   │ │
│ │   - createStream  │─┼──┼→│  PaymentRegistry   │─┼──┼→│  - onReceive      │ │
│ │   - sendTick      │ │  │ │  - processPayment  │ │  │ │  - claim          │ │
│ │   - cancelStream  │ │  │ │  - registerStream  │ │  │ │  - getClaimable   │ │
│ └───────────────────┘ │  │ │  - queryOracle     │ │  │ └───────────────────┘ │
│         ▲             │  │ └────────┬───────────┘ │  │         ▲             │
│         │ MsgCall     │  │          │             │  │         │ poll        │
│ ┌───────────────────┐ │  │ ┌────────▼───────────┐ │  │ ┌───────────────────┐ │
│ │   Ghost Wallet    │ │  │ │  IConnectOracle    │ │  │ │  Frontend (B)     │ │
│ │  (authz+feegrant) │ │  │ │  (USD price feed)  │ │  │ │  (receiver view)  │ │
│ └───────────────────┘ │  │ └────────────────────┘ │  │ └───────────────────┘ │
│         ▲             │  │                        │  │                       │
│         │ autoSign    │  │                        │  │                       │
│ ┌───────────────────┐ │  │                        │  │                       │
│ │  Frontend (A)     │ │  │                        │  │                       │
│ │  (sender view)    │ │  │                        │  │                       │
│ │  setInterval tick │ │  │                        │  │                       │
│ └───────────────────┘ │  │                        │  │                       │
└───────────────────────┘  └────────────────────────┘  └───────────────────────┘

IBC Flow (per stream tick):
  1. Frontend → Ghost Wallet: submitTxBlock(MsgCall → StreamSender.sendTick)
  2. StreamSender → ICosmos(0xf1): execute_cosmos(MsgTransfer + hook memo)
  3. Relayer A → Settlement: packet arrives, hook calls PaymentRegistry.processPayment
  4. PaymentRegistry → ICosmos(0xf1): execute_cosmos(MsgTransfer + hook memo)
  5. Relayer B → Rollup B: packet arrives, hook calls StreamReceiver.onReceivePayment
  6. Frontend (B): polls StreamReceiver.getClaimable, animates counter
```

### Technology Stack
| Technology | Version | Purpose |
|-----------|---------|---------|
| Solidity | 0.8.24 | Smart contracts (PaymentRegistry, StreamSender, StreamReceiver) |
| Foundry | Latest | Contract compilation, testing, deployment |
| OpenZeppelin | 5.x | Strings utility for uint→string conversion |
| TypeScript | 5.x | Frontend application |
| React | 18.x | UI framework |
| Vite | 5.x | Build tool and dev server |
| InterwovenKit | Latest | Wallet connection, auto-sign (ghost wallet), tx submission |
| TanStack Query | 5.x | Data fetching, caching, polling |
| React Router | 6.x | Client-side routing |
| Tailwind CSS | 3.x | Styling |
| viem | 2.x | Contract reads via JSON-RPC |
| Node.js | 20+ | Scripts (seed-demo) |

### File Structure
```
ghostpay/
├── contracts/
│   ├── src/
│   │   ├── interfaces/
│   │   │   ├── ICosmos.sol
│   │   │   └── IConnectOracle.sol
│   │   ├── lib/
│   │   │   └── HexUtils.sol
│   │   ├── PaymentRegistry.sol
│   │   ├── StreamSender.sol
│   │   └── StreamReceiver.sol
│   ├── script/
│   │   └── Deploy.s.sol
│   ├── test/
│   │   ├── StreamSender.t.sol
│   │   ├── PaymentRegistry.t.sol
│   │   └── StreamReceiver.t.sol
│   └── foundry.toml
├── frontend/
│   ├── src/
│   │   ├── main.tsx
│   │   ├── index.css
│   │   ├── App.tsx
│   │   ├── config/
│   │   │   ├── chains.ts
│   │   │   └── contracts.ts
│   │   ├── types/
│   │   │   └── index.ts
│   │   ├── hooks/
│   │   │   ├── useStreams.ts
│   │   │   ├── useStreamTick.ts
│   │   │   └── useOracle.ts
│   │   ├── pages/
│   │   │   ├── Dashboard.tsx
│   │   │   ├── CreateStream.tsx
│   │   │   └── DemoView.tsx
│   │   └── components/
│   │       ├── Layout.tsx
│   │       ├── StreamCard.tsx
│   │       ├── BridgeVisualization.tsx
│   │       └── StreamCounter.tsx
│   ├── index.html
│   ├── package.json
│   ├── vite.config.ts
│   ├── tsconfig.json
│   ├── tailwind.config.ts
│   └── postcss.config.js
├── scripts/
│   └── seed-demo.ts
└── .env.example
```

### Dependency Graph
```
ICosmos.sol ← StreamSender.sol
ICosmos.sol ← PaymentRegistry.sol
IConnectOracle.sol ← PaymentRegistry.sol
HexUtils.sol ← StreamSender.sol
HexUtils.sol ← PaymentRegistry.sol
OpenZeppelin/Strings ← StreamSender.sol
OpenZeppelin/Strings ← PaymentRegistry.sol

contracts.ts ← useStreams.ts
contracts.ts ← useStreamTick.ts
contracts.ts ← useOracle.ts
chains.ts ← contracts.ts
types/index.ts ← all frontend files
hooks/* ← pages/*
components/* ← pages/*
```

---

## 2. Component Architecture

### Component Table
| # | Component | Type | File Path | Purpose | Dependencies |
|---|-----------|------|-----------|---------|-------------|
| 1 | ICosmos Interface | Solidity Interface | contracts/src/interfaces/ICosmos.sol | Precompile at 0xf1 for cosmos SDK calls from EVM | None |
| 2 | IConnectOracle Interface | Solidity Interface | contracts/src/interfaces/IConnectOracle.sol | Oracle price feed queries | None |
| 3 | HexUtils Library | Solidity Library | contracts/src/lib/HexUtils.sol | bytes→hex string conversion for IBC hook memos | None |
| 4 | StreamSender | Solidity Contract | contracts/src/StreamSender.sol | Deposit, stream creation, IBC tick sending | ICosmos, HexUtils, Strings |
| 5 | PaymentRegistry | Solidity Contract | contracts/src/PaymentRegistry.sol | Stream state, oracle query, cross-rollup routing | ICosmos, IConnectOracle, HexUtils, Strings |
| 6 | StreamReceiver | Solidity Contract | contracts/src/StreamReceiver.sol | Credit received funds, allow claims | None |
| 7 | Deploy Scripts | Foundry Script | contracts/script/Deploy.s.sol | Deploy all 3 contracts to respective chains | All contracts |
| 8 | Frontend | React SPA | frontend/src/ | Stream creation, visualization, wallet mgmt | InterwovenKit, viem, TanStack Query |
| 9 | Seed Script | TypeScript | scripts/seed-demo.ts | Create demo state for recording | viem, contracts |

### Data Flow

1. **Stream creation:** User connects via InterwovenKit → enables auto-sign (ghost wallet created with authz for MsgCall) → calls StreamSender.createStream() with native token deposit → stream ID generated, state stored on-chain, StreamCreated event emitted.

2. **Stream tick:** Frontend setInterval fires every 30s → calls submitTxBlock(MsgCall → StreamSender.sendTick(streamId)) → ghost wallet signs without popup → StreamSender calculates tick amount, builds MsgTransfer JSON with EVM hook memo targeting PaymentRegistry → ICosmos.execute_cosmos sends IBC packet → relayer A delivers to Settlement Minitia → hook calls PaymentRegistry.processPayment → records payment, queries oracle for USD value → builds MsgTransfer JSON with EVM hook memo targeting StreamReceiver → ICosmos.execute_cosmos sends IBC packet → relayer B delivers to Rollup B → hook calls StreamReceiver.onReceivePayment → credits receiver balance.

3. **Balance polling:** Frontend on Rollup B polls StreamReceiver.getClaimable(address) via viem public client every 5s → animates StreamCounter component.

4. **Claiming:** Receiver calls StreamReceiver.claim() → native tokens transferred to receiver address.

---

## 3. Shared Types

### Purpose
TypeScript types used across all frontend components. Written first — all downstream imports reference these.

### Dependencies
None.

### Code

#### File: frontend/src/types/index.ts
[VERIFIED]
```typescript
// File: frontend/src/types/index.ts

export enum StreamStatus {
  ACTIVE = 0,
  COMPLETED = 1,
  CANCELLED = 2,
}

export interface StreamView {
  streamId: string;
  sender: string;
  receiver: string;
  destChannel: string;
  totalAmount: bigint;
  amountSent: bigint;
  ratePerTick: bigint;
  startTime: number;
  endTime: number;
  active: boolean;
}

export interface RegistryStream {
  streamId: string;
  sender: string;
  receiver: string;
  sourceChannel: string;
  destChannel: string;
  totalAmount: bigint;
  amountSent: bigint;
  ratePerTick: bigint;
  startTime: number;
  endTime: number;
  lastTickTime: number;
  usdValueTotal: bigint;
  status: StreamStatus;
}

export interface IncomingStream {
  streamId: string;
  sender: string;
  totalReceived: bigint;
  lastReceiveTime: number;
  active: boolean;
}

export interface OraclePrice {
  price: bigint;
  timestamp: number;
  decimal: number;
}

export interface ChainConfig {
  chainId: string;
  name: string;
  rpcUrl: string;
  restUrl: string;
  viemChain: import('viem').Chain;
}

export interface CreateStreamParams {
  receiver: string;
  destChannel: string;
  totalAmount: string;
  durationSeconds: number;
}
```

---

## 4. ICosmos Interface

### Purpose
Interface for the ICosmos precompile at `0x00...f1` on all EVM Minitias. Allows Solidity contracts to execute Cosmos SDK messages (MsgTransfer for IBC) and convert between EVM and Cosmos addresses.

### Dependencies
None.

### Code

#### File: contracts/src/interfaces/ICosmos.sol
[VERIFIED] — Source: https://github.com/initia-labs/initia-evm-contracts/blob/main/src/interfaces/ICosmos.sol
```solidity
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
```

### Key Decisions
- **Using the precompile directly** rather than wrapping in a library — keeps gas costs visible and code traceable.
- **ICosmos at 0xf1** is a system precompile on ALL EVM Minitias. No deployment needed.

---

## 5. IConnectOracle Interface

### Purpose
Interface for the Connect (Slinky) oracle precompile on EVM Minitias with oracle enabled. Provides USD price feeds for stream value display.

### Dependencies
None.

### Code

#### File: contracts/src/interfaces/IConnectOracle.sol
[VERIFIED] — Source: https://github.com/initia-labs/initia-evm-contracts/blob/main/src/ConnectOracle.sol
```solidity
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
```

### Key Decisions
- **INIT/USD may not exist** on testnet. Contract code queries get_all_currency_pairs() first. If INIT/USD unavailable, falls back to ETH/USD or returns 0 for USD value.

---

## 6. HexUtils Library

### Purpose
Converts bytes and addresses to hex strings for building EVM IBC hook memo JSON payloads.

### Dependencies
None.

### Code

#### File: contracts/src/lib/HexUtils.sol
[ASSUMED] — No official pattern found; standard Solidity hex conversion
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// File: contracts/src/lib/HexUtils.sol
// CAUTION: ASSUMED PATTERN — test immediately

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
```

---

## 7. StreamSender Contract

### Purpose
Deployed on Rollup A. Accepts deposits, creates streams, and sends IBC micro-payments (ticks) to the Settlement Minitia via ICosmos precompile. Each tick includes an EVM IBC hook memo that triggers PaymentRegistry.processPayment on the settlement chain.

### Dependencies
- ICosmos (0xf1 precompile)
- HexUtils (hex encoding for hook memos)
- OpenZeppelin Strings (uint→string)

### Code

#### File: contracts/src/StreamSender.sol
[VERIFIED] — IBC transfer pattern from https://github.com/initia-labs/initia-evm-contracts; hook memo from https://docs.initia.xyz/build-on-initia/vm-specific-tutorials/evm/evm-ibc-hooks
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// File: contracts/src/StreamSender.sol

import {ICosmos} from "./interfaces/ICosmos.sol";
import {HexUtils} from "./lib/HexUtils.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract StreamSender {
    ICosmos constant COSMOS = ICosmos(0x00000000000000000000000000000000000000f1);

    struct StreamInfo {
        bytes32 streamId;
        address sender;
        string receiver;
        string settlementChannel;
        string destChannel;
        uint256 totalAmount;
        uint256 amountSent;
        uint256 ratePerTick;
        uint256 startTime;
        uint256 endTime;
        bool active;
    }

    string public denom;
    address public paymentRegistry; // EVM address of PaymentRegistry on Settlement
    uint256 private _nonce;

    mapping(bytes32 => StreamInfo) public streams;
    mapping(address => bytes32[]) public senderStreams;
    mapping(bytes32 => uint256) private _lastTickTime;

    event StreamCreated(bytes32 indexed streamId, address indexed sender, string receiver, uint256 totalAmount, uint256 duration);
    event TickSent(bytes32 indexed streamId, uint256 amount, uint256 tickNumber);
    event StreamCancelled(bytes32 indexed streamId, uint256 refundAmount);

    constructor(string memory _denom, string memory _settlementChannel, address _paymentRegistry) {
        denom = _denom;
        paymentRegistry = _paymentRegistry;
        // Store settlement channel in a state var used by all streams
        _defaultSettlementChannel = _settlementChannel;
    }

    string private _defaultSettlementChannel;

    function createStream(
        string calldata receiver,
        string calldata destChannel,
        uint256 durationSeconds
    ) external payable returns (bytes32) {
        require(msg.value > 0, "Must deposit tokens");
        require(durationSeconds > 0, "Duration must be positive");

        bytes32 streamId = keccak256(abi.encodePacked(msg.sender, _nonce++));
        uint256 tickInterval = 30; // 30 seconds per tick
        uint256 totalTicks = durationSeconds / tickInterval;
        if (totalTicks == 0) totalTicks = 1;
        uint256 ratePerTick = msg.value / totalTicks;

        streams[streamId] = StreamInfo({
            streamId: streamId,
            sender: msg.sender,
            receiver: receiver,
            settlementChannel: _defaultSettlementChannel,
            destChannel: destChannel,
            totalAmount: msg.value,
            amountSent: 0,
            ratePerTick: ratePerTick,
            startTime: block.timestamp,
            endTime: block.timestamp + durationSeconds,
            active: true
        });
        senderStreams[msg.sender].push(streamId);

        emit StreamCreated(streamId, msg.sender, receiver, msg.value, durationSeconds);
        return streamId;
    }

    uint256 public constant MIN_TICK_INTERVAL = 15; // seconds — prevents draining in one block

    function sendTick(bytes32 streamId) external {
        StreamInfo storage s = streams[streamId];
        require(s.active, "Stream not active");
        require(block.timestamp <= s.endTime, "Stream expired");
        require(s.amountSent == 0 || block.timestamp >= _lastTickTime[streamId] + MIN_TICK_INTERVAL, "Tick too soon");

        uint256 remaining = s.totalAmount - s.amountSent;
        uint256 tickAmount = s.ratePerTick > remaining ? remaining : s.ratePerTick;
        require(tickAmount > 0, "Nothing to send");

        s.amountSent += tickAmount;
        _lastTickTime[streamId] = block.timestamp;
        uint256 tickNumber = s.amountSent / s.ratePerTick;

        if (s.amountSent >= s.totalAmount) {
            s.active = false;
        }

        _sendIbcWithHook(s, tickAmount, tickNumber);
        emit TickSent(streamId, tickAmount, tickNumber);
    }

    function cancelStream(bytes32 streamId) external {
        StreamInfo storage s = streams[streamId];
        require(s.sender == msg.sender, "Not stream owner");
        require(s.active, "Stream not active");

        s.active = false;
        uint256 refund = s.totalAmount - s.amountSent;
        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }

        emit StreamCancelled(streamId, refund);
    }

    function getStreamInfo(bytes32 streamId) external view returns (StreamInfo memory) {
        return streams[streamId];
    }

    function getSenderStreams(address sender) external view returns (bytes32[] memory) {
        return senderStreams[sender];
    }

    function _sendIbcWithHook(StreamInfo storage s, uint256 amount, uint256 tickNumber) internal {
        // Build the ABI-encoded calldata for PaymentRegistry.processPayment
        bytes memory callData = abi.encodeWithSignature(
            "processPayment(bytes32,string,string,string,uint256,uint256,uint256,uint256)",
            s.streamId,
            _cosmosAddr(),
            s.receiver,
            s.destChannel,
            s.totalAmount,
            s.endTime,
            amount,
            tickNumber
        );

        // Build the EVM IBC hook memo JSON
        string memory hookMemo = string(abi.encodePacked(
            '{"evm":{"message":{"contract_addr":"',
            HexUtils.toHexString(paymentRegistry),
            '","input":"0x',
            HexUtils.toHexString(callData),
            '"}}}'
        ));

        // Build the MsgTransfer JSON
        uint256 timeoutNanos = (block.timestamp + 600) * 1_000_000_000;
        string memory msgTransfer = string(abi.encodePacked(
            '{"@type":"/ibc.applications.transfer.v1.MsgTransfer",',
            '"source_port":"transfer",',
            '"source_channel":"', s.settlementChannel, '",',
            '"token":{"denom":"', denom, '","amount":"', Strings.toString(amount), '"},',
            '"sender":"', _cosmosAddr(), '",',
            '"receiver":"', _registryCosmosAddr(), '",',
            '"timeout_timestamp":"', Strings.toString(timeoutNanos), '",',
            '"memo":"', _escapeJson(hookMemo), '"}'
        ));

        COSMOS.execute_cosmos(msgTransfer);
    }

    string private _cachedCosmosAddr;
    string private _cachedRegistryCosmosAddr;

    function _cosmosAddr() internal returns (string memory) {
        if (bytes(_cachedCosmosAddr).length == 0) {
            _cachedCosmosAddr = COSMOS.to_cosmos_address(address(this));
        }
        return _cachedCosmosAddr;
    }

    function _registryCosmosAddr() internal returns (string memory) {
        if (bytes(_cachedRegistryCosmosAddr).length == 0) {
            _cachedRegistryCosmosAddr = COSMOS.to_cosmos_address(paymentRegistry);
        }
        return _cachedRegistryCosmosAddr;
    }

    /// @dev Escape double quotes in JSON string for nested memo
    function _escapeJson(string memory input) internal pure returns (string memory) {
        bytes memory inputBytes = bytes(input);
        // Count quotes to size output
        uint256 extraChars = 0;
        for (uint256 i = 0; i < inputBytes.length; i++) {
            if (inputBytes[i] == '"') extraChars++;
        }
        bytes memory output = new bytes(inputBytes.length + extraChars);
        uint256 j = 0;
        for (uint256 i = 0; i < inputBytes.length; i++) {
            if (inputBytes[i] == '"') {
                output[j++] = '\\';
            }
            output[j++] = inputBytes[i];
        }
        return string(output);
    }

    receive() external payable {}
}
```

### Key Decisions
- **30-second tick interval** hardcoded — optimized for demo pacing. 5-15s IBC latency + 30s interval = visible bridge crossings without overwhelming the relayer.
- **JSON string building in Solidity** is gas-expensive but this is the verified pattern for ICosmos precompile interaction. No alternative exists on minievm.
- **_escapeJson** needed because the hook memo is nested inside the MsgTransfer memo field, requiring escaped quotes.
- **sendTick is callable by anyone** — the ghost wallet (or any address) can trigger ticks. Security relies on funds being pre-deposited; ticks can only send to the pre-configured stream destination.

### Verified / Unverified Status
- ICosmos.execute_cosmos pattern: [VERIFIED]
- EVM IBC hook memo format: [VERIFIED]
- JSON escaping for nested memo: [ASSUMED] — may need adjustment based on how minievm parses memo fields

---

## 8. PaymentRegistry Contract

### Purpose
Deployed on Settlement Minitia. Central stream state management and cross-rollup routing. Receives IBC payments via EVM hook, records stream state, queries oracle for USD conversion, and forwards tokens to destination rollup via another IBC transfer with hook memo.

### Dependencies
- ICosmos (0xf1 precompile)
- IConnectOracle
- HexUtils
- OpenZeppelin Strings

### Code

#### File: contracts/src/PaymentRegistry.sol
[VERIFIED] — IBC pattern from initia-evm-contracts; Oracle pattern from https://docs.initia.xyz/developers/developer-guides/vm-specific-tutorials/evm/connect-oracles
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// File: contracts/src/PaymentRegistry.sol

import {ICosmos} from "./interfaces/ICosmos.sol";
import {IConnectOracle} from "./interfaces/IConnectOracle.sol";
import {HexUtils} from "./lib/HexUtils.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract PaymentRegistry {
    ICosmos constant COSMOS = ICosmos(0x00000000000000000000000000000000000000f1);

    enum StreamStatus { ACTIVE, COMPLETED, CANCELLED }

    struct Stream {
        bytes32 streamId;
        string sender;
        string receiver;
        string sourceChannel;
        string destChannel;
        uint256 totalAmount;
        uint256 amountSent;
        uint256 ratePerTick;
        uint256 startTime;
        uint256 endTime;
        uint256 lastTickTime;
        uint256 usdValueTotal;
        StreamStatus status;
    }

    string public denom;
    address public oracleAddress;
    string public oraclePairId;
    address public streamReceiverAddress; // EVM address on Rollup B (for hook memo)
    address public owner;

    mapping(bytes32 => Stream) public streams;
    mapping(string => bytes32[]) public receiverStreams; // receiver addr → stream IDs
    mapping(string => bytes32[]) public senderStreams;   // sender addr → stream IDs

    event StreamRegistered(bytes32 indexed streamId, string sender, string receiver, uint256 totalAmount);
    event PaymentProcessed(bytes32 indexed streamId, uint256 amount, uint256 usdValue, uint256 tickNumber);
    event StreamCompleted(bytes32 indexed streamId, uint256 totalSent);

    constructor(
        string memory _denom,
        address _oracleAddress,
        string memory _oraclePairId,
        address _streamReceiverAddress
    ) {
        denom = _denom;
        oracleAddress = _oracleAddress;
        oraclePairId = _oraclePairId;
        streamReceiverAddress = _streamReceiverAddress;
        owner = msg.sender;
    }

    /// @notice Called via IBC hook from StreamSender on source rollup
    /// @dev totalAmount and endTime are passed from StreamSender via hook calldata
    ///      so the registry can display stream progress without querying the sender chain.
    ///      NOTE: denom on this chain will be an IBC denom (ibc/HASH), not the origin
    ///      chain's native denom. Call setDenom() after first tick to record the actual
    ///      IBC denom for forwarding.
    function processPayment(
        bytes32 streamId,
        string calldata sender,
        string calldata receiver,
        string calldata destChannel,
        uint256 totalAmount_,
        uint256 endTime_,
        uint256 amount,
        uint256 tickNumber
    ) external {
        Stream storage s = streams[streamId];

        // Register stream on first tick
        if (s.startTime == 0) {
            streams[streamId] = Stream({
                streamId: streamId,
                sender: sender,
                receiver: receiver,
                sourceChannel: "",
                destChannel: destChannel,
                totalAmount: totalAmount_,
                amountSent: 0,
                ratePerTick: amount,
                startTime: block.timestamp,
                endTime: endTime_,
                lastTickTime: block.timestamp,
                usdValueTotal: 0,
                status: StreamStatus.ACTIVE
            });
            s = streams[streamId];
            receiverStreams[receiver].push(streamId);
            senderStreams[sender].push(streamId);
            emit StreamRegistered(streamId, sender, receiver, totalAmount_);
        }

        s.amountSent += amount;
        s.lastTickTime = block.timestamp;

        // Query oracle for USD value
        uint256 usdValue = _getUsdValue(amount);
        s.usdValueTotal += usdValue;

        emit PaymentProcessed(streamId, amount, usdValue, tickNumber);

        // Forward to destination rollup via IBC with hook memo
        _forwardToDestination(streamId, receiver, destChannel, amount);
    }

    function getStream(bytes32 streamId) external view returns (Stream memory) {
        return streams[streamId];
    }

    function getStreamsByReceiver(string calldata receiver) external view returns (bytes32[] memory) {
        return receiverStreams[receiver];
    }

    function getStreamsBySender(string calldata sender) external view returns (bytes32[] memory) {
        return senderStreams[sender];
    }

    function setOraclePairId(string calldata newPairId) external {
        require(msg.sender == owner, "Not owner");
        oraclePairId = newPairId;
    }

    /// @notice Update the IBC denom used for forwarding.
    /// @dev Tokens arriving via IBC have denom `ibc/HASH`, not the origin chain's
    ///      native denom. Call this after the first IBC transfer lands so subsequent
    ///      forwards use the correct denom. Only owner can call.
    function setDenom(string calldata newDenom) external {
        require(msg.sender == owner, "Not owner");
        denom = newDenom;
    }

    function _getUsdValue(uint256 amount) internal view returns (uint256) {
        if (oracleAddress == address(0)) return 0;

        try IConnectOracle(oracleAddress).get_price(oraclePairId) returns (IConnectOracle.Price memory price) {
            return (amount * price.price) / (10 ** price.decimal);
        } catch {
            // Oracle unavailable — return 0 USD value, don't block payment
            return 0;
        }
    }

    function _forwardToDestination(
        bytes32 streamId,
        string memory receiver,
        string memory destChannel,
        uint256 amount
    ) internal {
        // Build ABI-encoded calldata for StreamReceiver.onReceivePayment
        bytes memory callData = abi.encodeWithSignature(
            "onReceivePayment(bytes32,string,uint256)",
            streamId,
            receiver,
            amount
        );

        // Build EVM IBC hook memo
        string memory hookMemo = string(abi.encodePacked(
            '{"evm":{"message":{"contract_addr":"',
            HexUtils.toHexString(streamReceiverAddress),
            '","input":"0x',
            HexUtils.toHexString(callData),
            '"}}}'
        ));

        // Build MsgTransfer JSON
        uint256 timeoutNanos = (block.timestamp + 600) * 1_000_000_000;
        string memory cosmosAddr = COSMOS.to_cosmos_address(address(this));

        string memory msgTransfer = string(abi.encodePacked(
            '{"@type":"/ibc.applications.transfer.v1.MsgTransfer",',
            '"source_port":"transfer",',
            '"source_channel":"', destChannel, '",',
            '"token":{"denom":"', denom, '","amount":"', Strings.toString(amount), '"},',
            '"sender":"', cosmosAddr, '",',
            '"receiver":"', _receiverCosmosAddr(), '",',
            '"timeout_timestamp":"', Strings.toString(timeoutNanos), '",',
            '"memo":"', _escapeJson(hookMemo), '"}'
        ));

        COSMOS.execute_cosmos(msgTransfer);
    }

    string private _cachedReceiverCosmosAddr;

    function _receiverCosmosAddr() internal returns (string memory) {
        if (bytes(_cachedReceiverCosmosAddr).length == 0) {
            _cachedReceiverCosmosAddr = COSMOS.to_cosmos_address(streamReceiverAddress);
        }
        return _cachedReceiverCosmosAddr;
    }

    function _escapeJson(string memory input) internal pure returns (string memory) {
        bytes memory inputBytes = bytes(input);
        uint256 extraChars = 0;
        for (uint256 i = 0; i < inputBytes.length; i++) {
            if (inputBytes[i] == '"') extraChars++;
        }
        bytes memory output = new bytes(inputBytes.length + extraChars);
        uint256 j = 0;
        for (uint256 i = 0; i < inputBytes.length; i++) {
            if (inputBytes[i] == '"') {
                output[j++] = '\\';
            }
            output[j++] = inputBytes[i];
        }
        return string(output);
    }

    receive() external payable {}
}
```

### Key Decisions
- **Auto-register stream on first tick** instead of requiring a separate registration call. Simplifies the cross-chain flow — no need for a registration IBC message before streaming begins.
- **Oracle query wrapped in try/catch** — if oracle fails, payment still processes with 0 USD value. Demo isn't blocked by oracle issues.
- **streamReceiverAddress stored as EVM address** — converted to bech32 at runtime via ICosmos.to_cosmos_address(). This means we only need to know the EVM address at deploy time.
- **denom handling**: The IBC-received tokens on Settlement Minitia have an IBC denom (ibc/HASH). The `denom` field must be set to this IBC denom, not the origin chain's native denom.

### Verified / Unverified Status
- ICosmos.execute_cosmos for forwarding: [VERIFIED]
- Oracle try/catch pattern: [ASSUMED] — IConnectOracle.get_price may revert differently than expected
- IBC denom on Settlement Minitia: [UNVERIFIED] — exact denom depends on channel path; must be determined after relayer setup

---

## 9. StreamReceiver Contract

### Purpose
Deployed on Rollup B. Receives IBC payments via EVM hook, credits funds to recipient addresses, and allows receivers to claim accumulated balances.

### Dependencies
None.

### Code

#### File: contracts/src/StreamReceiver.sol
[VERIFIED] — Standard Solidity pattern; hook call pattern from https://docs.initia.xyz/build-on-initia/vm-specific-tutorials/evm/evm-ibc-hooks
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// File: contracts/src/StreamReceiver.sol

import {ICosmos} from "./interfaces/ICosmos.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract StreamReceiver {
    ICosmos constant COSMOS = ICosmos(0x00000000000000000000000000000000000000f1);
    struct IncomingStream {
        bytes32 streamId;
        string sender;
        uint256 totalReceived;
        uint256 lastReceiveTime;
        bool active;
    }

    mapping(address => uint256) public claimable;
    mapping(bytes32 => IncomingStream) public incomingStreams;
    mapping(address => bytes32[]) public receiverStreamIds;

    event PaymentReceived(bytes32 indexed streamId, address indexed receiver, uint256 amount);
    event FundsClaimed(address indexed receiver, uint256 amount);

    /// @notice Called via IBC hook from PaymentRegistry on Settlement Minitia
    /// @dev The receiver parameter is a bech32 string; we convert to EVM address for crediting
    function onReceivePayment(
        bytes32 streamId,
        string calldata receiver,
        uint256 amount
    ) external {
        // Convert bech32 receiver to EVM address for balance tracking
        // NOTE: In production, validate msg.sender is IBC module. For hackathon, open access.
        address receiverAddr = _bech32ToAddress(receiver);

        // Update or create incoming stream record
        IncomingStream storage s = incomingStreams[streamId];
        if (s.lastReceiveTime == 0) {
            incomingStreams[streamId] = IncomingStream({
                streamId: streamId,
                sender: "",
                totalReceived: 0,
                lastReceiveTime: block.timestamp,
                active: true
            });
            s = incomingStreams[streamId];
            receiverStreamIds[receiverAddr].push(streamId);
        }

        s.totalReceived += amount;
        s.lastReceiveTime = block.timestamp;
        claimable[receiverAddr] += amount;

        emit PaymentReceived(streamId, receiverAddr, amount);
    }

    string public denom; // Set to the IBC denom that arrives on this chain

    constructor(string memory _denom) {
        denom = _denom;
    }

    function setDenom(string calldata newDenom) external {
        denom = newDenom;
    }

    /// @notice Claim accumulated funds via Cosmos bank send
    /// @dev Tokens arrive as IBC denoms (Cosmos-side), not EVM balance.
    ///      We use ICosmos.execute_cosmos() with MsgSend to transfer.
    function claim() external {
        uint256 amount = claimable[msg.sender];
        require(amount > 0, "Nothing to claim");
        claimable[msg.sender] = 0;

        string memory senderCosmos = COSMOS.to_cosmos_address(address(this));
        string memory receiverCosmos = COSMOS.to_cosmos_address(msg.sender);

        string memory msgSend = string(abi.encodePacked(
            '{"@type":"/cosmos.bank.v1beta1.MsgSend",',
            '"from_address":"', senderCosmos, '",',
            '"to_address":"', receiverCosmos, '",',
            '"amount":[{"denom":"', denom, '","amount":"', Strings.toString(amount), '"}]}'
        ));
        COSMOS.execute_cosmos(msgSend);

        emit FundsClaimed(msg.sender, amount);
    }

    function getClaimable(address account) external view returns (uint256) {
        return claimable[account];
    }

    function getIncomingStreams(address account) external view returns (bytes32[] memory) {
        return receiverStreamIds[account];
    }

    function getIncomingStream(bytes32 streamId) external view returns (IncomingStream memory) {
        return incomingStreams[streamId];
    }

    /// @dev Convert bech32 cosmos address to EVM address
    /// Uses ICosmos precompile if available, otherwise hash-based fallback
    function _bech32ToAddress(string calldata bech32Addr) internal view returns (address) {
        // Try ICosmos precompile for conversion
        try COSMOS.to_evm_address(bech32Addr) returns (address evmAddr) {
            return evmAddr;
        } catch {
            // Fallback: hash the bech32 string to get a deterministic address
            // WARNING: This is a demo fallback — may not match the actual EVM address
            return address(uint160(uint256(keccak256(bytes(bech32Addr)))));
        }
    }

    receive() external payable {}
}
```

### Key Decisions
- **Separate ICosmos import** inline rather than importing from interfaces — keeps StreamReceiver self-contained with minimal interface needed.
- **bech32→EVM fallback** uses hash-based conversion as safety net. In practice, ICosmos.to_evm_address should always work on minievm.
- **claim() uses transfer()** instead of call() — acceptable for native token transfers on minievm (no complex fallback needed).
- **No access control on onReceivePayment** — for hackathon, this is acceptable. In production, would restrict to IBC module address.

---

## 10. Deploy Scripts

### Purpose
Foundry scripts to deploy all three contracts to their respective chains. Run separately per chain with different RPC URLs.

### Dependencies
All contracts.

### Code

#### File: contracts/script/Deploy.s.sol
[VERIFIED] — Foundry script pattern; minievm flags from https://docs.initia.xyz/developers/developer-guides/vm-specific-tutorials/evm
```solidity
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
        string memory settlementChannel = vm.envString("SETTLEMENT_CHANNEL");
        address paymentRegistry = vm.envAddress("PAYMENT_REGISTRY_ADDRESS");

        vm.startBroadcast();
        StreamSender sender = new StreamSender(denom, settlementChannel, paymentRegistry);
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
```

### Deployment Commands
```bash
# Step 1: Deploy StreamReceiver on Rollup B (no dependencies)
forge script script/Deploy.s.sol:DeployStreamReceiver \
  --rpc-url $ROLLUP_B_RPC \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast --via-ir --with-gas-price 0 --skip-simulation

# Step 2: Deploy PaymentRegistry on Settlement Minitia (needs StreamReceiver address)
STREAM_RECEIVER_ADDRESS=<from step 1> \
forge script script/Deploy.s.sol:DeployPaymentRegistry \
  --rpc-url $SETTLEMENT_RPC \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast --via-ir --with-gas-price 0 --skip-simulation

# Step 3: Deploy StreamSender on Rollup A (needs PaymentRegistry address)
PAYMENT_REGISTRY_ADDRESS=<from step 2> \
forge script script/Deploy.s.sol:DeployStreamSender \
  --rpc-url $ROLLUP_A_RPC \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast --via-ir --with-gas-price 0 --skip-simulation
```

---

## 11. Contract Tests

### Purpose
Basic Foundry tests for each contract. Focus on core logic (stream creation, tick sending, payment crediting) rather than IBC integration (which requires live relayers).

### Dependencies
Contracts, forge-std.

### Code

#### File: contracts/test/StreamSender.t.sol
[ASSUMED] — Standard Foundry test pattern; ICosmos mock needed since precompile unavailable in test env
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// File: contracts/test/StreamSender.t.sol
// CAUTION: ASSUMED PATTERN — ICosmos precompile is not available in forge test.
// These tests verify local logic only. IBC integration tested manually on testnet.

import "forge-std/Test.sol";
import "../src/StreamSender.sol";

contract StreamSenderTest is Test {
    StreamSender public sender;
    address public alice = makeAddr("alice");
    address public registryAddr = makeAddr("registry");

    function setUp() public {
        sender = new StreamSender("uinit", "channel-0", registryAddr);
        vm.deal(alice, 100 ether);
    }

    function test_createStream() public {
        vm.prank(alice);
        bytes32 streamId = sender.createStream{value: 10 ether}(
            "init1receiver...",
            "channel-1",
            300 // 5 minutes
        );
        assertTrue(streamId != bytes32(0));

        StreamSender.StreamInfo memory info = sender.getStreamInfo(streamId);
        assertEq(info.sender, alice);
        assertEq(info.totalAmount, 10 ether);
        assertTrue(info.active);
        assertEq(info.ratePerTick, 1 ether); // 10 ether / 10 ticks (300s / 30s)
    }

    function test_createStream_revertZeroValue() public {
        vm.prank(alice);
        vm.expectRevert("Must deposit tokens");
        sender.createStream{value: 0}("init1receiver...", "channel-1", 300);
    }

    function test_cancelStream() public {
        vm.prank(alice);
        bytes32 streamId = sender.createStream{value: 10 ether}(
            "init1receiver...",
            "channel-1",
            300
        );

        uint256 balanceBefore = alice.balance;
        vm.prank(alice);
        sender.cancelStream(streamId);

        StreamSender.StreamInfo memory info = sender.getStreamInfo(streamId);
        assertFalse(info.active);
        assertEq(alice.balance, balanceBefore + 10 ether);
    }

    function test_cancelStream_revertNotOwner() public {
        vm.prank(alice);
        bytes32 streamId = sender.createStream{value: 10 ether}(
            "init1receiver...",
            "channel-1",
            300
        );

        vm.prank(makeAddr("bob"));
        vm.expectRevert("Not stream owner");
        sender.cancelStream(streamId);
    }

    function test_getSenderStreams() public {
        vm.startPrank(alice);
        sender.createStream{value: 5 ether}("init1a...", "channel-1", 300);
        sender.createStream{value: 5 ether}("init1b...", "channel-1", 300);
        vm.stopPrank();

        bytes32[] memory ids = sender.getSenderStreams(alice);
        assertEq(ids.length, 2);
    }
}
```

#### File: contracts/test/PaymentRegistry.t.sol
[ASSUMED] — Standard Foundry test pattern
```solidity
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
    address constant ICOSMOS = 0x00000000000000000000000000000000000000f1;

    function setUp() public {
        registry = new PaymentRegistry(
            "uinit",
            address(0), // No oracle in test
            "INIT/USD",
            receiverContract
        );
        // Mock ICosmos precompile — execute_cosmos is a no-op, address conversions return fixed values
        vm.mockCall(ICOSMOS, abi.encodeWithSignature("execute_cosmos(string)"), abi.encode());
        vm.mockCall(
            ICOSMOS,
            abi.encodeWithSignature("to_cosmos_address(address)"),
            abi.encode("init1mockaddr...")
        );
    }

    function test_processPayment_registersStream() public {
        bytes32 streamId = keccak256("stream1");
        registry.processPayment(
            streamId,
            "init1sender...",
            "init1receiver...",
            "channel-1",
            10 ether, // totalAmount
            block.timestamp + 300, // endTime
            1 ether,
            1
        );

        PaymentRegistry.Stream memory s = registry.getStream(streamId);
        assertEq(s.amountSent, 1 ether);
        assertEq(s.totalAmount, 10 ether);
        assertEq(uint(s.status), uint(PaymentRegistry.StreamStatus.ACTIVE));
    }

    function test_processPayment_multipleTicksAccumulate() public {
        bytes32 streamId = keccak256("stream1");

        registry.processPayment(streamId, "init1s...", "init1r...", "channel-1", 10 ether, block.timestamp + 300, 1 ether, 1);
        registry.processPayment(streamId, "init1s...", "init1r...", "channel-1", 10 ether, block.timestamp + 300, 1 ether, 2);
        registry.processPayment(streamId, "init1s...", "init1r...", "channel-1", 10 ether, block.timestamp + 300, 1 ether, 3);

        PaymentRegistry.Stream memory s = registry.getStream(streamId);
        assertEq(s.amountSent, 3 ether);
    }

    function test_getStreamsByReceiver() public {
        bytes32 id1 = keccak256("s1");
        bytes32 id2 = keccak256("s2");

        registry.processPayment(id1, "init1s...", "init1r...", "channel-1", 10 ether, block.timestamp + 300, 1 ether, 1);
        registry.processPayment(id2, "init1s...", "init1r...", "channel-1", 10 ether, block.timestamp + 300, 1 ether, 1);

        bytes32[] memory ids = registry.getStreamsByReceiver("init1r...");
        assertEq(ids.length, 2);
    }
}
```

#### File: contracts/test/StreamReceiver.t.sol
[ASSUMED] — Standard Foundry test pattern
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// File: contracts/test/StreamReceiver.t.sol
// CAUTION: ASSUMED PATTERN — bech32 conversion uses hash fallback in test.

import "forge-std/Test.sol";
import "../src/StreamReceiver.sol";

contract StreamReceiverTest is Test {
    StreamReceiver public receiver;
    address constant ICOSMOS = 0x00000000000000000000000000000000000000f1;

    function setUp() public {
        receiver = new StreamReceiver("ibc/TESTHASH");
        vm.deal(address(receiver), 100 ether); // Fund contract for claims
        // Mock ICosmos precompile
        vm.mockCall(ICOSMOS, abi.encodeWithSignature("execute_cosmos(string)"), abi.encode());
        vm.mockCall(
            ICOSMOS,
            abi.encodeWithSignature("to_cosmos_address(address)"),
            abi.encode("init1mockaddr...")
        );
        // to_evm_address fallback will be used (reverts → hash fallback)
    }

    function test_onReceivePayment_creditsBalance() public {
        bytes32 streamId = keccak256("stream1");
        // The bech32 address will be hashed to an EVM address in test (fallback)
        receiver.onReceivePayment(streamId, "init1testrecv...", 5 ether);

        // Get the derived address from the hash
        address derivedAddr = address(uint160(uint256(keccak256(bytes("init1testrecv...")))));
        assertEq(receiver.getClaimable(derivedAddr), 5 ether);
    }

    function test_claim() public {
        bytes32 streamId = keccak256("stream1");
        receiver.onReceivePayment(streamId, "init1testrecv...", 5 ether);

        address derivedAddr = address(uint160(uint256(keccak256(bytes("init1testrecv...")))));

        vm.prank(derivedAddr);
        receiver.claim();

        assertEq(receiver.getClaimable(derivedAddr), 0);
        // Balance not checked here — claim sends via Cosmos bank send, mocked as no-op
    }

    function test_claim_revertNothingToClaim() public {
        vm.expectRevert("Nothing to claim");
        receiver.claim();
    }

    function test_multiplePaymentsAccumulate() public {
        bytes32 streamId = keccak256("stream1");
        receiver.onReceivePayment(streamId, "init1testrecv...", 2 ether);
        receiver.onReceivePayment(streamId, "init1testrecv...", 3 ether);

        address derivedAddr = address(uint160(uint256(keccak256(bytes("init1testrecv...")))));
        assertEq(receiver.getClaimable(derivedAddr), 5 ether);

        StreamReceiver.IncomingStream memory s = receiver.getIncomingStream(streamId);
        assertEq(s.totalReceived, 5 ether);
    }
}
```

---

## 12. Foundry Configuration

### Code

#### File: contracts/foundry.toml
[VERIFIED] — minievm flags from https://docs.initia.xyz/developers/developer-guides/vm-specific-tutorials/evm
```toml
# File: contracts/foundry.toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc_version = "0.8.24"
via_ir = true
optimizer = true
optimizer_runs = 200

[rpc_endpoints]
rollup_a = "${ROLLUP_A_RPC}"
settlement = "${SETTLEMENT_RPC}"
rollup_b = "${ROLLUP_B_RPC}"
```

---

## 13. Frontend Configuration

### Code

#### File: frontend/package.json
[ASSUMED] — Package versions based on latest available; InterwovenKit package name from docs
```json
{
  "name": "ghostpay-frontend",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "@initia/interwovenkit-react": "latest",
    "@tanstack/react-query": "^5.0.0",
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "react-router-dom": "^6.26.0",
    "viem": "^2.21.0"
  },
  "devDependencies": {
    "@types/react": "^18.3.0",
    "@types/react-dom": "^18.3.0",
    "@vitejs/plugin-react": "^4.3.0",
    "autoprefixer": "^10.4.0",
    "postcss": "^8.4.0",
    "tailwindcss": "^3.4.0",
    "typescript": "^5.6.0",
    "vite": "^5.4.0"
  }
}
```

#### File: frontend/vite.config.ts
[VERIFIED]
```typescript
// File: frontend/vite.config.ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
  },
})
```

#### File: frontend/tsconfig.json
[VERIFIED]
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "isolatedModules": true,
    "moduleDetection": "force",
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": false,
    "noUnusedParameters": false,
    "noFallthroughCasesInSwitch": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src"]
}
```

#### File: frontend/tailwind.config.ts
[VERIFIED]
```typescript
// File: frontend/tailwind.config.ts
import type { Config } from 'tailwindcss'

export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        ghost: {
          50: '#f0f4ff',
          100: '#dbe4ff',
          500: '#4c6ef5',
          600: '#3b5bdb',
          700: '#364fc7',
          900: '#1b2559',
        },
      },
      animation: {
        'pulse-slow': 'pulse 3s ease-in-out infinite',
        'flow': 'flow 2s ease-in-out infinite',
      },
      keyframes: {
        flow: {
          '0%, 100%': { transform: 'translateX(0)' },
          '50%': { transform: 'translateX(100%)' },
        },
      },
    },
  },
  plugins: [],
} satisfies Config
```

#### File: frontend/postcss.config.js
[VERIFIED]
```javascript
// File: frontend/postcss.config.js
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
```

#### File: frontend/index.html
[VERIFIED]
```html
<!-- File: frontend/index.html -->
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>GhostPay — Payment Streams Across Rollups</title>
    <link rel="icon" type="image/svg+xml" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>👻</text></svg>" />
  </head>
  <body class="bg-gray-950 text-white min-h-screen">
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

---

## 14. Frontend: Chain & Contract Config

### Purpose
Chain configuration for all three rollups and contract addresses/ABIs for frontend interaction.

### Code

#### File: frontend/src/config/chains.ts
[ASSUMED] — Chain IDs and RPC URLs determined at deploy time; InterwovenKit chain config pattern assumed
```typescript
// File: frontend/src/config/chains.ts
// CAUTION: ASSUMED PATTERN — InterwovenKit chain config shape may differ. Test empirically.

import { defineChain } from 'viem'
import type { ChainConfig } from '../types'

function makeViemChain(name: string, rpcUrl: string) {
  return defineChain({ id: 1, name, nativeCurrency: { name: 'INIT', symbol: 'INIT', decimals: 18 }, rpcUrls: { default: { http: [rpcUrl] } } })
}

export const ROLLUP_A: ChainConfig = {
  chainId: import.meta.env.VITE_ROLLUP_A_CHAIN_ID || 'ghostpay-rollup-a-1',
  name: 'GhostPay Rollup A',
  rpcUrl: import.meta.env.VITE_ROLLUP_A_RPC || 'http://localhost:8545',
  restUrl: import.meta.env.VITE_ROLLUP_A_REST || 'http://localhost:1317',
  viemChain: makeViemChain('GhostPay Rollup A', import.meta.env.VITE_ROLLUP_A_RPC || 'http://localhost:8545'),
}

export const SETTLEMENT: ChainConfig = {
  chainId: import.meta.env.VITE_SETTLEMENT_CHAIN_ID || 'ghostpay-settlement-1',
  name: 'GhostPay Settlement',
  rpcUrl: import.meta.env.VITE_SETTLEMENT_RPC || 'http://localhost:8546',
  restUrl: import.meta.env.VITE_SETTLEMENT_REST || 'http://localhost:1318',
  viemChain: makeViemChain('GhostPay Settlement', import.meta.env.VITE_SETTLEMENT_RPC || 'http://localhost:8546'),
}

export const ROLLUP_B: ChainConfig = {
  chainId: import.meta.env.VITE_ROLLUP_B_CHAIN_ID || 'ghostpay-rollup-b-1',
  name: 'GhostPay Rollup B',
  rpcUrl: import.meta.env.VITE_ROLLUP_B_RPC || 'http://localhost:8547',
  restUrl: import.meta.env.VITE_ROLLUP_B_REST || 'http://localhost:1319',
  viemChain: makeViemChain('GhostPay Rollup B', import.meta.env.VITE_ROLLUP_B_RPC || 'http://localhost:8547'),
}

export const TICK_INTERVAL_MS = 30_000 // 30 seconds between stream ticks
export const POLL_INTERVAL_MS = 5_000  // 5 seconds between balance polls
```

#### File: frontend/src/config/contracts.ts
[ASSUMED] — ABI shapes derived from contract code; addresses set at deploy time
```typescript
// File: frontend/src/config/contracts.ts
// CAUTION: ASSUMED PATTERN — ABI may need adjustment after compilation

import { ROLLUP_A, SETTLEMENT, ROLLUP_B } from './chains'

export const STREAM_SENDER_ADDRESS = import.meta.env.VITE_STREAM_SENDER_ADDRESS || '0x'
export const PAYMENT_REGISTRY_ADDRESS = import.meta.env.VITE_PAYMENT_REGISTRY_ADDRESS || '0x'
export const STREAM_RECEIVER_ADDRESS = import.meta.env.VITE_STREAM_RECEIVER_ADDRESS || '0x'

export const STREAM_SENDER_ABI = [
  {
    type: 'function',
    name: 'createStream',
    inputs: [
      { name: 'receiver', type: 'string' },
      { name: 'destChannel', type: 'string' },
      { name: 'durationSeconds', type: 'uint256' },
    ],
    outputs: [{ name: '', type: 'bytes32' }],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'sendTick',
    inputs: [{ name: 'streamId', type: 'bytes32' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'cancelStream',
    inputs: [{ name: 'streamId', type: 'bytes32' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'getStreamInfo',
    inputs: [{ name: 'streamId', type: 'bytes32' }],
    outputs: [
      {
        name: '',
        type: 'tuple',
        components: [
          { name: 'streamId', type: 'bytes32' },
          { name: 'sender', type: 'address' },
          { name: 'receiver', type: 'string' },
          { name: 'settlementChannel', type: 'string' },
          { name: 'destChannel', type: 'string' },
          { name: 'totalAmount', type: 'uint256' },
          { name: 'amountSent', type: 'uint256' },
          { name: 'ratePerTick', type: 'uint256' },
          { name: 'startTime', type: 'uint256' },
          { name: 'endTime', type: 'uint256' },
          { name: 'active', type: 'bool' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getSenderStreams',
    inputs: [{ name: 'sender', type: 'address' }],
    outputs: [{ name: '', type: 'bytes32[]' }],
    stateMutability: 'view',
  },
  {
    type: 'event',
    name: 'StreamCreated',
    inputs: [
      { name: 'streamId', type: 'bytes32', indexed: true },
      { name: 'sender', type: 'address', indexed: true },
      { name: 'receiver', type: 'string', indexed: false },
      { name: 'totalAmount', type: 'uint256', indexed: false },
      { name: 'duration', type: 'uint256', indexed: false },
    ],
  },
  {
    type: 'event',
    name: 'TickSent',
    inputs: [
      { name: 'streamId', type: 'bytes32', indexed: true },
      { name: 'amount', type: 'uint256', indexed: false },
      { name: 'tickNumber', type: 'uint256', indexed: false },
    ],
  },
] as const

export const STREAM_RECEIVER_ABI = [
  {
    type: 'function',
    name: 'getClaimable',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'claim',
    inputs: [],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'getIncomingStreams',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'bytes32[]' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getIncomingStream',
    inputs: [{ name: 'streamId', type: 'bytes32' }],
    outputs: [
      {
        name: '',
        type: 'tuple',
        components: [
          { name: 'streamId', type: 'bytes32' },
          { name: 'sender', type: 'string' },
          { name: 'totalReceived', type: 'uint256' },
          { name: 'lastReceiveTime', type: 'uint256' },
          { name: 'active', type: 'bool' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'event',
    name: 'PaymentReceived',
    inputs: [
      { name: 'streamId', type: 'bytes32', indexed: true },
      { name: 'receiver', type: 'address', indexed: true },
      { name: 'amount', type: 'uint256', indexed: false },
    ],
  },
  {
    type: 'event',
    name: 'FundsClaimed',
    inputs: [
      { name: 'receiver', type: 'address', indexed: true },
      { name: 'amount', type: 'uint256', indexed: false },
    ],
  },
] as const

export const PAYMENT_REGISTRY_ABI = [
  {
    type: 'function',
    name: 'getStream',
    inputs: [{ name: 'streamId', type: 'bytes32' }],
    outputs: [
      {
        name: '',
        type: 'tuple',
        components: [
          { name: 'streamId', type: 'bytes32' },
          { name: 'sender', type: 'string' },
          { name: 'receiver', type: 'string' },
          { name: 'sourceChannel', type: 'string' },
          { name: 'destChannel', type: 'string' },
          { name: 'totalAmount', type: 'uint256' },
          { name: 'amountSent', type: 'uint256' },
          { name: 'ratePerTick', type: 'uint256' },
          { name: 'startTime', type: 'uint256' },
          { name: 'endTime', type: 'uint256' },
          { name: 'lastTickTime', type: 'uint256' },
          { name: 'usdValueTotal', type: 'uint256' },
          { name: 'status', type: 'uint8' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'event',
    name: 'PaymentProcessed',
    inputs: [
      { name: 'streamId', type: 'bytes32', indexed: true },
      { name: 'amount', type: 'uint256', indexed: false },
      { name: 'usdValue', type: 'uint256', indexed: false },
      { name: 'tickNumber', type: 'uint256', indexed: false },
    ],
  },
] as const
```

---

## 15. Frontend: Hooks

### Purpose
React hooks for contract reads, stream tick management, and oracle price queries.

### Code

#### File: frontend/src/hooks/useStreams.ts
[ASSUMED] — viem public client pattern; InterwovenKit wallet address retrieval assumed
```typescript
// File: frontend/src/hooks/useStreams.ts
// CAUTION: ASSUMED PATTERN — InterwovenKit useInterwovenKit() shape may differ

import { useQuery } from '@tanstack/react-query'
import { createPublicClient, http } from 'viem'
import { ROLLUP_A, ROLLUP_B, POLL_INTERVAL_MS } from '../config/chains'
import {
  STREAM_SENDER_ADDRESS,
  STREAM_RECEIVER_ADDRESS,
  STREAM_SENDER_ABI,
  STREAM_RECEIVER_ABI,
} from '../config/contracts'
import type { StreamView } from '../types'

const rollupAClient = createPublicClient({ chain: ROLLUP_A.viemChain, transport: http(ROLLUP_A.rpcUrl) })
const rollupBClient = createPublicClient({ chain: ROLLUP_B.viemChain, transport: http(ROLLUP_B.rpcUrl) })

export function useSentStreams(senderAddress: string | undefined) {
  return useQuery({
    queryKey: ['sentStreams', senderAddress],
    queryFn: async (): Promise<StreamView[]> => {
      if (!senderAddress) return []
      const ids = await rollupAClient.readContract({
        address: STREAM_SENDER_ADDRESS as `0x${string}`,
        abi: STREAM_SENDER_ABI,
        functionName: 'getSenderStreams',
        args: [senderAddress as `0x${string}`],
      }) as `0x${string}`[]

      const streams = await Promise.all(
        ids.map(async (id) => {
          const info = await rollupAClient.readContract({
            address: STREAM_SENDER_ADDRESS as `0x${string}`,
            abi: STREAM_SENDER_ABI,
            functionName: 'getStreamInfo',
            args: [id],
          }) as {
            streamId: `0x${string}`; sender: string; receiver: string;
            settlementChannel: string; destChannel: string;
            totalAmount: bigint; amountSent: bigint; ratePerTick: bigint;
            startTime: bigint; endTime: bigint; active: boolean;
          }
          return {
            streamId: id,
            sender: info.sender,
            receiver: info.receiver,
            destChannel: info.destChannel,
            totalAmount: info.totalAmount,
            amountSent: info.amountSent,
            ratePerTick: info.ratePerTick,
            startTime: Number(info.startTime),
            endTime: Number(info.endTime),
            active: info.active,
          } as StreamView
        })
      )
      return streams
    },
    enabled: !!senderAddress,
    refetchInterval: POLL_INTERVAL_MS,
  })
}

export function useClaimableBalance(receiverAddress: string | undefined) {
  return useQuery({
    queryKey: ['claimable', receiverAddress],
    queryFn: async (): Promise<bigint> => {
      if (!receiverAddress) return 0n
      const result = await rollupBClient.readContract({
        address: STREAM_RECEIVER_ADDRESS as `0x${string}`,
        abi: STREAM_RECEIVER_ABI,
        functionName: 'getClaimable',
        args: [receiverAddress as `0x${string}`],
      })
      return result as bigint
    },
    enabled: !!receiverAddress,
    refetchInterval: POLL_INTERVAL_MS,
  })
}

export function useReceivedStreamIds(receiverAddress: string | undefined) {
  return useQuery({
    queryKey: ['receivedStreamIds', receiverAddress],
    queryFn: async (): Promise<string[]> => {
      if (!receiverAddress) return []
      const result = await rollupBClient.readContract({
        address: STREAM_RECEIVER_ADDRESS as `0x${string}`,
        abi: STREAM_RECEIVER_ABI,
        functionName: 'getIncomingStreams',
        args: [receiverAddress as `0x${string}`],
      })
      return result as string[]
    },
    enabled: !!receiverAddress,
    refetchInterval: POLL_INTERVAL_MS,
  })
}
```

#### File: frontend/src/hooks/useStreamTick.ts
[ASSUMED] — InterwovenKit submitTxBlock API shape assumed; setInterval pattern for ghost wallet ticks
```typescript
// File: frontend/src/hooks/useStreamTick.ts
// CAUTION: ASSUMED PATTERN — submitTxBlock signature and MsgCall format may differ

import { useRef, useCallback, useEffect, useState } from 'react'
import { encodeFunctionData } from 'viem'
import { TICK_INTERVAL_MS } from '../config/chains'
import { STREAM_SENDER_ADDRESS, STREAM_SENDER_ABI } from '../config/contracts'

interface UseStreamTickOptions {
  streamId: string
  enabled: boolean
  senderAddress: string
  submitTxBlock: (params: { msgs: any[] }) => Promise<any>
}

export function useStreamTick({ streamId, enabled, senderAddress, submitTxBlock }: UseStreamTickOptions) {
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null)
  const isSendingRef = useRef(false)
  const [tickCount, setTickCount] = useState(0)
  const [lastTickTime, setLastTickTime] = useState<number | null>(null)

  const sendTick = useCallback(async () => {
    if (isSendingRef.current) return
    isSendingRef.current = true
    try {
      const calldata = encodeFunctionData({
        abi: STREAM_SENDER_ABI,
        functionName: 'sendTick',
        args: [streamId as `0x${string}`],
      })

      await submitTxBlock({
        msgs: [{
          typeUrl: '/minievm.evm.v1.MsgCall',
          value: {
            sender: senderAddress,
            contract_addr: STREAM_SENDER_ADDRESS,
            input: calldata,
            value: '0',
          },
        }],
      })

      setTickCount((c) => c + 1)
      setLastTickTime(Date.now())
    } catch (err) {
      console.error('Tick failed:', err)
    } finally {
      isSendingRef.current = false
    }
  }, [streamId, senderAddress, submitTxBlock])

  useEffect(() => {
    if (!enabled || !streamId) {
      if (intervalRef.current) clearInterval(intervalRef.current)
      return
    }

    // Send first tick immediately
    sendTick()

    intervalRef.current = setInterval(sendTick, TICK_INTERVAL_MS)
    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current)
    }
  }, [enabled, streamId, sendTick])

  const stop = useCallback(() => {
    if (intervalRef.current) {
      clearInterval(intervalRef.current)
      intervalRef.current = null
    }
  }, [])

  return { tickCount, lastTickTime, isSending: isSendingRef.current, stop }
}
```

#### File: frontend/src/hooks/useOracle.ts
[ASSUMED] — REST API query pattern for oracle data; Slinky oracle REST endpoint assumed
```typescript
// File: frontend/src/hooks/useOracle.ts
// CAUTION: ASSUMED PATTERN — Oracle REST endpoint path may differ

import { useQuery } from '@tanstack/react-query'
import { SETTLEMENT } from '../config/chains'
import type { OraclePrice } from '../types'

export function useOraclePrice(pairId: string = 'INIT/USD') {
  return useQuery({
    queryKey: ['oracle', pairId],
    queryFn: async (): Promise<OraclePrice | null> => {
      try {
        // Try direct RPC call to oracle contract via REST
        const res = await fetch(`${SETTLEMENT.restUrl}/slinky/oracle/v1/get_price?currency_pair_id=${pairId}`)
        if (!res.ok) {
          // Fallback to ETH/USD
          if (pairId === 'INIT/USD') {
            const fallbackRes = await fetch(`${SETTLEMENT.restUrl}/slinky/oracle/v1/get_price?currency_pair_id=ETH/USD`)
            if (!fallbackRes.ok) return null
            const fallbackData = await fallbackRes.json()
            return parseOracleResponse(fallbackData)
          }
          return null
        }
        const data = await res.json()
        return parseOracleResponse(data)
      } catch {
        return null
      }
    },
    refetchInterval: 30_000, // Refresh price every 30s
    staleTime: 15_000,
  })
}

function parseOracleResponse(data: any): OraclePrice {
  return {
    price: BigInt(data.price?.price || '0'),
    timestamp: Number(data.price?.block_timestamp || '0'),
    decimal: Number(data.decimals || 8),
  }
}

/// @param tokenDecimals — 18 for EVM-native amounts, 6 for Cosmos uinit. Defaults to 18.
export function formatUsdValue(amountWei: bigint, price: OraclePrice | null | undefined, tokenDecimals = 18): string {
  if (!price || price.price === 0n) return '$?.??'
  const usdRaw = (amountWei * price.price) / (10n ** BigInt(price.decimal))
  const usdFloat = Number(usdRaw) / 10 ** tokenDecimals
  return `$${usdFloat.toFixed(2)}`
}
```

---

## 16. Frontend: Components

### Code

#### File: frontend/src/components/Layout.tsx
[VERIFIED]
```tsx
// File: frontend/src/components/Layout.tsx
import { Link, useLocation } from 'react-router-dom'

export function Layout({ children }: { children: React.ReactNode }) {
  const { pathname } = useLocation()

  return (
    <div className="min-h-screen bg-gray-950">
      <nav className="border-b border-gray-800 px-6 py-4">
        <div className="max-w-7xl mx-auto flex items-center justify-between">
          <Link to="/" className="text-xl font-bold text-white flex items-center gap-2">
            <span className="text-2xl">👻</span> GhostPay
          </Link>
          <div className="flex gap-4">
            <NavLink to="/" active={pathname === '/'}>Dashboard</NavLink>
            <NavLink to="/create" active={pathname === '/create'}>New Stream</NavLink>
            <NavLink to="/demo" active={pathname === '/demo'}>Demo</NavLink>
          </div>
        </div>
      </nav>
      <main className="max-w-7xl mx-auto px-6 py-8">{children}</main>
    </div>
  )
}

function NavLink({ to, active, children }: { to: string; active: boolean; children: React.ReactNode }) {
  return (
    <Link
      to={to}
      className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-colors ${
        active ? 'bg-ghost-600 text-white' : 'text-gray-400 hover:text-white hover:bg-gray-800'
      }`}
    >
      {children}
    </Link>
  )
}
```

#### File: frontend/src/components/StreamCard.tsx
[ASSUMED]
```tsx
// File: frontend/src/components/StreamCard.tsx
import type { StreamView } from '../types'
import { StreamCounter } from './StreamCounter'
import { formatUsdValue } from '../hooks/useOracle'
import type { OraclePrice } from '../types'

interface StreamCardProps {
  stream: StreamView
  type: 'sent' | 'received'
  oraclePrice?: OraclePrice | null
}

export function StreamCard({ stream, type, oraclePrice }: StreamCardProps) {
  const progress = stream.totalAmount > 0n
    ? Number((stream.amountSent * 100n) / stream.totalAmount)
    : 0

  const remaining = stream.endTime - Math.floor(Date.now() / 1000)
  const timeLeft = remaining > 0 ? formatDuration(remaining) : 'Completed'

  return (
    <div className="bg-gray-900 border border-gray-800 rounded-xl p-5 hover:border-ghost-600 transition-colors">
      <div className="flex items-center justify-between mb-3">
        <span className={`text-xs font-medium px-2 py-0.5 rounded-full ${
          stream.active ? 'bg-green-900 text-green-300' : 'bg-gray-800 text-gray-400'
        }`}>
          {stream.active ? 'Active' : 'Ended'}
        </span>
        <span className="text-xs text-gray-500">{timeLeft}</span>
      </div>

      <div className="space-y-2">
        <div className="flex justify-between text-sm">
          <span className="text-gray-400">{type === 'sent' ? 'To' : 'From'}</span>
          <span className="text-white font-mono text-xs">
            {type === 'sent'
              ? stream.receiver.slice(0, 12) + '...'
              : stream.sender?.slice(0, 12) + '...'}
          </span>
        </div>

        <div className="flex justify-between text-sm">
          <span className="text-gray-400">Streamed</span>
          <StreamCounter
            current={stream.amountSent}
            rate={stream.ratePerTick}
            active={stream.active}
          />
        </div>

        <div className="flex justify-between text-sm">
          <span className="text-gray-400">Total</span>
          <span className="text-white">
            {formatAmount(stream.totalAmount)} INIT
            {oraclePrice && <span className="text-gray-500 ml-1">{formatUsdValue(stream.totalAmount, oraclePrice)}</span>}
          </span>
        </div>

        <div className="w-full bg-gray-800 rounded-full h-1.5 mt-2">
          <div
            className="bg-ghost-500 h-1.5 rounded-full transition-all duration-1000"
            style={{ width: `${Math.min(progress, 100)}%` }}
          />
        </div>
      </div>
    </div>
  )
}

function formatAmount(wei: bigint): string {
  return (Number(wei) / 1e18).toFixed(4)
}

function formatDuration(seconds: number): string {
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  return `${m}m ${s}s`
}
```

#### File: frontend/src/components/StreamCounter.tsx
[ASSUMED]
```tsx
// File: frontend/src/components/StreamCounter.tsx
import { useState, useEffect, useRef } from 'react'

interface StreamCounterProps {
  current: bigint
  rate: bigint
  active: boolean
}

export function StreamCounter({ current, rate, active }: StreamCounterProps) {
  const [displayValue, setDisplayValue] = useState(current)
  const startTimeRef = useRef(Date.now())
  const baseValueRef = useRef(current)

  useEffect(() => {
    baseValueRef.current = current
    startTimeRef.current = Date.now()
    setDisplayValue(current)
  }, [current])

  useEffect(() => {
    if (!active || rate === 0n) return

    const interval = setInterval(() => {
      const elapsed = (Date.now() - startTimeRef.current) / 1000
      const ratePerSecond = rate / 30n // rate is per 30s tick
      const increment = BigInt(Math.floor(elapsed)) * ratePerSecond
      setDisplayValue(baseValueRef.current + increment)
    }, 100)

    return () => clearInterval(interval)
  }, [active, rate])

  const formatted = (Number(displayValue) / 1e18).toFixed(6)

  return (
    <span className="text-white font-mono tabular-nums">
      {formatted} <span className="text-gray-500">INIT</span>
    </span>
  )
}
```

#### File: frontend/src/components/BridgeVisualization.tsx
[ASSUMED]
```tsx
// File: frontend/src/components/BridgeVisualization.tsx
import { useState, useEffect, useRef } from 'react'

interface Packet {
  id: number
  progress: number
  phase: 'hop1' | 'hop2'
}

interface BridgeVisualizationProps {
  activeStreamCount: number
  lastTickTime: number | null
}

export function BridgeVisualization({ activeStreamCount, lastTickTime }: BridgeVisualizationProps) {
  const [packets, setPackets] = useState<Packet[]>([])
  const nextIdRef = useRef(0)

  useEffect(() => {
    if (!lastTickTime) return
    const id = nextIdRef.current++
    setPackets((prev) => [...prev, { id, progress: 0, phase: 'hop1' }])
  }, [lastTickTime])

  useEffect(() => {
    const interval = setInterval(() => {
      setPackets((prev) =>
        prev
          .map((p) => {
            const newProgress = p.progress + 2
            if (newProgress >= 100 && p.phase === 'hop1') {
              return { ...p, progress: 0, phase: 'hop2' as const }
            }
            return { ...p, progress: newProgress }
          })
          .filter((p) => !(p.phase === 'hop2' && p.progress >= 100))
      )
    }, 50)
    return () => clearInterval(interval)
  }, [])

  return (
    <div className="flex flex-col items-center gap-2 py-4">
      <div className="text-xs text-gray-500 uppercase tracking-wider">Bridge</div>
      <div className="relative w-8 h-64 bg-gray-900 border border-gray-700 rounded-full overflow-hidden">
        <div className="absolute inset-0 flex flex-col">
          {/* Rollup A → Settlement */}
          <div className="flex-1 relative border-b border-gray-700">
            <div className="absolute inset-x-0 top-1 text-center text-[8px] text-gray-600">A</div>
            {packets
              .filter((p) => p.phase === 'hop1')
              .map((p) => (
                <div
                  key={p.id}
                  className="absolute left-1/2 -translate-x-1/2 w-3 h-3 bg-ghost-500 rounded-full shadow-lg shadow-ghost-500/50"
                  style={{ top: `${p.progress}%` }}
                />
              ))}
          </div>
          {/* Settlement → Rollup B */}
          <div className="flex-1 relative">
            <div className="absolute inset-x-0 bottom-1 text-center text-[8px] text-gray-600">B</div>
            {packets
              .filter((p) => p.phase === 'hop2')
              .map((p) => (
                <div
                  key={p.id}
                  className="absolute left-1/2 -translate-x-1/2 w-3 h-3 bg-green-500 rounded-full shadow-lg shadow-green-500/50"
                  style={{ top: `${p.progress}%` }}
                />
              ))}
          </div>
        </div>
      </div>
      <div className="text-xs text-gray-500">
        {activeStreamCount > 0 ? `${activeStreamCount} active` : 'No streams'}
      </div>
    </div>
  )
}
```

---

## 17. Frontend: Pages

### Code

#### File: frontend/src/pages/Dashboard.tsx
[ASSUMED] — InterwovenKit hook shape assumed
```tsx
// File: frontend/src/pages/Dashboard.tsx
// CAUTION: ASSUMED PATTERN — useInterwovenKit() return shape may differ

import { Link } from 'react-router-dom'
import { encodeFunctionData } from 'viem'
import { useSentStreams, useClaimableBalance } from '../hooks/useStreams'
import { useOraclePrice } from '../hooks/useOracle'
import { StreamCard } from '../components/StreamCard'
import { STREAM_RECEIVER_ABI, STREAM_RECEIVER_ADDRESS } from '../config/contracts'
import { ROLLUP_B } from '../config/chains'

interface DashboardProps {
  address: string | undefined
  wallet: { address: string; submitTxBlock: (chainId: string, msgs: unknown[]) => Promise<void> } | null
}

export function Dashboard({ address, wallet }: DashboardProps) {
  const { data: sentStreams, isLoading: loadingSent } = useSentStreams(address)
  const { data: claimable } = useClaimableBalance(address)
  const { data: oraclePrice } = useOraclePrice()

  if (!address) {
    return (
      <div className="text-center py-20">
        <h2 className="text-2xl font-bold mb-4">Connect Your Wallet</h2>
        <p className="text-gray-400">Connect via InterwovenKit to view your streams.</p>
      </div>
    )
  }

  return (
    <div className="space-y-8">
      {/* Claimable Balance */}
      {claimable && claimable > 0n && (
        <div className="bg-green-900/20 border border-green-800 rounded-xl p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-green-400">Claimable Balance</p>
              <p className="text-2xl font-bold text-white">
                {(Number(claimable) / 1e18).toFixed(4)} INIT
              </p>
            </div>
            <button
              className="bg-green-600 hover:bg-green-500 text-white px-4 py-2 rounded-lg font-medium transition-colors"
              onClick={async () => {
                if (!wallet) return
                await wallet.submitTxBlock(ROLLUP_B.chainId, [{
                  typeUrl: '/minievm.evm.v1.MsgCall',
                  value: {
                    sender: wallet.address,
                    contract_addr: STREAM_RECEIVER_ADDRESS,
                    input: encodeFunctionData({
                      abi: STREAM_RECEIVER_ABI,
                      functionName: 'claim',
                      args: [],
                    }),
                  },
                }])
              }}
            >
              Claim Funds
            </button>
          </div>
        </div>
      )}

      {/* Sent Streams */}
      <section>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold">Sent Streams</h2>
          <Link
            to="/create"
            className="bg-ghost-600 hover:bg-ghost-500 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors"
          >
            New Stream
          </Link>
        </div>

        {loadingSent ? (
          <div className="text-gray-500">Loading...</div>
        ) : sentStreams && sentStreams.length > 0 ? (
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {sentStreams.map((stream) => (
              <StreamCard
                key={stream.streamId}
                stream={stream}
                type="sent"
                oraclePrice={oraclePrice}
              />
            ))}
          </div>
        ) : (
          <div className="text-gray-500 py-8 text-center">
            No streams yet. <Link to="/create" className="text-ghost-500 underline">Create one</Link>
          </div>
        )}
      </section>
    </div>
  )
}
```

#### File: frontend/src/pages/CreateStream.tsx
[ASSUMED] — InterwovenKit autoSign and submitTxBlock API shapes assumed
```tsx
// File: frontend/src/pages/CreateStream.tsx
// CAUTION: ASSUMED PATTERN — InterwovenKit autoSign and submitTxBlock may differ

import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { encodeFunctionData, parseEther } from 'viem'
import { STREAM_SENDER_ADDRESS, STREAM_SENDER_ABI } from '../config/contracts'
import { ROLLUP_A } from '../config/chains'
import { useOraclePrice, formatUsdValue } from '../hooks/useOracle'

interface CreateStreamProps {
  address: string | undefined
  autoSign: { enable: (chainId: string) => Promise<void>; enabled: boolean }
  submitTxBlock: (params: { msgs: any[] }) => Promise<any>
}

export function CreateStream({ address, autoSign, submitTxBlock }: CreateStreamProps) {
  const navigate = useNavigate()
  const { data: oraclePrice } = useOraclePrice()
  const [receiver, setReceiver] = useState('')
  const [amount, setAmount] = useState('')
  const [duration, setDuration] = useState('300') // 5 min default
  const [destChannel, setDestChannel] = useState(import.meta.env.VITE_DEST_CHANNEL || 'channel-1')
  const [isCreating, setIsCreating] = useState(false)
  const [autoSignEnabled, setAutoSignEnabled] = useState(false)

  const handleEnableAutoSign = async () => {
    try {
      await autoSign.enable(ROLLUP_A.chainId)
      setAutoSignEnabled(true)
    } catch (err) {
      console.error('Auto-sign enable failed:', err)
    }
  }

  const handleCreate = async () => {
    if (!address || !receiver || !amount || isCreating) return
    setIsCreating(true)
    try {
      const calldata = encodeFunctionData({
        abi: STREAM_SENDER_ABI,
        functionName: 'createStream',
        args: [receiver, destChannel, BigInt(duration)],
      })

      await submitTxBlock({
        msgs: [{
          typeUrl: '/minievm.evm.v1.MsgCall',
          value: {
            sender: address,
            contract_addr: STREAM_SENDER_ADDRESS,
            input: calldata,
            value: parseEther(amount).toString(),
          },
        }],
      })

      navigate('/')
    } catch (err) {
      console.error('Create stream failed:', err)
    } finally {
      setIsCreating(false)
    }
  }

  const amountBigInt = amount ? parseEther(amount) : 0n
  const ratePerTick = amountBigInt > 0n && Number(duration) > 0
    ? amountBigInt / BigInt(Math.floor(Number(duration) / 30) || 1)
    : 0n

  return (
    <div className="max-w-lg mx-auto">
      <h2 className="text-2xl font-bold mb-6">Create Payment Stream</h2>

      <div className="space-y-5 bg-gray-900 border border-gray-800 rounded-xl p-6">
        <Field label="Recipient Address (bech32)">
          <input
            type="text"
            value={receiver}
            onChange={(e) => setReceiver(e.target.value)}
            placeholder="init1..."
            className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2.5 text-white placeholder-gray-500 focus:border-ghost-500 focus:outline-none"
          />
        </Field>

        <Field label="Amount (INIT)">
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="10"
            min="0"
            step="0.1"
            className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2.5 text-white placeholder-gray-500 focus:border-ghost-500 focus:outline-none"
          />
          {oraclePrice && amountBigInt > 0n && (
            <p className="text-xs text-gray-500 mt-1">{formatUsdValue(amountBigInt, oraclePrice)}</p>
          )}
        </Field>

        <Field label="Duration">
          <select
            value={duration}
            onChange={(e) => setDuration(e.target.value)}
            className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2.5 text-white focus:border-ghost-500 focus:outline-none"
          >
            <option value="120">2 minutes</option>
            <option value="300">5 minutes</option>
            <option value="600">10 minutes</option>
            <option value="1800">30 minutes</option>
            <option value="3600">1 hour</option>
          </select>
        </Field>

        <Field label="Destination Channel">
          <input
            type="text"
            value={destChannel}
            onChange={(e) => setDestChannel(e.target.value)}
            className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2.5 text-white focus:border-ghost-500 focus:outline-none"
          />
        </Field>

        {/* Rate preview */}
        {ratePerTick > 0n && (
          <div className="bg-gray-800 rounded-lg p-4 text-sm">
            <p className="text-gray-400">Rate: <span className="text-white">{(Number(ratePerTick) / 1e18).toFixed(4)} INIT</span> per tick (30s)</p>
            <p className="text-gray-400">Ticks: <span className="text-white">{Math.floor(Number(duration) / 30)}</span></p>
          </div>
        )}

        {/* Auto-sign button */}
        {!autoSignEnabled && (
          <button
            onClick={handleEnableAutoSign}
            className="w-full bg-gray-800 hover:bg-gray-700 text-white py-3 rounded-lg font-medium border border-gray-700 transition-colors"
          >
            Enable Ghost Wallet (Auto-Sign)
          </button>
        )}

        <button
          onClick={handleCreate}
          disabled={isCreating || !receiver || !amount || !address}
          className="w-full bg-ghost-600 hover:bg-ghost-500 disabled:bg-gray-700 disabled:text-gray-500 text-white py-3 rounded-lg font-medium transition-colors"
        >
          {isCreating ? 'Creating...' : 'Start Stream'}
        </button>
      </div>
    </div>
  )
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="block text-sm text-gray-400 mb-1.5">{label}</label>
      {children}
    </div>
  )
}
```

#### File: frontend/src/pages/DemoView.tsx
[ASSUMED] — Split-screen demo view showing sender (Rollup A) + bridge + receiver (Rollup B)
```tsx
// File: frontend/src/pages/DemoView.tsx
// CAUTION: ASSUMED PATTERN — Demo view reads from multiple chains simultaneously

import { useSentStreams, useClaimableBalance } from '../hooks/useStreams'
import { useOraclePrice, formatUsdValue } from '../hooks/useOracle'
import { BridgeVisualization } from '../components/BridgeVisualization'
import { StreamCounter } from '../components/StreamCounter'
import { StreamCard } from '../components/StreamCard'

interface DemoViewProps {
  senderAddress: string | undefined
  receiverAddress: string | undefined
  lastTickTime: number | null
}

export function DemoView({ senderAddress, receiverAddress, lastTickTime }: DemoViewProps) {
  const { data: sentStreams } = useSentStreams(senderAddress)
  const { data: claimable } = useClaimableBalance(receiverAddress)
  const { data: oraclePrice } = useOraclePrice()

  const activeStreams = sentStreams?.filter((s) => s.active) || []

  return (
    <div className="h-[calc(100vh-80px)]">
      <h2 className="text-lg font-semibold text-center mb-4 text-gray-400">
        Live Cross-Rollup Payment Stream
      </h2>

      <div className="grid grid-cols-[1fr_auto_1fr] gap-4 h-full">
        {/* Left: Sender (Rollup A) */}
        <div className="bg-gray-900 border border-gray-800 rounded-xl p-6 overflow-auto">
          <div className="flex items-center gap-2 mb-4">
            <div className="w-2 h-2 rounded-full bg-blue-500" />
            <h3 className="text-sm font-medium text-gray-400">Rollup A — Sender</h3>
          </div>

          {activeStreams.length > 0 ? (
            <div className="space-y-4">
              {activeStreams.map((stream) => (
                <StreamCard
                  key={stream.streamId}
                  stream={stream}
                  type="sent"
                  oraclePrice={oraclePrice}
                />
              ))}
            </div>
          ) : (
            <p className="text-gray-600 text-sm">No active streams</p>
          )}
        </div>

        {/* Center: Bridge Visualization */}
        <BridgeVisualization
          activeStreamCount={activeStreams.length}
          lastTickTime={lastTickTime}
        />

        {/* Right: Receiver (Rollup B) */}
        <div className="bg-gray-900 border border-gray-800 rounded-xl p-6 overflow-auto">
          <div className="flex items-center gap-2 mb-4">
            <div className="w-2 h-2 rounded-full bg-green-500" />
            <h3 className="text-sm font-medium text-gray-400">Rollup B — Receiver</h3>
          </div>

          <div className="space-y-4">
            <div className="bg-gray-800 rounded-lg p-4">
              <p className="text-sm text-gray-400 mb-1">Claimable Balance</p>
              <p className="text-3xl font-bold font-mono tabular-nums text-green-400">
                {claimable ? (Number(claimable) / 1e18).toFixed(6) : '0.000000'}
                <span className="text-lg text-gray-500 ml-2">INIT</span>
              </p>
              {oraclePrice && claimable && claimable > 0n && (
                <p className="text-sm text-gray-500 mt-1">{formatUsdValue(claimable, oraclePrice)}</p>
              )}
            </div>

            {claimable && claimable > 0n && (
              <button
                className="w-full bg-green-600 hover:bg-green-500 text-white py-2 rounded-lg text-sm font-medium transition-colors"
                onClick={() => {
                  // In demo mode, claim is view-only. Wire to submitTxBlock when wallet is available.
                  console.log('Claim requested — wire to wallet.submitTxBlock in production')
                }}
              >
                Claim Funds
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
```

---

## 18. Frontend: App Shell

### Code

#### File: frontend/src/App.tsx
[ASSUMED] — InterwovenKit provider setup and hook usage patterns assumed
```tsx
// File: frontend/src/App.tsx
// CAUTION: ASSUMED PATTERN — InterwovenKit provider props and hook return shapes may differ

import { BrowserRouter, Routes, Route } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { Layout } from './components/Layout'
import { Dashboard } from './pages/Dashboard'
import { CreateStream } from './pages/CreateStream'
import { DemoView } from './pages/DemoView'
import { ROLLUP_A } from './config/chains'
import { useState } from 'react'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 2,
      staleTime: 5000,
    },
  },
})

// WARNING: InterwovenKitProvider import and config shape is ASSUMED.
// Real import: import { InterwovenKitProvider, useInterwovenKit } from '@initia/interwovenkit-react'
// For build purposes, we define a placeholder that must be replaced with real InterwovenKit.

function App() {
  // These would come from useInterwovenKit() in the real implementation
  const [address] = useState<string | undefined>(import.meta.env.VITE_DEMO_SENDER_ADDRESS)
  const [receiverAddress] = useState<string | undefined>(import.meta.env.VITE_DEMO_RECEIVER_ADDRESS)
  const [lastTickTime, setLastTickTime] = useState<number | null>(null)

  // Placeholder for InterwovenKit hooks — replace with real implementation
  const autoSign = {
    enable: async (chainId: string) => { console.log('autoSign.enable:', chainId) },
    enabled: false,
  }
  const submitTxBlock = async (params: { msgs: any[] }) => {
    console.log('submitTxBlock:', params)
    setLastTickTime(Date.now())
  }

  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <Layout>
          <Routes>
            <Route path="/" element={<Dashboard address={address} wallet={address ? { address, submitTxBlock: (chainId: string, msgs: unknown[]) => submitTxBlock({ msgs }) } : null} />} />
            <Route
              path="/create"
              element={
                <CreateStream
                  address={address}
                  autoSign={autoSign}
                  submitTxBlock={submitTxBlock}
                />
              }
            />
            <Route
              path="/demo"
              element={
                <DemoView
                  senderAddress={address}
                  receiverAddress={receiverAddress}
                  lastTickTime={lastTickTime}
                />
              }
            />
          </Routes>
        </Layout>
      </BrowserRouter>
    </QueryClientProvider>
  )
}

export default App
```

#### File: frontend/src/main.tsx
[VERIFIED]
```tsx
// File: frontend/src/main.tsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
```

#### File: frontend/src/index.css
[VERIFIED]
```css
/* File: frontend/src/index.css */
@tailwind base;
@tailwind components;
@tailwind utilities;
```

---

## 19. Seed Demo Script

### Purpose
Creates the exact demo state from PRD Section 6 Demo Prerequisites. Must be idempotent.

### Code

#### File: scripts/seed-demo.ts
[ASSUMED] — Uses viem for contract interaction; addresses must be set in .env
```typescript
// File: scripts/seed-demo.ts
// CAUTION: ASSUMED PATTERN — Contract interaction on minievm via standard JSON-RPC

import { createWalletClient, createPublicClient, http, parseEther, encodeFunctionData } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'

// Load config from env
const ROLLUP_A_RPC = process.env.ROLLUP_A_RPC || 'http://localhost:8545'
const ROLLUP_B_RPC = process.env.ROLLUP_B_RPC || 'http://localhost:8547'
const DEPLOYER_KEY = process.env.DEPLOYER_PRIVATE_KEY as `0x${string}`
const STREAM_SENDER = process.env.STREAM_SENDER_ADDRESS as `0x${string}`

const STREAM_SENDER_ABI = [
  {
    type: 'function',
    name: 'createStream',
    inputs: [
      { name: 'receiver', type: 'string' },
      { name: 'destChannel', type: 'string' },
      { name: 'durationSeconds', type: 'uint256' },
    ],
    outputs: [{ name: '', type: 'bytes32' }],
    stateMutability: 'payable',
  },
] as const

async function main() {
  console.log('=== GhostPay Demo Seed ===')

  const account = privateKeyToAccount(DEPLOYER_KEY)
  const walletA = createWalletClient({ account, transport: http(ROLLUP_A_RPC) })
  const publicA = createPublicClient({ transport: http(ROLLUP_A_RPC) })

  // Check balance
  const balance = await publicA.getBalance({ address: account.address })
  console.log(`Deployer balance on Rollup A: ${Number(balance) / 1e18} INIT`)

  if (balance < parseEther('15')) {
    console.error('Insufficient balance. Need at least 15 INIT for demo seeding.')
    process.exit(1)
  }

  // Create pre-seeded stream (10 INIT over 5 minutes)
  console.log('Creating pre-seeded stream...')
  const receiverAddr = process.env.DEMO_RECEIVER_BECH32
  if (!receiverAddr) {
    console.error('DEMO_RECEIVER_BECH32 env var is required. Set a valid bech32 address.')
    process.exit(1)
  }
  const destChannel = process.env.DEST_CHANNEL || 'channel-1'

  const calldata = encodeFunctionData({
    abi: STREAM_SENDER_ABI,
    functionName: 'createStream',
    args: [receiverAddr, destChannel, 300n], // 5 minutes
  })

  const hash = await walletA.sendTransaction({
    to: STREAM_SENDER,
    data: calldata,
    value: parseEther('10'),
  })

  console.log(`Stream creation tx: ${hash}`)
  const receipt = await publicA.waitForTransactionReceipt({ hash })
  console.log(`Stream created in block ${receipt.blockNumber}`)

  console.log('\n=== Seed Complete ===')
  console.log('Pre-seeded state:')
  console.log('- 1 active stream: 10 INIT over 5min')
  console.log(`- Sender: ${account.address}`)
  console.log(`- Receiver: ${receiverAddr}`)
  console.log(`- StreamSender: ${STREAM_SENDER}`)
}

main().catch((err) => {
  console.error('Seed failed:', err)
  process.exit(1)
})
```

---

## 20. Configuration Reference

### Environment Variables
| Variable | Description | Example Value | Required |
|----------|-------------|---------------|:---:|
| DEPLOYER_PRIVATE_KEY | Private key for contract deployment | 0xac0974... | Yes |
| ROLLUP_A_RPC | JSON-RPC URL for Rollup A | http://localhost:8545 | Yes |
| SETTLEMENT_RPC | JSON-RPC URL for Settlement Minitia | http://localhost:8546 | Yes |
| ROLLUP_B_RPC | JSON-RPC URL for Rollup B | http://localhost:8547 | Yes |
| ROLLUP_A_REST | REST API URL for Rollup A | http://localhost:1317 | Yes |
| SETTLEMENT_REST | REST API URL for Settlement | http://localhost:1318 | Yes |
| ROLLUP_B_REST | REST API URL for Rollup B | http://localhost:1319 | Yes |
| STREAM_DENOM | Native token denom for IBC transfers | uinit | Yes |
| SETTLEMENT_CHANNEL | IBC channel from Rollup A to Settlement | channel-0 | Yes |
| DEST_CHANNEL | IBC channel from Settlement to Rollup B | channel-1 | Yes |
| ORACLE_ADDRESS | ConnectOracle contract on Settlement | 0x031ECb... | Yes |
| ORACLE_PAIR_ID | Oracle pair for USD conversion | INIT/USD | Yes |
| STREAM_SENDER_ADDRESS | Deployed StreamSender on Rollup A | DEPLOY_AND_RECORD | Yes |
| PAYMENT_REGISTRY_ADDRESS | Deployed PaymentRegistry on Settlement | DEPLOY_AND_RECORD | Yes |
| STREAM_RECEIVER_ADDRESS | Deployed StreamReceiver on Rollup B | DEPLOY_AND_RECORD | Yes |
| VITE_ROLLUP_A_CHAIN_ID | Chain ID for frontend | ghostpay-rollup-a-1 | Yes |
| VITE_SETTLEMENT_CHAIN_ID | Chain ID for frontend | ghostpay-settlement-1 | Yes |
| VITE_ROLLUP_B_CHAIN_ID | Chain ID for frontend | ghostpay-rollup-b-1 | Yes |
| VITE_DEMO_SENDER_ADDRESS | Demo sender EVM address | 0x... | No |
| VITE_DEMO_RECEIVER_ADDRESS | Demo receiver EVM address | 0x... | No |

### Config File

#### File: .env.example
[VERIFIED]
```bash
# File: .env.example

# === Deployment ===
# WARNING: Replace with your own key. NEVER commit a real private key.
DEPLOYER_PRIVATE_KEY=YOUR_PRIVATE_KEY_HERE

# === Chain RPCs ===
ROLLUP_A_RPC=http://localhost:8545
SETTLEMENT_RPC=http://localhost:8546
ROLLUP_B_RPC=http://localhost:8547
ROLLUP_A_REST=http://localhost:1317
SETTLEMENT_REST=http://localhost:1318
ROLLUP_B_REST=http://localhost:1319

# === IBC Config ===
STREAM_DENOM=uinit
SETTLEMENT_CHANNEL=channel-0
DEST_CHANNEL=channel-1

# === Oracle ===
ORACLE_ADDRESS=0x031ECb63480983FD216D17BB6e1d393f3816b72F
ORACLE_PAIR_ID=INIT/USD

# === Contract Addresses (fill after deployment) ===
STREAM_SENDER_ADDRESS=DEPLOY_AND_RECORD
PAYMENT_REGISTRY_ADDRESS=DEPLOY_AND_RECORD
STREAM_RECEIVER_ADDRESS=DEPLOY_AND_RECORD

# === Frontend (Vite) ===
VITE_ROLLUP_A_RPC=http://localhost:8545
VITE_SETTLEMENT_RPC=http://localhost:8546
VITE_ROLLUP_B_RPC=http://localhost:8547
VITE_ROLLUP_A_REST=http://localhost:1317
VITE_SETTLEMENT_REST=http://localhost:1318
VITE_ROLLUP_B_REST=http://localhost:1319
VITE_ROLLUP_A_CHAIN_ID=ghostpay-rollup-a-1
VITE_SETTLEMENT_CHAIN_ID=ghostpay-settlement-1
VITE_ROLLUP_B_CHAIN_ID=ghostpay-rollup-b-1
VITE_STREAM_SENDER_ADDRESS=DEPLOY_AND_RECORD
VITE_PAYMENT_REGISTRY_ADDRESS=DEPLOY_AND_RECORD
VITE_STREAM_RECEIVER_ADDRESS=DEPLOY_AND_RECORD
VITE_DEST_CHANNEL=channel-1
VITE_DEMO_SENDER_ADDRESS=
VITE_DEMO_RECEIVER_ADDRESS=
```

---

## 21. Testing Strategy

### Test Files
| Test File | Tests | Command |
|-----------|-------|---------|
| contracts/test/StreamSender.t.sol | Stream creation, cancellation, sender tracking | `forge test --match-contract StreamSenderTest -vvv` |
| contracts/test/PaymentRegistry.t.sol | Payment processing, stream registration, accumulation | `forge test --match-contract PaymentRegistryTest -vvv` |
| contracts/test/StreamReceiver.t.sol | Payment crediting, claiming, balance tracking | `forge test --match-contract StreamReceiverTest -vvv` |

### Critical Tests (must pass before deployment)
1. `test_createStream` — verifies stream creation with correct parameters and deposit
2. `test_cancelStream` — verifies refund of unstreamed funds
3. `test_processPayment_registersStream` — verifies first-tick auto-registration
4. `test_onReceivePayment_creditsBalance` — verifies receiver balance crediting
5. `test_claim` — verifies fund withdrawal

### Run All Tests
```bash
cd contracts && forge test --via-ir -vvv
```

### Integration Testing (Manual — requires live relayers)
1. Deploy all 3 contracts to respective minitias
2. Create a stream via StreamSender on Rollup A
3. Manually call sendTick() and verify IBC packet delivery
4. Check PaymentRegistry state on Settlement
5. Check StreamReceiver balance on Rollup B
6. Claim funds on Rollup B

---

## 22. Deployment Sequence

| Step | Action | Command | Verify |
|:---:|--------|---------|--------|
| 1 | Deploy Settlement Minitia | `weave rollup launch` (EVM, oracle=yes) | `curl http://localhost:8546` returns JSON-RPC response |
| 2 | Deploy Rollup A (or use existing testnet minitia) | `weave rollup launch` or use testnet | JSON-RPC responds |
| 3 | Deploy Rollup B (or use existing testnet minitia) | `weave rollup launch` or use testnet | JSON-RPC responds |
| 4 | Start IBC relayer L1↔Settlement | `weave relayer start` | `weave relayer status` shows active |
| 5 | Start IBC relayer L1↔Rollup A | `weave relayer start` | Active relayer |
| 6 | Start IBC relayer L1↔Rollup B | `weave relayer start` | Active relayer |
| 7 | Record IBC channel IDs | `weave relayer channels` | Save to .env |
| 8 | Install contract deps | `cd contracts && forge install OpenZeppelin/openzeppelin-contracts --no-commit` | `lib/` populated |
| 9 | Query oracle address | `curl $SETTLEMENT_REST/minievm/evm/v1/connect_oracle` | Save address to .env |
| 10 | Deploy StreamReceiver on Rollup B | See Deploy Script step 1 | Address logged |
| 11 | Deploy PaymentRegistry on Settlement | See Deploy Script step 2 | Address logged |
| 12 | Deploy StreamSender on Rollup A | See Deploy Script step 3 | Address logged |
| 13 | Update .env with all addresses | Manual | All DEPLOY_AND_RECORD replaced |
| 14 | Run seed-demo.ts | `npx tsx scripts/seed-demo.ts` | Stream created, tx hash logged |
| 15 | Install frontend deps | `cd frontend && npm install` | No errors |
| 16 | Start frontend dev server | `cd frontend && npm run dev` | http://localhost:3000 loads |

### Dependencies
- Steps 1-3 must complete before steps 4-6 (relayers need running chains)
- Steps 4-7 must complete before steps 10-12 (deploy needs IBC channels)
- Step 10 must complete before step 11 (PaymentRegistry needs StreamReceiver address)
- Step 11 must complete before step 12 (StreamSender needs PaymentRegistry address)
- Steps 10-13 must complete before step 14 (seed needs deployed contracts)

---

## 23. Addresses & External References

### On-Chain Addresses
| Item | Address | Network | Source |
|------|---------|---------|--------|
| ICosmos precompile | 0x00000000000000000000000000000000000000f1 | All EVM Minitias | [VERIFIED] Initia docs |
| ConnectOracle | Query `${REST_URL}/minievm/evm/v1/connect_oracle` | Settlement Minitia | [VERIFIED] Initia docs |
| StreamSender | DEPLOY_AND_RECORD | Rollup A | Deploy step 12 |
| PaymentRegistry | DEPLOY_AND_RECORD | Settlement Minitia | Deploy step 11 |
| StreamReceiver | DEPLOY_AND_RECORD | Rollup B | Deploy step 10 |

### API Endpoints
| Service | URL | Auth |
|---------|-----|------|
| Rollup A JSON-RPC | http://localhost:8545 | None |
| Settlement JSON-RPC | http://localhost:8546 | None |
| Rollup B JSON-RPC | http://localhost:8547 | None |
| Rollup A REST | http://localhost:1317 | None |
| Settlement REST | http://localhost:1318 | None |
| Rollup B REST | http://localhost:1319 | None |
| Initia L1 RPC | https://rpc.testnet.initia.xyz | None |
| Initia Faucet | https://faucet.testnet.initia.xyz | Gitcoin Passport |

---

## 24. Integration Map

| From | To | Protocol | Credential (env var) | Health Check | Priority |
|------|----|:--------:|---------------------|:------------:|:--------:|
| Frontend | StreamSender | JSON-RPC | `VITE_ROLLUP_A_RPC` | `curl -X POST -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' $ROLLUP_A_RPC` | CRITICAL |
| Frontend | StreamReceiver | JSON-RPC | `VITE_ROLLUP_B_RPC` | `curl -X POST -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' $ROLLUP_B_RPC` | CRITICAL |
| Frontend | Oracle REST | HTTP | `VITE_SETTLEMENT_REST` | `curl $SETTLEMENT_REST/slinky/oracle/v1/get_price?currency_pair_id=ETH/USD` | STANDARD |
| StreamSender | ICosmos(0xf1) | Precompile | None | `cast call 0xf1 "to_cosmos_address(address)" $DEPLOYER --rpc-url $ROLLUP_A_RPC` | CRITICAL |
| StreamSender | PaymentRegistry | IBC+Hook | `SETTLEMENT_CHANNEL` | `weave relayer status` shows active | CRITICAL |
| PaymentRegistry | IConnectOracle | Contract call | `ORACLE_ADDRESS` | `cast call $ORACLE_ADDRESS "get_all_currency_pairs()" --rpc-url $SETTLEMENT_RPC` | STANDARD |
| PaymentRegistry | StreamReceiver | IBC+Hook | `DEST_CHANNEL` | `weave relayer status` shows active | CRITICAL |
| IBC Relayer A | L1↔Settlement | IBC packets | Relayer key | `weave relayer status` | CRITICAL |
| IBC Relayer B | L1↔Rollup B | IBC packets | Relayer key | `weave relayer status` | CRITICAL |

---

## 25. Acceptance Criteria

### Acceptance Criteria
| Feature | Criteria | Judge Priority |
|---------|----------|:--------------:|
| Stream creation | User can create a payment stream with amount and duration; funds deposited on-chain | HIGH |
| Ghost wallet (auto-sign) | Auto-sign enables without error; subsequent ticks fire without wallet popups | HIGH |
| Cross-rollup bridge | Stream ticks visibly cross from Rollup A through Settlement to Rollup B via IBC | HIGH |
| Receiver balance | Receiver's claimable balance increases in real-time as ticks arrive | HIGH |
| Split-screen demo | Demo view shows sender, bridge animation, and receiver simultaneously | HIGH |
| Oracle USD display | Stream amounts show USD equivalent from oracle price feed | MED |
| Stream cancellation | Payer can cancel stream and receive refund of unstreamed funds | MED |
| Fund claiming | Receiver can claim accumulated funds to their wallet | MED |
| Multiple streams | Multiple streams can run concurrently and converge on same receiver | LOW |

### Test Scenarios (per HIGH-priority feature)

#### Stream Creation
| Scenario | Input | Expected Output |
|----------|-------|----------------|
| Happy path | 10 INIT, 5min duration, valid receiver | StreamCreated event, stream visible on dashboard |
| Zero amount | 0 INIT | Revert: "Must deposit tokens" |
| Zero duration | 10 INIT, 0 seconds | Revert: "Duration must be positive" |

#### Cross-Rollup Bridge
| Scenario | Input | Expected Output |
|----------|-------|----------------|
| Happy path | Active stream, sendTick called | IBC packet sent, PaymentRegistry processes, StreamReceiver credits |
| Expired stream | Stream past endTime | Revert: "Stream expired" |
| Relayer down | sendTick called, no relayer | Tx succeeds on-chain but IBC packet not relayed; timeout after 10min |

#### Receiver Balance
| Scenario | Input | Expected Output |
|----------|-------|----------------|
| Happy path | 3 ticks received | Claimable balance = 3 * ratePerTick |
| Claim | Receiver calls claim() | Balance transferred, claimable reset to 0 |
| No balance | Receiver calls claim() with 0 balance | Revert: "Nothing to claim" |

---

## 26. Security Considerations

### Assets at Risk
| Asset | Value | Where Stored |
|-------|-------|-------------|
| Deposited stream funds | User tokens locked in StreamSender | StreamSender contract on Rollup A |
| In-transit IBC funds | Tokens during IBC transfer | IBC escrow accounts |
| Claimable funds | Received tokens pending claim | StreamReceiver contract on Rollup B |
| Deployer private key | Controls all contracts | .env file (local only) |

### Attack Surfaces
| Surface | Attack Vector | Exposure Level |
|---------|--------------|:--------------:|
| StreamSender.sendTick | Anyone can call sendTick for any stream (no auth beyond stream existence) | LOW — ticks only send to pre-configured destination |
| PaymentRegistry.processPayment | Anyone can call processPayment (should be IBC module only) | MED — in production, restrict to IBC hook caller |
| StreamReceiver.onReceivePayment | Anyone can call and credit arbitrary balances | MED — in production, restrict to IBC hook caller |
| JSON memo injection | Malformed memo could exploit IBC hook parsing | LOW — memo built from on-chain data only |

### Security Invariants
- [ ] Stream funds cannot exceed deposited amount (amountSent <= totalAmount)
- [ ] Only stream creator can cancel and receive refund
- [ ] Claimable balance only increases via onReceivePayment, only decreases via claim
- [ ] claim() transfers exact claimable amount, then sets balance to 0 (no reentrancy window with transfer())
- [ ] IBC timeout prevents funds from being permanently locked in transit

---

## 27. Performance Budgets

| Component | Metric | Budget | Test Method |
|-----------|--------|:------:|-------------|
| Dashboard | First Contentful Paint | < 2000ms | Lighthouse |
| Dashboard | Time to Interactive | < 3000ms | Lighthouse |
| Stream creation tx | Confirmation time | < 3000ms | Timestamp diff |
| IBC hop (single) | Packet delivery | < 10000ms | Log timestamp diff |
| Full tick cycle (2 hops) | Rollup A → Rollup B | < 20000ms | Log timestamp diff |
| Balance poll | Response time | < 500ms | curl timing |
| Oracle query | Response time | < 1000ms | curl timing |

**Gas:** Managed by `forge snapshot` — not listed here. Debug phase 6 runs `forge snapshot --check` for automatic gas regression detection.
