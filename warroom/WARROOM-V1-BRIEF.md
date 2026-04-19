# WAR ROOM V1 — INITIATE: The Initia Hackathon (Season 1) DELIBERATION BRIEF
**Date:** 2026-04-07
**Objective:** Pick THE ONE idea for INITIATE that is BOTH the most winnable AND solves a significant real problem.

---

## NON-NEGOTIABLE RULES (from the builder)

### CRITICAL CONCERNS (Must satisfy — idea eliminated if violated)
1. **[C] Time NOT a constraint.** Claude Code = 10x dev speed. Do NOT penalize ideas for complexity.
3. **[C] Uniqueness is non-negotiable.** If competitors exist for the same idea, SERIOUS strike. Zero competitors preferred.
5. **[C] "Does this help real humans?" test.** Every idea must pass. Name real people whose lives improve.
8. **[C] Cumulative corrections.** Nothing dropped between versions.
9. **[C] Must solve a SIGNIFICANT, real problem.** Builder must BELIEVE in it.
13. **[C] Must serve actual target users who exist TODAY.**

### IMPORTANT CONCERNS (Should satisfy — score penalty if violated)
2. **[I] Everything is devnet/testnet.** Mocks are fine. Judge on concept + demo, not production infra.
6. **[I] Read ALL research data.** Cite Discord intel, web research, competitor analysis, winning patterns.
7. **[I] Take your time, be extensive.** 200-400 word proposals with citations. 800+ lines total.
10. **[I] Focused product, BROAD problem.** Niche scope fine. Niche AUDIENCE is NOT. Problem should affect MILLIONS.
11. **[I] Winning AND real impact are not mutually exclusive.**
14. **[I] Demo must feel like the real product.** Pre-seed with realistic data.
15. **[I] AI/Agents should be considered.** AI track exists. Consider AI as a tool, don't force it.
16. **[I] Cross-chain capability valued.** IBC/interwoven bridge is a native feature requirement.

### ADVISORY CONCERNS
4. **[A] Fresh ideas allowed.** Not limited to predefined lists.
12. **[A] Reframing is on the table.** Same tech can serve different problems.

---

## HACKATHON FACTS
- **Hackathon:** INITIATE: The Initia Hackathon (Season 1)
- **Deadline:** 2026-04-15 23:00 UTC (8 days remaining)
- **Prize:** $25,000 USD (Mac Minis, cash grants, Network School trips, ecosystem support)
- **Tracks:** DeFi, Gaming & Consumer, AI & Tooling
- **Platform:** Initia (Cosmos SDK L1 + VM-agnostic L2 optimistic rollups)
- **Submissions:** 25 BUIDLs, 383 hackers registered
- **Demo Format:** Recorded video, 1-3 minutes

## JUDGING CRITERIA
| Criterion | Weight | What It Means |
|-----------|:---:|---|
| Originality & Track Fit | 20% | Fresh idea, distinct POV, clearly in a track |
| Technical Execution & Initia Integration | 30% | Rollup deployed, core logic works, native features used meaningfully |
| Product Value & UX | 20% | Understandable, functional, Initia features improve UX |
| Working Demo & Completeness | 20% | End-to-end working, judges can verify |
| Market Understanding | 10% | Target user named, credible GTM, knows competitors |

## THE BUILDER
- Solo developer with Claude Code (10x multiplier)
- Full-stack capable (frontend + smart contracts)
- 8 days remaining to deadline
- Access to MoveVM, EVM, WasmVM toolchains

---

## INITIA CAPABILITIES
- **Architecture:** Cosmos SDK L1 → VM-agnostic L2 rollups → connected via IBC
- **VMs:** MoveVM (gaming, complex objects), EVM (DeFi, Ethereum tooling), WasmVM (AI/backend)
- **Performance:** 500ms block times, 10,000+ TPS per rollup
- **Native Features:** Auto-signing (ghost wallet), Interwoven Bridge (L1↔L2), Initia Usernames (.init)
- **Key Tools:** weave CLI, InterwovenKit (@initia/interwovenkit-react), initia.js, Oracle Price Feed
- **Move Objects:** Structs with key+store abilities = true on-chain asset ownership
- **Known Issues:** Faucet intermittent, registry API was 404, Move u64 overflow at 10^19+, redeploy errors

---

## KNOWN COMPETITORS (25 submissions)

### HIGH Threat
| Project | Track | Description |
|---------|-------|-------------|
| SocialYield | DeFi | MEV redistribution as yield to .init holders |
| AppSwap | DeFi | Unified DEX across Initia rollups |
| IntentOS | AI | NLP → on-chain DeFi strategies |
| SwarmFi | DeFi | Multi-agent stigmergic oracle consensus |
| InitPage | AI | AI-native commerce for humans and agents |

### MEDIUM Threat
Caleb (AI agents), SIGIL (AI marketplace), InitCode (browser IDE), Sinergy (ZK dark pools), Carnage of Gods (PvP game), Initia Brawlers (pixel autobattler), Gam3Hub (gaming platform), Initpay (payroll), Smart Yield (AI vault), InitiaAI Yield Agent (AI yield), Initia-B2B-Escrow (trade escrow)

### LOW Threat
AgentCommerce, Stream-Pay, initiaLink, Hunch, Impulsive Markets, Arcade Chess Arena, InitBet, Pulse, giuliano

### Competition Density
| Track | Teams | Density |
|-------|:---:|:---:|
| AI & Tooling | 10+ | HIGH |
| DeFi | 7+ | MEDIUM |
| Gaming & Consumer | 8+ | MEDIUM (weakest quality) |

### Saturated Sub-Niches (AVOID)
- AI yield agents (3 projects)
- AI agent marketplace (3 projects)
- Betting/prediction markets (3 projects)

---

## WHAT PAST WINNERS HAVE IN COMMON
- Limit to 3 features max
- Working demo beats ambitious scope
- Deep sponsor tech integration (not bolted-on)
- Target less popular tracks
- Clean README with screenshots
- Gaming wins disproportionately at ETHGlobal (4/10 top spots)
- Solo devs can and do win

---

## YOUR TASK
You are 4 expert agents debating which idea to build for INITIATE.

### AGENT ROLES

**INIT — Integration Maximalist** (→ Technical Execution 30%)
Lens: "Does this deeply use Initia's tech stack?"
Attacks: Superficial integrations, wrong VM, missing native features

**PULSE — Product & UX Evaluator** (→ Product Value & UX 20%)
Lens: "Would real users actually enjoy using this?"
Attacks: Abstract users, no clear flow, features nobody asked for

**STAGE — Demo Impact Specialist** (→ Working Demo 20%)
Lens: "What do judges SEE in the 3-minute demo?"
Attacks: Loading spinners, abstract demos, fake-looking pre-seeded data

**WILD — Contrarian X-Factor** (→ Originality 20% + Market 10%)
Lens: "What would NOBODY else build?"
Attacks: Clone ideas, crowded categories, predictable approaches

### IDEAS TO EVALUATE (8 finalists from Phase 0.5)
1. **OracleHunter** (23/25) — Oracle-driven dungeon crawler
2. **MoveArena** (21/25) — Real-time PvP arena
3. **ChainCraft** (21/25) — On-chain crafting game
4. **InitForge** (21/25) — Roguelike with permadeath
5. **InitQuest** (19/25) — Gamified onboarding RPG (uses all 3 native features)
6. **PriceDuel** (19/25) — Oracle price prediction dueling
7. **InitStudio** (18/25) — Creator economy platform
8. **DungeonMint** (22/25) — Oracle dungeon + crafting hybrid

Full idea descriptions available in research/ideas.md.
