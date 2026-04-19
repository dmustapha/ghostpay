# GhostPay — Product Requirements Document

**Hackathon:** INITIATE: The Initia Hackathon (Season 1)
**Track:** DeFi
**Deadline:** 2026-04-15
**Version:** V1

---

## 1. Project Overview

### One-Liner
GhostPay turns lump-sum crypto payments into continuous money streams that flow automatically across Initia rollups via IBC.

### Problem Statement
**Crypto has no concept of continuous money movement across chains.**

Every crypto transaction today is all-or-nothing: send $100 or $0. There is no partial, proportional, or time-based payment — the same model as writing a check in 1950. Superfluid and Sablier brought streaming to single chains, but **zero protocols stream payments across rollups**.

On Initia specifically, paying someone on a different rollup means: bridge tokens → wait for confirmation → swap if needed → send. Every single time. No recurring or automated cross-chain payments exist.

Three layers of the problem:
1. **All-or-nothing payments** — Every crypto tx is a lump sum. No proportional, time-based payments.
2. **Cross-rollup payments are manual and painful** — Bridge → wait → swap → send. Every time. Nobody automates this.
3. **No programmable money flows** — Can't split revenue between 3 contributors on 3 rollups in real-time. Can't stream protocol fees cross-chain. Every payment requires a human clicking "send."

**Use cases unlocked:** Subscriptions (cancel anytime, pay only for usage), payroll (salary streams every block), revenue splitting (cofounders on different rollups), protocol-to-protocol fee flows, DCA streaming, conditional payments.

### Solution
GhostPay deploys a dedicated Settlement Minitia (its own rollup) that acts as a payment routing hub between Initia rollups. A payer creates a stream (amount, duration, recipient, destination rollup), and a "ghost wallet" — powered by Initia's authz + feegrant — fires micro-transactions at regular intervals without any wallet popups. Each micro-payment routes through the Settlement Minitia via IBC, with oracle-powered USD conversion, arriving on the receiver's rollup in real-time. The receiver watches their balance climb continuously.

The bridge crossing is the visual centerpiece: money visibly leaving one rollup, crossing through the settlement layer, and arriving on another — a live demonstration of Initia's multi-rollup architecture.

### Why This Wins
| Judging Criterion | Weight | How We Excel |
|---|:---:|---|
| Technical Execution & Initia Integration | 30% | 5 native features (own Minitia, IBC, authz+feegrant, oracle, InterwovenKit) — ALL load-bearing. Remove any one and the product breaks. |
| Originality & Track Fit | 20% | Cross-rollup payment streaming doesn't exist anywhere. Not on Initia, not on any chain. Zero competitors in this exact space. |
| Product Value & UX | 20% | Clean streaming visualization with bridge-crossing animation. One-click stream creation. Ghost wallet eliminates tx approval fatigue. |
| Working Demo & Completeness | 20% | Split-screen demo: Rollup A (sender) and Rollup B (receiver). Money visibly crosses the bridge in real-time. |
| Market Understanding | 10% | Infrastructure bet on Initia's multi-rollup future. Positioned as payment rails for 100+ rollups. |

---

## 2. System Architecture Overview

### System Diagram
```
                        ┌─────────────────────────────────┐
                        │        INITIA L1 (Router)       │
                        │   IBC Relayers (3 L2↔L1 pairs)  │
                        └──┬──────────┬──────────┬────────┘
                  hop 1 ↑↓ │   hop 2 ↑↓│   hop 3 ↑↓│  hop 4
┌─────────────────────┐    │ ┌──────────────────────┐    │ ┌─────────────────────┐
│   Rollup A (EVM)    │    │ │  Settlement Minitia  │    │ │   Rollup B (EVM)    │
│                     │    │ │   (GhostPay Rollup)  │    │ │                     │
│ ┌─────────────────┐ │    │ │                      │    │ │ ┌─────────────────┐ │
│ │  Payer Wallet   │ │    │ │ ┌──────────────────┐ │    │ │ │ Receiver Wallet │ │
│ │       +         │ │ →L1→ │ │ PaymentRegistry  │ │ →L1→ │ │                 │ │
│ │  Ghost Wallet   │ │    │ │ │ (stream state,   │ │    │ │ │ StreamReceiver  │ │
│ │  (authz grant)  │ │    │ │ │  routing, oracle) │ │    │ │ │ (credits funds) │ │
│ └─────────────────┘ │    │ │ └──────────────────┘ │    │ │ └─────────────────┘ │
│                     │    │ │                      │    │ │                     │
│ ┌─────────────────┐ │    │ │ ┌──────────────────┐ │    │ │ ┌─────────────────┐ │
│ │ StreamSender    │ │    │ │ │ ConnectOracle    │ │    │ │ │  Frontend       │ │
│ │ (initiates IBC) │ │    │ │ │ (USD conversion) │ │    │ │ │  (receiver view)│ │
│ └─────────────────┘ │    │ │ └──────────────────┘ │    │ │ └─────────────────┘ │
│                     │    │ │                      │    │ │                     │
│ ┌─────────────────┐ │    │ │                      │    │ │                     │
│ │  Frontend       │ │    │ │                      │    │ │                     │
│ │  (sender view)  │ │    │ │                      │    │ │                     │
│ └─────────────────┘ │    │ │                      │    │ │                     │
└─────────────────────┘    │ └──────────────────────┘    │ └─────────────────────┘

Routing: Rollup A → L1 (hop 1) → Settlement (hop 2) → L1 (hop 3) → Rollup B (hop 4)
No direct L2↔L2 channels exist. All IBC traffic routes through L1. ~10-30s per full tick.

Data Flow:
  Payer creates stream → Ghost wallet fires micro-tx every 30s →
  IBC transfer Rollup A → L1 → Settlement Minitia (hops 1-2) →
  PaymentRegistry records + queries oracle + initiates outbound IBC →
  IBC transfer Settlement → L1 → Rollup B (hops 3-4) →
  StreamReceiver credits receiver balance → Frontend visualizes increase
```

