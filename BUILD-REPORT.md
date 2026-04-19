# Build Report — GhostPay
Generated: 2026-04-08
Builder: hackathon-build skill

## Summary
| Phase | Steps | Status | Notes |
|-------|-------|--------|-------|
| 0 | 0.1–0.6 | **COMPLETE** | Infrastructure + Go/No-Go — ALL PASS |
| 1 | 1.1–1.9 | **COMPLETE** | All contracts on Settlement (DEV-007), 12/12 tests, E2E verified, gas snapshot generated |
| 2 | 2.1–2.4 | **COMPLETE** | Frontend scaffolding, types, config, hooks, oracle graceful degradation |
| 3 | 3.1–3.3 | **COMPLETE** | Layout, StreamCard, StreamCounter, BridgeViz, Dashboard, CreateStream, DemoView, App shell |
| 4 | 4.1–4.5 | **COMPLETE** | Seed script, E2E tick verified (claimable updated), ABI fixes, .env.example |
| 5 | 5.1–5.4 | **COMPLETE** | Bug fix pass (clean), submission.json, seed auto-tick, .gitignore |
| 6 | 6.1–6.3 | **READY** | Demo recording + submission — requires human action |

## Deviations from Architecture

| ID | Component | ARCHITECTURE Said | ACTUAL | Reason | Downstream Impact |
|----|-----------|-------------------|--------|--------|-------------------|
| DEV-001 | Minitia addresses | coin_type 60 (ethsecp256k1) for l1/l2_address | All addresses use coin_type 118 (secp256k1) | minitiad keyring derives addresses with secp256k1; mismatch causes "address mismatch" error | All system key addresses are 118-derived; must fund 118 addresses on L1 |
| DEV-002 | L1 RPC URL | `https://rpc.testnet.initia.xyz` | `https://rpc.testnet.initia.xyz:443` | IBC relayer requires explicit port; "missing port in address" error without it | All RPC URLs to L1 need explicit :443 |
| DEV-003 | ICosmos interface | `execute_cosmos(string)` selector 0xd46f64e6 | `execute_cosmos(string,uint64)` selector 0x56c657a5 | minievm v1.2.15 requires gas parameter; GitHub ICosmos.sol outdated | **Critical** — ALL contracts must use updated 2-param signature |
| DEV-004 | EVM transaction method | `cast send` / standard EVM tx | `minitiad tx evm call` only | eth_getBalance returns 0 on minievm; cast send fails with "ERC20: transfer amount exceeds balance" | **Critical** — ALL contract interactions must use minitiad CLI |
| DEV-005 | Gas estimation | `--gas auto` | `--gas 500000` (fixed) | Gas simulation fails for execute_cosmos (queued cosmos msgs not handled in simulation) | Minor — use fixed gas for all execute_cosmos calls |
| DEV-006 | Deployment method | `minitiad tx evm call` only (DEV-004) | `forge script --with-gas-price 0 --skip-simulation` works | Foundry broadcast succeeds when gas price is 0 and simulation skipped | Positive — standard Foundry deploy flow usable |
| DEV-007 | IBC topology | Direct IBC between rollups with EVM hooks | Hub-and-spoke: all IBC routes through L1, EVM hooks fire on L1 (no minievm) | Initia minitias only have IBC channels to L1, not to each other. EVM hooks only fire on the destination chain (L1), which doesn't run minievm | **Critical** — All 3 contracts deployed on Settlement (single chain). Direct EVM calls replace IBC hooks |
| DEV-008 | Token funding | `msg.value` in createStream | `amount` parameter + cosmos bank pre-funding | On minievm, EVM `msg.value` doesn't work because EVM balance is always 0 (cosmos bank balance not reflected in EVM msg.value) | **Significant** — createStream takes explicit amount param. Users must cosmos bank send to contract first |
| DEV-009 | Token forwarding | PaymentRegistry forwards tokens via cosmos bank send then calls StreamReceiver | StreamSender sends tokens directly to StreamReceiver; PaymentRegistry is bookkeeping only | `execute_cosmos` queues cosmos msgs — they execute AFTER EVM returns. Chained sends (A→B→C) fail because B has no balance when it tries to send to C | **Significant** — StreamSender handles all token movement, PaymentRegistry is pure bookkeeping + oracle |

