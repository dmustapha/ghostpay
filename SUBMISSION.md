# GhostPay — Continuous Payment Streams on Initia

## One-Liner
GhostPay turns lump-sum crypto payments into continuous money streams with per-tick delivery, real-time USD conversion via Connect Oracle, and claimable balances — all on its own minievm rollup.

## Problem
Every crypto payment is all-or-nothing. No partial payments, no streams, no automation. Paying someone means choosing an amount and clicking send. Want to pay a contractor hourly? Send 720 separate transactions. Want continuous revenue splitting? Impossible.

## Solution
GhostPay deploys a dedicated settlement minitia (`ghostpay-1`) that streams payments in real-time. A sender creates a stream specifying recipient, amount, and duration. A ghost wallet (auto-sign) fires micro-transactions every 30 seconds — no wallet popups. The receiver watches their claimable balance climb continuously.

### How It Works
```
Sender → StreamSender.createStream() → auto-tick every 30s
  └→ StreamSender.sendTick()
       ├→ cosmos bank send (tokens to StreamReceiver via ICosmos)
       └→ PaymentRegistry.processPayment() (bookkeeping + oracle USD)
            └→ StreamReceiver.onReceivePayment() (credit claimable)

Receiver → StreamReceiver.claim() → withdraw funds
```

## Initia Features Used (5 native integrations)

| Feature | How It's Used | Load-Bearing? |
|---------|--------------|:---:|
| **Own Minitia** | GhostPay runs on `ghostpay-1`, its own minievm rollup (Bridge ID 1808) | Yes |
| **ICosmos Precompile** | Contracts call `execute_cosmos` at `0xf1` for cosmos bank sends — this is how tokens move between contracts | Yes |
| **Connect Oracle** | PaymentRegistry queries INIT/USD price on every tick for real-time USD conversion | Yes |
| **minievm** | All 3 Solidity contracts leverage EVM↔Cosmos interop; wouldn't work on vanilla EVM | Yes |
| **Wallet Widget** | `@initia/react-wallet-widget` for seamless Initia wallet connection and tx signing | Yes |

Remove any one of these and the product breaks. This is Initia-native infrastructure, not a port.

## Technical Depth

### Contracts (Solidity, Foundry)
- **StreamSender** — creates streams, manages lifecycle, sends ticks via ICosmos precompile
- **PaymentRegistry** — processes payments, queries Connect Oracle, tracks USD values
- **StreamReceiver** — accumulates claimable balances, handles withdrawals via ICosmos

### Key Architecture Decisions
- **DEV-007**: All contracts on single chain (simplified from multi-chain IBC after discovering minitias only have IBC channels to L1)
- **DEV-008**: `msg.value` doesn't work on minievm; pre-fund contracts via cosmos bank send
- **DEV-009**: `execute_cosmos` queues msgs post-EVM; StreamSender sends directly to StreamReceiver

### Frontend (React + Vite + Tailwind)
- Split-screen demo view: sender panel, bridge visualization, receiver panel
- Real-time counter interpolation (BigInt precision, 100ms updates)
- Auto-tick via `useStreamTick` hook (ghost wallet simulation)
- 3 pages: Dashboard, Create Stream, Live Demo

### Testing
- 115 tests passing (unit + integration + edge cases)
- Security audit: 0 critical, 0 high findings
- E2E verified: createStream → sendTick (2M gas) → processPayment → onReceivePayment → claim

## Screenshots

### Live Demo View
Split-screen showing active streams (sender), bridge visualization (center), and claimable balance (receiver) with real on-chain data.

### Create Stream
Clean form for creating payment streams with rate preview, ghost wallet toggle, and Initia wallet integration.

## Links
- **GitHub**: https://github.com/dmustapha/ghostpay
- **Track**: DeFi
- **Chain**: ghostpay-1 (minievm, Bridge ID 1808)
