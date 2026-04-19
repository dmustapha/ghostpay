# WINNER-BRIEF — INITIATE: The Initia Hackathon (Season 1)
**Idea:** GhostPay
**Track:** DeFi
**Warroom Version:** V4
**Date:** 2026-04-07

---

## Chosen Idea
Cross-rollup payment streaming infrastructure on Initia. A dedicated settlement Minitia (own rollup) enables continuous money flows between any two rollups via IBC, powered by auto-signing ghost wallets. Payers set a stream (amount + duration + recipient), and a ghost wallet fires micro-transactions every N blocks, routed through the GhostPay settlement rollup to the receiver on any other rollup.

## Problem Statement
**Crypto has no concept of continuous money movement across chains.**

Three layers:
1. **All-or-nothing payments** — Every crypto transaction is a lump sum. Send $100 or $0. No partial, proportional, or time-based payments. Same model as writing a check in 1950.
2. **Cross-rollup payments are manual and painful** — Paying someone on a different rollup means: bridge tokens → wait for confirmation → swap if needed → send. Every single time. No recurring or automated cross-chain payments exist.
3. **No programmable money flows** — Can't split revenue between 3 contributors on 3 rollups in real-time. Can't stream protocol fees cross-chain. Can't do proportional payments. Every payment requires a human clicking "send."

**Use cases:** Subscriptions (cancel anytime, pay only for usage), payroll (salary streams every block), revenue splitting (cofounders on different rollups), protocol-to-protocol fee flows, DCA streaming, conditional payments.

## Why It Won
| Criterion | Weight | Score | Rationale |
|-----------|:------:|:-----:|-----------|
| Technical Execution & Integration | 30% | 9/10 | Own Minitia + IBC + auto-signing + oracle + InterwovenKit — 5 native features, all load-bearing |
| Originality & Track Fit | 20% | 8/10 | Cross-rollup streaming doesn't exist anywhere — not on Initia, not on any chain |
| Product Value & UX | 20% | 7/10 | Clean streaming visualization, intuitive concept, but utility is forward-looking |
| Working Demo & Completeness | 20% | 8/10 | Two-rollup + settlement rollup demo impressive for solo dev |
| Market Understanding | 10% | 7/10 | Infrastructure bet on multi-rollup future — clear positioning vs Initpay |
**FINAL weighted score: 8.0/10**

## Key Deliberation Arguments (Why This Won)

1. **Integration depth is unmatched.** Every Initia-native feature is load-bearing — remove any one and the product breaks. Own Minitia (deep), IBC bridge (deep), auto-signing (medium), oracle (medium), InterwovenKit (mandatory). This mirrors the builder's Chainlink win strategy: deep integration > feature count.

2. **Structurally impossible without Initia.** Cross-rollup payment streaming requires multi-rollup IBC architecture. Can't port this to Ethereum, Solana, or any single-chain. The product IS the Initia architecture.

3. **Zero competitors in this exact space.** Superfluid/Sablier stream on single chains. Initpay does single-rollup batch payroll. Nobody does cross-rollup streaming via IBC. Verified across research-brief competitor landscape (25 competitors mapped).

## Top Risks + Mitigations
| # | Risk | Severity | Mitigation |
|---|------|:--------:|------------|
| 1 | IBC relayer setup eats 2+ days — builder has zero Cosmos experience | CRITICAL | Day 1 morning task. Use Initia default relayer config. If blocked by EOD 1, fall back to L1 settlement |
| 2 | Minitia deployment harder than docs suggest (faucet issues noted in research) | CRITICAL | Day 1 task alongside relayer. If blocked, L1-only settlement is fallback (weaker but shippable) |
| 3 | Auto-signing permission scoping underdocumented | HIGH | Test with minimal authz grants first, expand only as needed |
| 4 | Solo dev building 3-rollup system in 8 days — zero margin for error | HIGH | Feature-freeze Day 6. Demo prep Days 7-8. Day 1 go/no-go on full architecture |
| 5 | "No real users today" judge objection | MEDIUM | Frame as infrastructure for multi-rollup future |

## Non-Negotiables (Must Be In Build)
- Settlement Minitia deployed via weave CLI (own rollup)
- Ghost wallet creation with authz + feegrant grants
- Single payment stream working: Rollup A → Settlement Minitia → Rollup B via IBC
- Real-time streaming visualization with bridge-crossing animation as centerpiece
- Oracle USD conversion display on streams
- InterwovenKit wallet connection + chain switching between rollups

## Explicit Out-of-Scope
- Mobile app or responsive mobile layout
- Multi-token support beyond testnet tokens
- Production security audit or formal verification
- Creator economy marketplace features (tiers, content gating)
- .init username resolution (nice-to-have only)
- Stream modification/pause mid-stream (V2 feature)

## Minority Dissent (Unresolved Concerns)
- **Product utility is forward-looking.** No real cross-rollup payment demand exists today on Initia's nascent rollup ecosystem. Mitigated by infrastructure framing but remains the strongest counterargument.
- **Cosmos/IBC learning curve.** Builder's entire experience is EVM. The architecture depends on tech the builder has never shipped. Day 1 go/no-go gate is the mitigation.

## Architecture Notes for Forge

### Tech Stack
- **VM:** EVM (builder's strength, DeFi track recommendation from config)
- **Frontend:** Vite + React + InterwovenKit + TanStack Query
- **Contracts:** Solidity on EVM Minitia — payment registry, stream state, ghost wallet management
- **Infrastructure:** weave CLI for Minitia deploy, IBC relayer for cross-rollup, initiad for L1

### Demo Script Concept
Split-screen: Rollup A (left) and Rollup B (right). User starts a payment stream. Money visually leaves Rollup A, animated crossing the bridge in center, arrives on Rollup B in real-time. Revenue counter climbs on receiver side. Then second stream from different rollup — both converging on same receiver. Bridge crossing is the visual centerpiece.

### Pitch Order
1. **Problem first** — "Crypto has no continuous money movement. Everything is lump sums, manual, single-chain."
2. **The twist** — "Initia has multiple rollups. Paying across them is bridge → wait → swap → send. Every time."
3. **Solution** — "GhostPay turns payments into streams that flow across rollups automatically."
4. **Demo** — Show the stream crossing the bridge in real-time.
5. **Scale** — "Payment rails for Initia's 100-rollup future."

### Day 1 Go/No-Go Gate
Morning: Deploy Minitia + test IBC relayer. Both work by EOD 1 → full 3-rollup architecture. Either blocked → fall back to L1-only settlement (same concept, less integration depth, still shippable).

### Fallback Architecture (if Day 1 fails)
Payer (L1) → auto-signing ghost wallet → Oracle conversion → Receiver (L1). Same streaming concept, single-chain. Loses the cross-rollup USP but still demonstrates auto-signing + oracle + InterwovenKit. Score drops from ~8.0 to ~6.5.
