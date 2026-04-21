# GhostPay

**Payment streaming infrastructure on Initia minievm.**

Turns lump-sum payments into continuous money streams with per-tick delivery, real-time USD conversion via Connect Oracle, and claimable balances — all powered by the ICosmos precompile on minievm.

Built for [INITIATE: The Initia Hackathon (Season 1)](https://dorahacks.io/hackathon/initia-initiate) | **Track: DeFi**

---

## How It Works

1. **Sender creates a stream** — specifies recipient, amount, and duration
2. **Ghost Wallet auto-ticks** — every 30 seconds, a micro-payment is sent without wallet popups
3. **Registry processes** — PaymentRegistry records each tick with oracle USD pricing
4. **Receiver accumulates** — StreamReceiver credits claimable balance in real-time
5. **Receiver claims** — withdraw accumulated funds at any time

```
Sender → StreamSender.createStream() → auto-tick every 30s
  │
  └→ StreamSender.sendTick()
       ├→ cosmos bank send (tokens to StreamReceiver)
       └→ PaymentRegistry.processPayment() (bookkeeping + oracle)
            └→ StreamReceiver.onReceivePayment() (credit claimable)

Receiver → StreamReceiver.claim() → cosmos bank send to receiver
```

## Initia Features Used

| Feature | How It's Used |
|---------|--------------|
| **Own Minitia** | GhostPay runs on its own minievm rollup (`ghostpay-1`) |
| **ICosmos Precompile** | Contracts execute cosmos bank sends for token transfers |
| **Connect Oracle** | Real-time INIT/USD price for every tick payment |
| **minievm** | Solidity contracts with cosmos interop via `0xf1` precompile |
| **InterwovenKit** | `@initia/interwovenkit-react` for seamless wallet connection |

## Architecture

Three smart contracts deployed on a single minievm chain:

- **StreamSender** — creates streams, sends ticks, manages stream lifecycle
- **PaymentRegistry** — processes payments, queries oracle, tracks USD values
- **StreamReceiver** — accumulates claimable balances, handles withdrawals

Key design decisions:
- **DEV-007**: All contracts on same chain (simplified hub-and-spoke)
- **DEV-008**: `msg.value` doesn't work on minievm; pre-fund contracts via cosmos bank send
- **DEV-009**: `execute_cosmos` queues msgs post-EVM; StreamSender sends tokens directly to StreamReceiver

## Deployed Contracts

Chain: `ghostpay-1` (minievm)

| Contract | Address |
|----------|---------|
| StreamSender | `0x69C58360fa715717C5D72Eb21EB3fDe69231A4A7` |
| PaymentRegistry | `0xaE53c86bA6a0C90e607E571FEc1F22DC591ED634` |
| StreamReceiver | `0x6890d4576c55410831CD3A01bf0e40F3C0B984A9` |

## Tech Stack

- **Contracts**: Solidity 0.8.24 (Foundry), OpenZeppelin Ownable2Step
- **Frontend**: TypeScript, React 19, Vite, Tailwind CSS, viem
- **Wallet**: `@initia/interwovenkit-react` (InterwovenKit) with built-in auto-signing
- **Chain**: Initia minievm minitia
- **Tests**: 124 passing (Foundry)

## Project Structure

```
ghostpay/
├── contracts/          # Solidity smart contracts (Foundry)
│   ├── src/
│   │   ├── StreamSender.sol
│   │   ├── PaymentRegistry.sol
│   │   ├── StreamReceiver.sol
│   │   └── interfaces/
│   └── script/Deploy.s.sol
├── frontend/           # React + Vite frontend
│   ├── src/
│   │   ├── pages/      # Dashboard, CreateStream, DemoView
│   │   ├── hooks/      # useStreams, useStreamTick, useOracle
│   │   ├── components/ # StreamCard, StreamCounter, BridgeVisualization
│   │   └── config/     # chains.ts, contracts.ts
│   └── .env.example
├── infra/              # Chain configuration files
└── .initia/            # Submission metadata
```

## Running Locally

### Prerequisites

- [Foundry](https://getfoundry.sh/) for contract compilation
- Node.js 18+
- minitiad binary (minievm v1.2.15)

### Start the Chain

```bash
minitiad start --home ~/.minitia
```

> **Note:** If using weave, the home directory may be at `~/.weave/data/minievm@v1.2.15/` instead.

### Deploy Contracts

```bash
cd contracts
export DEPLOYER_PRIVATE_KEY=<your-key>
export STREAM_DENOM=umin
export ORACLE_ADDRESS=0x0000000000000000000000000000000000000000
export ORACLE_PAIR_ID="INIT/USD"

forge script script/Deploy.s.sol:DeployAll \
  --rpc-url http://localhost:8545 \
  --broadcast --with-gas-price 0 --skip-simulation
```

### Seed Demo Data

Pre-seeds a demo stream for testing the UI:

```bash
bash scripts/seed-demo.sh
```

This creates a 2 MIN stream over 10 minutes, funds the StreamSender contract, and sends the first tick.

### Start Frontend

```bash
cd frontend
cp .env.example .env  # Update with your contract addresses
npm install --legacy-peer-deps
npm run dev
```

## Team

- **dami** — solo builder

## License

MIT