| DEV-010 | Gas for sendTick | `--gas 500000` (DEV-005) | `--gas 2000000` required | sendTick call chain: bank send + processPayment (oracle) + onReceivePayment — actual gas ~472K but 500K limit causes "out of gas in precompile" | **Minor** — all sendTick calls need 2M gas |
| DEV-011 | Frontend ABI types | `getClaimable(string)`, events with `string` receiver | `getClaimable(address)`, events with `address` receiver | Contract uses `address` keys (bech32→address conversion inside onReceivePayment) | **Minor** — frontend ABIs corrected |
| DEV-012 | Deployer address | DEPLOYER_BECH32=init1lvnz8d (coin_type 60) | Keyring deployer=init1sxqh6a (coin_type 118), EVM=0x81817d | minitiad keyring uses coin_type 118 derivation for same private key | **Significant** — seed script uses keyring deployer |

## Failed Attempts & Resolutions
| Step | Error | Attempts | Resolution |
|------|-------|----------|------------|
| 0.2 | `address mismatch for key Validator, keyring=init19738..., input=init1we99...` | 3 | Set all addresses (l1, l2, da) to coin_type 118 derived addresses |
| 0.2 | `failed to run lifecycle during ibc step 5: missing port in address` | 2 | Added explicit `:443` port to L1 RPC URL |
| 1.8 | IBC packet from Rollup A arrived at L1, not Settlement | 1 | Discovered DEV-007: hub-and-spoke topology. Redesigned for single-chain deployment |
| 1.8 | `ERC20: transfer amount exceeds balance` on createStream with msg.value | 2 | DEV-008: msg.value doesn't work on minievm. Replaced with amount param + cosmos bank pre-funding |
| 1.8 | `ERC20: transfer amount exceeds balance` on sendTick (chained cosmos sends) | 1 | DEV-009: execute_cosmos queues msgs, chained sends fail. StreamSender sends directly to StreamReceiver |
| 1.8 | `Stream expired` on sendTick | 1 | Previous stream expired during debugging. Created new stream with 600s duration |
| 1.8 | Funding tx appeared to succeed (broadcast code 0) but on-chain code 23 | 1 | Validator had 4.99M umin, tried to send 5M. Reduced funding amount to 2M |

## Verification Results
| Phase | Command | Expected | Actual | Pass? |
|-------|---------|----------|--------|-------|
| 0.2 | `minitiad launch --with-config` | Minitia deployed, bridge ID assigned | Bridge ID 1808, IBC channels created (channel-0/channel-3803 transfer, channel-1/channel-3804 nft-transfer) | PASS |
| 0.3 | `minitiad launch --with-config` × 2 | Rollup A + B deployed | Rollup A: bridge 1809, ch-0/ch-3805. Rollup B: bridge 1810, ch-0/ch-3807 | PASS |
| 0.5 | HookToIbcTest.onHookReceive("channel-0") | IBC packet sent from contract | send_packet on channel-0→channel-3803, sequence 2, execute_cosmos returned true | **PASS — GO** |
| 1.3 | `forge build --via-ir` | All contracts compile | Compiler run successful! | PASS |
| 1.5 | `forge test -vvv` | All tests pass | 12 tests passed, 0 failed (StreamSender 5/5, PaymentRegistry 3/3, StreamReceiver 4/4) | PASS |
| 1.6 | Deploy all 3 contracts on Settlement | Addresses logged | StreamSender@0x9983, PaymentRegistry@0xF261, StreamReceiver@0xA5b7 (all Settlement) | PASS |
| 1.8 | createStream + sendTick E2E | Token transfer + events from all 3 contracts | code:0, 25000umin transferred StreamSender→StreamReceiver, PaymentProcessed+PaymentReceived+TickSent events | **PASS** |
| 1.9 | VERIFY-MILESTONE gate | All 5 checks pass | 12/12 tests pass, 3 contracts respond with "umin", .gas-snapshot generated, E2E verified | **PASS** |
| 2.1 | `npm install` + `npm run dev` | Dev server starts | 151 packages installed, Vite serves 200 on :5173 | PASS |
| 2.2 | `npx tsc --noEmit` | Types + config compile | Clean typecheck, all VITE_ env vars typed | PASS |
| 2.3 | `npx tsc --noEmit` | Hooks compile | useStreams, useStreamTick, useOracle all typecheck | PASS |
| 2.4 | Oracle REST + cast call | Price data or graceful degradation | REST returns "Not Implemented", on-chain returns price=0, graceful degradation confirmed | PASS |
| 3.1-3.3 | `npm run build` | Full frontend builds | 487 modules, 470KB JS bundle, all pages + components render | PASS |