> **Architecture tradeoff:** Routing through Settlement Minitia adds 2 extra hops vs. deploying PaymentRegistry on L1 directly (2 hops). We accept this because: (1) own Minitia is a hackathon differentiator showing deep Initia integration, (2) dedicated rollup means no gas competition from other L1 traffic, (3) judges explicitly reward "deploying your own rollup." If latency proves unacceptable during Day 1 testing, the L1-only fallback (same code, deploy to L1 instead) cuts to 2 hops.

### Component Table
| Component | Type | Purpose | Key Dependencies |
|-----------|------|---------|-----------------|
| PaymentRegistry | Solidity Contract (Settlement Minitia) | Central stream state, routing logic, oracle queries | ICosmos precompile, IConnectOracle |
| StreamSender | Solidity Contract (Rollup A) | Accepts deposits, emits IBC transfers to settlement | ICosmos precompile |
| StreamReceiver | Solidity Contract (Rollup B) | Credits received funds to recipient addresses | EVM IBC hooks |
| Ghost Wallet | Initia authz + feegrant | Session key that signs pre-approved tx types without popups. Frontend Web Worker drives scheduling. | InterwovenKit autoSign |
| Frontend | Vite + React + InterwovenKit | Stream creation UI, real-time visualization, wallet connection | InterwovenKit, TanStack Query |
| Settlement Minitia | EVM Minitia (own rollup) | Dedicated chain for payment routing and state | weave CLI, rapid-relayer |
| IBC Relayers | rapid-relayer instances | Relay packets between L1 and each Minitia | rapid-relayer |
| ConnectOracle | Slinky/Connect oracle | USD price conversion for stream display | Oracle precompile on settlement |

### Data Flow
1. **Stream creation:** Payer connects wallet via InterwovenKit on Rollup A. Enables auto-sign (creates ghost wallet with authz grant scoped to IBC transfers). Deposits funds into StreamSender contract. Stream parameters (rate, duration, recipient, destination rollup) are registered.

2. **Stream execution:** Frontend's Web Worker fires `submitTxBlock()` at interval (every 30 seconds). Ghost wallet signs IBC transfer from Rollup A → L1 → Settlement Minitia (hops 1-2). PaymentRegistry on settlement receives funds via IBC hook, records the payment, queries oracle for USD value, then initiates outbound IBC transfer Settlement → L1 → Rollup B (hops 3-4). **Note:** The hook-to-outbound-IBC pattern (contract calling `execute_cosmos(MsgTransfer)` from within an IBC hook callback) is [UNVERIFIED] — must be tested Day 1.

3. **Stream receipt:** StreamReceiver on Rollup B receives funds via IBC hook, credits to recipient's claimable balance. Frontend on receiver side polls balance and animates the climbing counter.

4. **Visualization:** Split-screen UI shows sender balance decreasing, bridge-crossing animation in center, receiver balance increasing. Oracle-converted USD values displayed alongside native token amounts.

---

## 3. User Flows

### Flow 1: Create a Payment Stream (Payer)
1. Payer opens GhostPay app, lands on Dashboard
2. Payer connects wallet via InterwovenKit (chain: Rollup A)
3. Payer clicks "New Stream"
4. Payer fills form: recipient address, destination rollup (Rollup B), total amount, duration
5. System calculates rate per interval and shows USD equivalent (oracle)
6. Payer clicks "Start Stream" — InterwovenKit prompts auto-sign enable (one-time)
7. Ghost wallet created with authz grant for IBC transfers + feegrant for gas
8. Funds deposited to StreamSender contract on Rollup A
9. Stream begins — frontend Web Worker fires micro-payments at interval
10. Dashboard shows active stream with countdown, amount sent, amount remaining

### Flow 2: Receive a Payment Stream (Receiver)
1. Receiver opens GhostPay app, connects wallet via InterwovenKit (chain: Rollup B)
2. Dashboard shows incoming streams with real-time balance counter climbing
3. Each stream shows: sender address, rate (tokens/sec + USD/sec), total received, time remaining
4. Receiver clicks "Claim" to withdraw accumulated funds to their wallet
5. Funds transfer from StreamReceiver contract to receiver's wallet on Rollup B

### Flow 3: Cancel a Stream (Payer)
1. Payer views active streams on Dashboard
2. Payer clicks "Cancel" on a stream
3. System stops the Web Worker interval
4. Remaining unstreamed funds returned to payer on Rollup A
5. Any in-flight IBC transfers complete normally (already sent)
6. Stream status updates to "Cancelled" on both sender and receiver views

### Flow 4: Demo Flow (Judge Experience)
```
Judge → Opens split-screen view
  → Left panel: Rollup A (Sender Dashboard)
  → Right panel: Rollup B (Receiver Dashboard)
  → Center: Bridge visualization

Judge sees:
  1. Pre-seeded active stream already running (demo data)
  2. Balance climbing on receiver side in real-time
  3. Bridge animation showing micro-payments crossing
  4. USD values updating via oracle
  5. Payer creates NEW stream → immediate bridge crossing visible
  6. Second stream from different address → both converging on same receiver
```

### Sequence Diagram: Stream Tick (Single Micro-Payment)
```
WebWorker -> InterwovenKit: submitTxBlock(ibcTransfer)
InterwovenKit -> GhostWallet: sign with authz (no popup)
GhostWallet -> StreamSender: call sendStreamTick()
StreamSender -> ICosmos(0xf1): execute_cosmos(MsgTransfer + hook memo)
ICosmos -> IBC Relayer A: packet to Settlement Minitia
IBC Relayer A -> PaymentRegistry: onRecvPacket (via EVM hook)
PaymentRegistry -> IConnectOracle: get_price("INIT/USD")
PaymentRegistry -> ICosmos(0xf1): execute_cosmos(MsgTransfer + hook memo)
ICosmos -> IBC Relayer B: packet to Rollup B
IBC Relayer B -> StreamReceiver: onRecvPacket (via EVM hook)
StreamReceiver -> ReceiverBalance: credit funds
Frontend(B) -> StreamReceiver: poll balance (TanStack Query)
Frontend(B) -> UI: animate counter increase
```

---

## 4. Technical Specifications

### PaymentRegistry (Settlement Minitia)
- **Purpose:** Central stream state management and cross-rollup routing
- **Interface:**
  - `registerStream(streamId, sender, receiver, sourceRollup, destRollup, totalAmount, duration)` — called via IBC hook on first payment
  - `processPayment(streamId, amount)` — called via IBC hook on each tick, routes to destination
  - `getStream(streamId) → Stream` — query stream state
  - `getStreamsByReceiver(receiver) → Stream[]` — list incoming streams
  - `getStreamsBySender(sender) → Stream[]` — list outgoing streams
- **Key Data Structures:**
  ```solidity
  struct Stream {
      bytes32 streamId;
      string sender;          // bech32 on source rollup
      string receiver;        // bech32 on dest rollup
      string sourceChannel;   // IBC channel to source rollup
      string destChannel;     // IBC channel to dest rollup
      uint256 totalAmount;    // total stream amount in native denom
      uint256 amountSent;     // amount already streamed
      uint256 ratePerTick;    // amount per interval
      uint256 startTime;
      uint256 endTime;
      uint256 lastTickTime;
      uint256 usdValueTotal;  // oracle-converted USD value
      StreamStatus status;    // ACTIVE, COMPLETED, CANCELLED
  }
  enum StreamStatus { ACTIVE, COMPLETED, CANCELLED }
  ```
- **Events:**
  - `StreamRegistered(streamId, sender, receiver, totalAmount, duration)`
  - `PaymentProcessed(streamId, amount, usdValue, tickNumber)`
  - `StreamCompleted(streamId, totalSent)`
  - `StreamCancelled(streamId, refundAmount)`