| 4.1 | `.env.example` updated | DEV-007 Settlement-only config | Updated with all env vars, secrets blanked | PASS |
| 4.2 | `bash scripts/seed-demo.sh` | Stream created, tx hash logged | Fund tx code:0, CreateStream tx code:0, stream ID verified on-chain | PASS |
| 4.3 | sendTick E2E | Claimable balance increases | code:0, gas_used:472036, claimable=100000 umin on StreamReceiver | PASS |
| 4.3 | Frontend ABI fix | Typecheck + build pass | `npx tsc --noEmit` clean, `npm run build` 487 modules | PASS |
| 4.4 | IBC Denom Fix | N/A | DEV-007: all on Settlement, native umin, no IBC denom transformation | SKIP |

| 5.1 | Bug fix pass | No critical bugs | No bugs found — ABIs already fixed in 4.3, contracts clean | PASS |
| 5.2 | `submission.json` | Valid JSON with all fields | project_name, track, contracts, infrastructure, initia_features, tech_stack | PASS |
| 5.3 | Seed auto-tick | Fund+Create+Tick all code:0 | Enhanced seed script: auto-tick after createStream, 2M gas (DEV-010) | PASS |
| 5.4 | `.gitignore` | Covers all build artifacts | Added contracts/broadcast/, verified .env excluded | PASS |

## Known Risks (for debug)
- Oracle feed inactive on local minitias — ETH/USD returns price=0. PaymentRegistry USD conversion will gracefully return 0. Need Connect oracle sidecar for live prices.
- Relayer key on L1 has 3 INIT — may need topping up for sustained relaying during demo
- All contracts on single chain (Settlement) — cross-chain narrative weakened but functionality intact
- `execute_cosmos` queued msg execution order is sequential but all after EVM — no mid-EVM cosmos state changes possible
- StreamSender must be pre-funded via cosmos bank send before createStream — frontend must handle this 2-step flow
- sendTick requires 2M gas (DEV-010) — wallet/InterwovenKit must set sufficient gas limit
- Deployer key derivation mismatch (DEV-012) — minitiad keyring uses coin_type 118, forge uses coin_type 60. Seed script hardcodes keyring deployer address

## Contract Addresses
| Contract | Network | Address | Tx Hash |
|----------|---------|---------|---------|
| StreamSender | Settlement | 0x998370F9161Dfc5a299aE4EA538BC20fD66D116E | forge script broadcast |
| PaymentRegistry | Settlement | 0xF261B1923e0e548ac76B0dB402300fd725f45be8 | forge script broadcast |
| StreamReceiver | Settlement | 0xA5b71f2899dD6e95c81003D3E7691B844fc513Fb | forge script broadcast |
| HookToIbcTest v4 (debug) | Settlement | 0x73f3601D98CaD568b990F62BaAF3640a765DDCcA | 377B7105...18B |

## Environment Variables Added
| Key | Source Step | Value/Description |
|-----|-----------|-------------------|
| SETTLEMENT_BRIDGE_ID | 0.2 | 1808 |
| SETTLEMENT_L2_IBC_CHANNEL | 0.2 | channel-0 |
| SETTLEMENT_L1_IBC_CHANNEL | 0.2 | channel-3803 |
| SETTLEMENT_L1_CLIENT | 0.2 | 07-tendermint-2957 |
| SETTLEMENT_L1_CONNECTION | 0.2 | connection-2781 |
| STREAM_DENOM | 0.2 | umin (settlement native) |
| ROLLUP_A_BRIDGE_ID | 0.3 | 1809 |
| ROLLUP_A_L2_IBC_CHANNEL | 0.3 | channel-0 |
| ROLLUP_A_L1_IBC_CHANNEL | 0.3 | channel-3805 |
| ROLLUP_B_BRIDGE_ID | 0.3 | 1810 |
| ROLLUP_B_L2_IBC_CHANNEL | 0.3 | channel-0 |
| ROLLUP_B_L1_IBC_CHANNEL | 0.3 | channel-3807 |
| ORACLE_ADDRESS | 0.6 | 0x031ECb63480983FD216D17BB6e1d393f3816b72F |
| ORACLE_PAIR_ID | 0.6 | ETH/USD (fallback — INIT/USD not tracked) |
| STREAM_SENDER_ADDRESS | 1.8 | 0x998370F9161Dfc5a299aE4EA538BC20fD66D116E |
| PAYMENT_REGISTRY_ADDRESS | 1.8 | 0xF261B1923e0e548ac76B0dB402300fd725f45be8 |
| STREAM_RECEIVER_ADDRESS | 1.8 | 0xA5b71f2899dD6e95c81003D3E7691B844fc513Fb |