- **Dependencies:** ICosmos precompile (0xf1), IConnectOracle

### StreamSender (Rollup A)
- **Purpose:** Accept deposits and emit IBC transfers for stream ticks
- **Interface:**
  - `createStream(receiver, destChannel, totalAmount, duration) → streamId` — deposits funds, returns stream ID
  - `cancelStream(streamId)` — refunds remaining balance
  - `getStreamInfo(streamId) → StreamInfo` — local stream state
- **Key Data Structures:**
  ```solidity
  struct StreamInfo {
      bytes32 streamId;
      address sender;
      string receiver;
      string destChannel;
      uint256 totalAmount;
      uint256 amountSent;
      uint256 ratePerTick;
      uint256 startTime;
      uint256 endTime;
      bool active;
  }
  ```
- **Events:**
  - `StreamCreated(streamId, sender, receiver, totalAmount, duration)`
  - `TickSent(streamId, amount, tickNumber)`
  - `StreamCancelled(streamId, refundAmount)`
- **Dependencies:** ICosmos precompile (0xf1)

### StreamReceiver (Rollup B)
- **Purpose:** Credit received funds to recipient addresses
- **Interface:**
  - `onReceivePayment(streamId, receiver, amount)` — called via IBC hook
  - `claim(amount)` — withdraw claimable balance
  - `getClaimable(address) → uint256` — query claimable amount
  - `getIncomingStreams(address) → IncomingStream[]` — list streams
- **Key Data Structures:**
  ```solidity
  struct IncomingStream {
      bytes32 streamId;
      string sender;
      uint256 totalReceived;
      uint256 lastReceiveTime;
      bool active;
  }
  ```
- **Events:**
  - `PaymentReceived(streamId, receiver, amount)`
  - `FundsClaimed(receiver, amount)`
- **Dependencies:** IBC hook receiver interface

### Frontend
- **Purpose:** Stream creation, visualization, wallet management
- **Interface:** React SPA with routes: `/` (dashboard), `/create` (new stream), `/stream/:id` (detail)
- **Key Data Structures:**
  ```typescript
  interface StreamView {
    streamId: string;
    sender: string;
    receiver: string;
    sourceRollup: string;
    destRollup: string;
    totalAmount: string;
    amountSent: string;
    ratePerTick: string;
    usdRate: string;
    startTime: number;
    endTime: number;
    status: 'active' | 'completed' | 'cancelled';
  }
  ```
- **Dependencies:** InterwovenKit, TanStack Query, ethers.js/viem

### Settlement Minitia (Infrastructure)
- **Purpose:** Dedicated EVM rollup hosting PaymentRegistry and oracle, acting as payment routing hub
- **Interface:** Standard EVM JSON-RPC at port 8545, REST at 1317, RPC at 26657
- **Dependencies:** weave CLI for deployment, rapid-relayer for IBC, OPinit bots (executor, challenger)
- **Constraints:** Requires ~7-8 INIT for OPinit bot funding. Oracle sidecar must be enabled at launch.

### IBC Relayers (Infrastructure)
- **Purpose:** Relay IBC packets between L1 and each Minitia (Settlement, Rollup A, Rollup B)
- **Interface:** Background process — `weave relayer start`
- **Dependencies:** rapid-relayer binary, L1 RPC endpoint, Minitia RPC endpoints
- **Constraints:** One relayer instance per L1↔Minitia pair (3 pairs total: L1↔Rollup A, L1↔Settlement, L1↔Rollup B). No direct L2↔L2 channels. Full stream tick = 4 hops via L1.

### ConnectOracle (Infrastructure)
- **Purpose:** Provide USD price conversion for stream amounts
- **Interface:** `IConnectOracle.get_price(pair_id)` — Solidity call on settlement Minitia
- **Dependencies:** Slinky/Connect oracle sidecar running alongside settlement node
- **Constraints:** Available pairs depend on network config. INIT/USD may not exist — fallback to ETH/USD.

### Ghost Wallet (Auto-Sign)
- **Purpose:** Sign stream micro-payments without user intervention
- **Interface:** Managed by InterwovenKit `autoSign.enable(chainId)` / `autoSign.disable(chainId)`
- **Constraints:**
  - Scoped to message types: `/ibc.applications.transfer.v1.MsgTransfer` (for IBC ticks), `/minievm.evm.v1.MsgCall` (for calling StreamSender.sendTick() which builds and fires the IBC transfer)
  - Expires based on user selection (10min to 1 week)
  - Frontend must be open — no background execution
  - PeriodicAllowance feegrant caps gas spending per period

---

## 5. API Contracts

### External API: Initia REST API (Settlement Minitia)
- **Base URL:** `http://localhost:1317` (local) / `https://{settlement-rest-url}` (testnet)
- **Authentication:** None (public RPC)
- **Rate Limits:** None (own rollup)

#### Endpoint: GET /minievm/evm/v1/connect_oracle
- **Request:** No body
- **Response (success):**
  ```json
  { "address": "0x031ECb63480983FD216D17BB6e1d393f3816b72F" }
  ```

### External API: Initia JSON-RPC (EVM)
- **Base URL:** `http://localhost:8545` (local) / `https://{rollup-jsonrpc-url}` (testnet)
- **Authentication:** None
- **Rate Limits:** None (own rollup)

#### Endpoint: Standard Ethereum JSON-RPC
- **Methods used:** `eth_call`, `eth_sendRawTransaction`, `eth_getTransactionReceipt`, `eth_blockNumber`
- **Request:** Standard JSON-RPC 2.0 format
- **Response:** Standard JSON-RPC 2.0 format

### External API: Initia Testnet Faucet
- **Base URL:** `https://faucet.testnet.initia.xyz/`
- **Authentication:** Gitcoin Passport
- **Rate Limits:** Once per 24 hours
- **Risk:** Could block Day 1 if Gitcoin Passport not ready

### External API: Connect Oracle (On-Chain)
- **Base URL:** On-chain at known contract address per minitia
- **Authentication:** None (public read)
- **Rate Limits:** Gas cost per query (~JSON parsing in Solidity)

#### Query: get_price(string pair_id)
- **Request:** Solidity call with pair string (e.g., "INIT/USD", "ETH/USD")
- **Response:**
  ```json
  {
    "price": 1250000000,
    "timestamp": 1712500800,
    "height": 12345,
    "nonce": 100,
    "decimal": 8,
    "id": 1
  }
  ```

---

## 6. Demo Script

**Total Duration:** 3-4 minutes
**Format:** Screen recording (recorded demo, per hackathon rules)

### Scene 1: The Problem (0:00 - 0:25)
**Screen:** Title card — "GhostPay: Payment Streams Across Rollups"
**Voiceover:** "Every crypto payment is all or nothing. Send a hundred dollars or zero. No partial payments, no streams, no automation. And if you need to pay someone on a different rollup? Bridge, wait, swap, send. Every single time. GhostPay changes that."
**Action:** Animated text appears with each pain point. Quick cut to a wallet showing the bridge-wait-swap-send flow.

### Scene 2: What GhostPay Does (0:25 - 0:50)
**Screen:** Architecture diagram animation — money flowing from Rollup A through Settlement Minitia to Rollup B
**Voiceover:** "GhostPay turns payments into streams that flow automatically across rollups. A dedicated settlement rollup routes money between any two chains via IBC. Ghost wallets sign micro-transactions on autopilot. The receiver watches their balance climb in real-time."
**Action:** Animated flow diagram, then transition to live app.

### Scene 3: Creating a Stream (0:50 - 1:30)
**Screen:** GhostPay app — Create Stream form
**Voiceover:** "Here on Rollup A, I create a payment stream. Ten INIT over five minutes to this address on Rollup B. One click to enable auto-signing — that creates a ghost wallet scoped to IBC transfers only. Hit Start Stream."
**Action:** Fill form fields. Click enable auto-sign (drawer opens, confirm). Click Start Stream. Show the stream appear on dashboard.

### Scene 4: The Bridge Crossing — Centerpiece (1:30 - 2:30)
**Screen:** Split-screen — Rollup A (left), bridge animation (center), Rollup B (right)
**Voiceover:** "Watch what happens. On the left, tokens leave Rollup A every thirty seconds — automatically, no popups. They cross through our settlement rollup in the center. And on the right, the receiver's balance climbs in real-time. This is live. Real IBC transfers. Real cross-rollup money movement."
**Action:** Show 3-4 stream ticks crossing the bridge. Balance counter climbs on receiver side. USD values update via oracle. Highlight the auto-sign indicator (no wallet popups).

### Scene 5: Multiple Streams Converging (2:30 - 3:00)
**Screen:** Same split-screen, but now a second stream starts from a different address
**Voiceover:** "Now a second stream from a different payer. Both converging on the same receiver. Real-time revenue splitting across rollups — something that was impossible before Initia's multi-rollup architecture."
**Action:** Second stream appears, both streams visible crossing the bridge. Receiver balance accelerates.

### Scene 6: Why Initia (3:00 - 3:30)
**Screen:** Feature diagram showing 5 Initia integrations
**Voiceover:** "GhostPay is structurally impossible without Initia. Our own settlement rollup for routing. IBC for cross-chain transfers. Authz and feegrant for ghost wallets. Connect oracle for USD conversion. InterwovenKit for seamless wallet management. Remove any one of these and the product breaks. This is not a port. This is Initia-native infrastructure."
**Action:** Each feature highlights as mentioned. Final card: "Payment rails for Initia's multi-rollup future."

### Scene 7: Close (3:30 - 3:45)
**Screen:** Logo + tagline
**Voiceover:** "GhostPay. Continuous money movement across rollups."
**Action:** Logo animation, GitHub link, team info.

### Demo Prerequisites

**Seed State Table** — exact state that must exist before recording begins.

| Item | Value | Network / Location | Created By |
|------|-------|-------------------|------------|
| Payer wallet (sender) | Funded with 100 INIT | Rollup A | seed-demo.ts |
| Receiver wallet | Empty initially | Rollup B | seed-demo.ts |
| Second payer wallet | Funded with 50 INIT | Rollup A | seed-demo.ts |
| Active stream (pre-seeded) | 10 INIT over 5min, ~2min elapsed | Settlement Minitia | seed-demo.ts |
| StreamSender contract | Deployed + verified | Rollup A | deploy script |
| PaymentRegistry contract | Deployed + verified | Settlement Minitia | deploy script |
| StreamReceiver contract | Deployed + verified | Rollup B | deploy script |
| IBC channels | L1↔Settlement, L1↔Rollup A, L1↔Rollup B | All chains | weave relayer |
| Oracle price feed | INIT/USD or ETH/USD active | Settlement Minitia | oracle sidecar |
| Auto-sign enabled | Ghost wallet active for payer | Rollup A | seed-demo.ts |

**Invariant:** Running `npx ts-node scripts/seed-demo.ts` from project root must produce this exact state from scratch. The script must be idempotent.

---

## 7. Risk Register

| # | Risk | Severity | Likelihood | Impact | Mitigation | Decision Tree |
|---|------|----------|-----------|--------|------------|:---:|
| 1 | IBC relayer setup eats 2+ days — builder has zero Cosmos experience | CRITICAL | HIGH | Blocks entire cross-rollup architecture | Day 1 morning task. Use Initia default relayer config. If blocked by EOD 1, fall back to L1 settlement. | Plan Phase 0 |
| 2 | Minitia deployment blocked (faucet issues, weave bugs) | CRITICAL | MEDIUM | Cannot deploy own rollup — core requirement | Day 1 parallel task. Gitcoin Passport ready in advance. L1-only fallback if completely blocked. | Plan Phase 0 |
| 3 | Auto-signing permission scoping underdocumented — ghost wallet fires wrong txs or fails | HIGH | MEDIUM | Stream micro-payments don't fire automatically | Start with GenericAuthorization for IBC transfers, test minimal scope. Fall back to manual signing per tick. | Plan Phase 1 |
| 4 | L2→L2 two-hop latency too high for compelling demo | HIGH | LOW | Bridge crossing feels slow/broken in demo | Pre-seed active streams. Show already-running streams. Optimize tick interval to mask latency. | Plan Phase 2 |
| 5 | Oracle INIT/USD pair not available on testnet | HIGH | MEDIUM | USD conversion display broken | Query get_all_currency_pairs() first. Fall back to ETH/USD or hardcoded rate for demo. | Plan Phase 1 |
| 6 | Frontend Web Worker streaming stops when tab loses focus | MEDIUM | HIGH | Stream pauses during demo if presenter switches tabs | Use dedicated browser window. Keep tab focused during recording. Visibilitychange API to resume. | Plan Phase 3 |
| 7 | Testnet instability during demo recording | MEDIUM | LOW | Demo fails mid-recording | Record with pre-seeded state. Multiple takes. Record segments separately if needed. | Plan Phase 4 |
| 8 | EVM IBC hooks don't trigger destination contract correctly | HIGH | MEDIUM | Cross-chain contract execution fails — funds received but not credited | Test hook memo format exhaustively on Day 2. Manual credit as fallback (receiver claims directly). | Plan Phase 1 |
| 9 | OPinit bot funding insufficient from faucet | MEDIUM | MEDIUM | Can't keep rollup running during demo | Request from multiple faucets if possible. Minimize bot gas usage. Monitor balances. | Plan Phase 0 |
| 10 | Scope creep — adding features beyond core stream flow | HIGH | HIGH | Miss feature freeze deadline | Feature set locked: stream create + visualize + bridge cross. No additions. | All Phases |
| 11 | Solidity JSON string building for MsgTransfer is fragile | MEDIUM | HIGH | IBC transfers fail due to malformed JSON | Use tested string concatenation pattern from initia-evm-contracts repo. Unit test JSON output. | Plan Phase 1 |
| 12 | InterwovenKit closed-source — debugging integration issues is harder | MEDIUM | MEDIUM | Blocked on opaque library behavior | Rely on published docs + API reference. Test empirically. Join Initia Discord for support. | Plan Phase 1 |
| 13 | Settlement contract cannot initiate outbound IBC from within inbound IBC hook callback | CRITICAL | MEDIUM | Entire 4-hop routing architecture breaks — funds arrive at Settlement but cannot be forwarded | Test this exact pattern Day 1: deploy minimal contract that calls execute_cosmos(MsgTransfer) inside a hook callback. If blocked: deploy PaymentRegistry on L1 directly (2-hop fallback). | Plan Phase 0 |
| 14 | IBC-received tokens have IBC denom (ibc/HASH), not native denom — claim() may fail | HIGH | HIGH | StreamReceiver holds IBC-denominated tokens but claim() tries to send native balance | Verify empirically on Day 1 whether minievm credits IBC tokens to EVM-native balance. If not: claim() must use Cosmos-side bank send via execute_cosmos. | Plan Phase 1 |

### Risk Categories Covered
- [x] Technical risks (#1, #2, #3, #5, #8, #11, #12, #13, #14)
- [x] Competitive risks (none — zero competitors in cross-rollup streaming)
- [x] Time risks (#10)
- [x] Demo risks (#4, #6, #7)
- [x] Judging risks (#4 — demo must feel real-time)
- [x] Scope risks (#10)

---

## 8. Day-by-Day Build Plan

| Day | Date | Primary Objective | Secondary Objective | Deliverable |
|:---:|------|------------------|--------------------|-----------  |
| 1 | Apr 8 | Deploy 3 Minitias (Settlement, Rollup A, Rollup B) + 3 IBC relayers | Gitcoin Passport + faucet tokens. Test hook-to-IBC pattern (Risk #13). | 3 running Minitias with IBC channels to L1. GO/NO-GO GATE. |
| 2 | Apr 9 | Core contracts: PaymentRegistry + StreamSender + StreamReceiver | Test IBC transfers end-to-end (manual) | Deployed contracts with IBC routing working |
| 3 | Apr 10 | Auto-signing integration + ghost wallet + stream execution | Oracle price feed integration | Working stream: create → auto-sign → IBC → receive |
| 4 | Apr 11 | Frontend: Dashboard + Create Stream + real-time visualization | Split-screen layout + bridge animation | Functional UI connected to contracts |
| 5 | Apr 12 | End-to-end integration testing + demo data seeding | Bug fixes, edge case handling | Complete working demo flow |
| 6 | Apr 13 | **FEATURE FREEZE.** Polish, seed demo data, recording prep | submission.json + repo cleanup | Feature-complete, demo-ready |
| 7 | Apr 14 | Demo video recording + editing | Pitch refinement | Recorded demo video |
| 8 | Apr 15 | **SUBMISSION.** Final packaging, description, screenshots | Last-minute fixes only | Submitted on DoraHacks |

### Buffer Allocation
- Day 5 is the primary buffer day — integration testing absorbs delays from Days 1-4
- Day 6 feature freeze is NON-NEGOTIABLE — no new features after this point
- If Day 1 go/no-go fails: switch to L1-only fallback, Days 2-4 compress to simpler architecture

### Day 1 Go/No-Go Gate
**Morning:** Deploy Settlement Minitia first. Test one relayer (L1↔Settlement). If that works, deploy Rollup A and Rollup B. Test hook-to-IBC pattern (Risk #13): deploy minimal contract on Settlement that calls `execute_cosmos(MsgTransfer)` inside an IBC hook callback.
- All 3 Minitias + relayers + hook-to-IBC work by EOD 1 → full 4-hop architecture
- Hook-to-IBC blocked but Minitias work → deploy PaymentRegistry on L1 (2-hop fallback, still uses own rollups for sender/receiver)
- Minitia deploy blocked → L1-only settlement (same concept, 2 hops, score drops from ~8.0 to ~6.5)

---

## 9. Dependencies & Prerequisites

### External Services
| Service | URL | Auth Required | Status |
|---------|-----|:---:|---|
| Initia Testnet L1 | https://rpc.testnet.initia.xyz | No | Live |
| Initia REST API | https://rest.testnet.initia.xyz | No | Live |
| Initia Faucet | https://faucet.testnet.initia.xyz | Gitcoin Passport | Live |
| Settlement Minitia (own) | http://localhost:8545 | No | Deploy Day 1 |
| IBC Relayer (rapid-relayer) | Local process | No | Deploy Day 1 |

### Development Tools
| Tool | Version | Purpose | Install Command |
|------|---------|---------|----------------|
| Node.js | 20+ | Frontend + scripts | `nvm install 20` |
| Foundry | Latest | Solidity contracts | `curl -L https://foundry.paradigm.xyz \| bash && foundryup` |
| weave CLI | Latest | Minitia deployment | `go install github.com/initia-labs/weave@latest` |
| Go | 1.22+ | weave dependency | `brew install go` |
| Vite | 5+ | Frontend bundler | `npm create vite@latest` |
| pnpm | 9+ | Package manager | `npm install -g pnpm` |

### Accounts & Credentials
| Account | Purpose | How to Get |
|---------|---------|-----------|
| Gitcoin Passport | Faucet access | https://passport.gitcoin.co — set up BEFORE Day 1 |
| Deployer wallet | Contract deployment + OPinit bots | Generate via `cast wallet new` |
| Test payer wallet | Demo stream sender | Generate via `cast wallet new` |
| Test receiver wallet | Demo stream receiver | Generate via `cast wallet new` |

### On-Chain Addresses
| Item | Address | Network | Source |
|------|---------|---------|--------|
| ICosmos precompile | 0x00000000000000000000000000000000000000f1 | All EVM Minitias | [VERIFIED] Initia docs |
| ConnectOracle | Query `${REST_URL}/minievm/evm/v1/connect_oracle` at runtime | Settlement Minitia | [VERIFIED] Initia docs |
| StreamSender | DEPLOY_AND_RECORD_ADDRESS_HERE | Rollup A | Deploy Day 2 |
| PaymentRegistry | DEPLOY_AND_RECORD_ADDRESS_HERE | Settlement Minitia | Deploy Day 2 |
| StreamReceiver | DEPLOY_AND_RECORD_ADDRESS_HERE | Rollup B | Deploy Day 2 |

---

## 10. Concerns Compliance

| # | Severity | Concern | How PRD Addresses It |
|---|:---:|---------|----------------------|
| 1 | C | Demo failure: Cross-rollup payment stream must work end-to-end without manual intervention | Demo script Scene 4 shows live bridge crossing. Pre-seeded streams ensure something is always running. Seed-demo.ts creates exact demo state. |
| 2 | C | Integration failure: IBC relayer must be running and settlement Minitia must be producing blocks during demo | Day 1 go/no-go gate. Risk #1 and #2 have decision trees. Demo recorded with all services verified running. |
| 3 | C | Auto-signing failure: Ghost wallet must fire micro-transactions without user wallet popups | Ghost wallet uses InterwovenKit autoSign.enable() with scoped permissions. Risk #3 has fallback to manual signing. |
| 4 | C | Submission compliance: Own rollup, InterwovenKit, auto-signing + bridge as native features, submission.json | All 5 native features are load-bearing in architecture. Day 6 includes submission.json preparation. |
| 5 | C | Day 1 go/no-go: If Minitia deploy + IBC relayer both fail by EOD 1, must switch to L1-only fallback | Day-by-day plan Day 1 is dedicated to infra. Fallback architecture defined in WINNER-BRIEF. |
| 6 | I | Scope creep: Core feature set locked — no additions during build | Risk #10 enforces feature freeze Day 6. Only: stream create + visualize + bridge cross. |
| 7 | I | Oracle integration: USD conversion must display correctly on streams | Risk #5 covers oracle pair availability with fallback to ETH/USD or hardcoded rate. |
| 8 | I | Demo data: Pre-seeded streams with visible activity for demo recording | Seed State Table in Section 6 defines exact pre-seeded state. seed-demo.ts implements it. |
| 9 | I | Code quality: Solidity contracts must compile and deploy without errors. Frontend must build without warnings. | Day 5 integration testing. Foundry tests for contracts. Build verification on Day 6. |
| 10 | I | Time budget: Feature-freeze Day 6. Demo prep Days 7-8. No exceptions. | Day-by-day plan enforces this. Buffer on Day 5. |
| 11 | A | Polish: UI animations are advisory — function and demo flow take priority over visual polish | Demo script prioritizes working flow over visual polish. Bridge animation is CSS-only, not complex. |
| 12 | A | .init usernames: Nice-to-have display feature, not required for core flow | Explicitly out-of-scope per WINNER-BRIEF. |
| 13 | A | Multi-stream convergence: Bonus demo moment if time permits, not core requirement | Demo Scene 5 includes it as bonus if time allows — not gating on it. |
