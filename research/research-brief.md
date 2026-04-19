# INITIATE: The Initia Hackathon (Season 1) — Research Brief

**Compiled:** 2026-04-07
**Intel Depth:** ID 6 (Standard)
**Sources:** Web Research (17 URLs), Discord (#hackathon channel), Twitter/X (skipped — noted gap)

---

## Overview

| Field | Value |
|-------|-------|
| Name | INITIATE: The Initia Hackathon (Season 1) |
| Organizer | Initia Labs |
| Platform | DoraHacks |
| Deadline | 2026-04-15 23:00 UTC |
| Tracks | DeFi, Gaming & Consumer, AI & Tooling |
| Chain | Initia (Cosmos SDK L1 + optimistic rollup L2s) |
| Native token | INIT ($0.083 USD, $15M market cap, 190M circulating / 1B total) |
| VM Options | MoveVM, EVM (Solidity), WasmVM (Rust/CosmWasm) |
| Hackers registered | 383 |
| BUIDLs submitted | 25 (as of 2026-04-06) |
| Team size limit | Not specified |

### Submission Requirements [A1]

- Deployed as own Initia appchain/rollup with valid rollup chain ID or txn link
- Must use InterwovenKit (`@initia/interwovenkit-react`) for wallet connection
- Must implement at least one native feature: `auto-signing`, `interwoven-bridge`, or `initia-usernames`
- `.initia/submission.json` with 10 required fields (project_name, repo_url, commit_sha, rollup_chain_id, deployed_address, vm, native_feature, core_logic_path, native_feature_frontend_path, demo_video_url)
- `README.md` with hackathon submission section (overview, custom implementation, native feature explanation, local setup steps)
- Demo video: 1-3 minutes, public Loom or YouTube URL
- Projects reproducing Blueprints without meaningful customization are **NOT eligible for prizes** [A1]

---

## Prizes

**BOTTOM LINE:** Total pool is $25K equivalent. Exact per-track breakdown is unclear — the Notion link for reward structure didn't render. Rewards include Mac Minis, cash grants, and Network School trips. [A1]
**EVIDENCE:**
- Official DoraHacks page states $25,000 USD total [A1]
- "Rewards may include: Mac Mini hardware awards, Cash grants, Sponsored trips to the Network School, Ecosystem growth and distribution support" [A1]
- Mid-hackathon MVP Demo Day: "2 strongest teams win Mac Mini hardware awards" before final judging [A1]
- Reward structure detail link: https://initia-xyz.notion.site/INITIATE-Reward-Structure-32c86c34856f80b582d2f188ebdd5dbb (Notion page — failed to render) [A1]
- "All rewards are subject to the quality and eligibility of submissions. Initia reserves the right to revise, reduce, or withhold rewards if entries do not meet the expected standards." [A1]
**CONFIDENCE:** Medium — total confirmed but per-track/per-placement breakdown unknown
**SO WHAT:** Don't optimize for a specific track prize without knowing the split. Focus on overall quality. The quality caveat means weak submissions get nothing.

### Post-Hackathon Rewards (Selected Projects) [A1]

- Entrepreneur in Residence (EIR) onboarding
- Fundraising conversations and investor introductions
- Anvil Credits for first 2-3 months mainnet chain deployment
- Continued technical and ecosystem support
- Help transitioning from developer to long-term builder/founder

**SO WHAT:** The post-hackathon value (EIR, funding intros, Anvil Credits) may exceed the prize money. Build something Initia wants to adopt long-term.

---

## Judging Criteria [A1]

| Criterion | Weight | What Judges Look For | How to Score High |
|-----------|:---:|---|---|
| **Originality & Track Fit** | 20% | Fresh idea, clearly defined within track, distinct POV on the problem | Don't clone a blueprint. Show a novel angle on a real problem. |
| **Technical Execution & Initia Integration** | 30% | Appchain correctly deployed, core logic implemented, Initia-native functionality integrated meaningfully | Deploy your own rollup. Use InterwovenKit deeply. Integrate native features beyond checkbox level. |
| **Product Value & UX** | 20% | Understandable, functional, improved by the Initia experience | Polish the UI. Make the Initia-specific features improve actual UX, not just exist. |
| **Working Demo & Completeness** | 20% | End-to-end working, demo/README sufficient for judges to verify | Working demo > ambitious scope. Judges will test it. Broken = instant fail. |
| **Market Understanding** | 10% | Target user defined, credible GTM, competitive landscape awareness | Name your user. Show you know competitors. Articulate why this on Initia specifically. |

**BOTTOM LINE:** Technical execution (30%) is the heaviest weight. A polished, working demo on your own rollup with deep Initia integration beats a brilliant idea with a broken prototype.
**EVIDENCE:** Official hackathon page scoring criteria [A1]
**CONFIDENCE:** High
**SO WHAT:** Prioritize: (1) working rollup deployment, (2) meaningful InterwovenKit + native feature integration, (3) clean demo. Originality and market are important but won't save a broken build.

---

## Tech Deep Dive

### Architecture [A1] [B2]

**BOTTOM LINE:** Initia is a Cosmos SDK L1 that orchestrates VM-agnostic L2 optimistic rollups ("Minitias") connected via IBC. You deploy your own rollup as your app's dedicated chain.

- **L1**: Initia mainchain (Cosmos SDK, Tendermint/CometBFT consensus)
- **L2 (Minitia)**: Custom rollups — can be MoveVM, EVM, or WasmVM
- **Bridge**: OPinit Stack — optimistic rollup framework with fraud proofs and rollback
- **Interoperability**: IBC (Inter-Blockchain Communication) between L1 ↔ L2 and L2 ↔ L2
- **Performance**: 500ms block times, 10,000+ TPS per rollup [B2]
- **Data Availability**: Celestia DA layer or Initia L1

### VM Selection Guide [A1]

| VM | Language | Best For | Track Recommendation | Setup Friction |
|----|----------|----------|---------------------|----------------|
| **MoveVM** | Move | Complex onchain logic, object-oriented assets | Gaming & Consumer | Low — no extra tools needed |
| **EVM** | Solidity | Existing Ethereum tooling, DeFi composability | DeFi | Medium — Foundry (Forge) recommended |
| **WasmVM** | Rust/CosmWasm | Backend-heavy apps, agents, tooling | AI & Tooling | High — Rust & Cargo required |

### Core Tools [A1]

| Tool | Purpose | Install |
|------|---------|---------|
| `weave` | Appchain initialization, management, relayer | Via Initia agent skills |
| `initiad` | L1 CLI — keys, transactions, queries | Built from source (Go 1.22+) |
| `minitiad` | L2 CLI — rollup-specific operations | Built per VM choice |
| `InterwovenKit` | React wallet connection + transaction handling | `@initia/interwovenkit-react` npm |
| `initia.js` | JavaScript SDK for blockchain interaction | `@initia/initia.js` npm |

### Key Endpoints [A1]

| Resource | URL |
|----------|-----|
| Testnet (L1) | `initiation-2` |
| Testnet Faucet | https://app.testnet.initia.xyz/faucet |
| Local RPC | `http://localhost:26657` |
| Local REST | `http://localhost:1317` |
| Local Indexer | `http://localhost:8080` |
| Docs Index | https://docs.initia.xyz/llms.txt |
| GitHub Org | https://github.com/initia-labs |

### Native Features (must implement at least one) [A1]

| Feature | What It Does | Best For | Implementation Complexity |
|---------|-------------|----------|--------------------------|
| **Auto-signing** | Ghost wallet with authz/feegrant for headless signing | Gaming, high-frequency txns | Medium — InterwovenKit hook, permission scoping |
| **Interwoven Bridge** | Cross-chain asset movement L1 ↔ L2 | DeFi, payments | Medium — OPinit executor + IBC relayer setup |
| **Initia Usernames (.init)** | Human-readable identities replacing hex addresses | Social, P2P payments | Low — namespace lookup integration |

### Blueprints (Reference Implementations) [A1]

| Blueprint | Feature | VM | Use Case |
|-----------|---------|------|----------|
| **BlockForge Game** | Auto-signing | Move | Crafting game — mint shards, craft relics |
| **MiniBank** | Interwoven Bridge | EVM | Cross-chain banking/payments |
| **MemoBoard** | Initia Usernames | Wasm | Social messaging board |

**WARNING:** "Projects that only reproduce a Blueprint without meaningful customization are not eligible for prizes" [A1]

### Appchain Setup Flow (weave init) [A1]

The full setup requires these sequential steps — plan for 1-2 hours first time:

1. **Create project directory** and install AI skill (`npx skills add initia-labs/agent-skills`)
2. **Install CLIs**: weave, initiad, minitiad, jq (via agent skill)
3. **Run `weave init`** — interactive CLI that generates Gas Station account, selects VM, configures rollup
4. **Fund Gas Station** via testnet faucet (currently unstable)
5. **Configure rollup**: chain ID, gas denom (`umin` default), moniker, submission interval (1m), finalization (168h)
6. **Data Availability**: select Initia L1 or Celestia
7. **Enable Oracle Price Feed**: recommended
8. **Generate system keys** and fund system accounts
9. **Set genesis balance**: 10^24 (EVM/Wasm) or 10^19 (Move — u64 overflow risk)
10. **Start OPinit executor** (`weave opinit init executor` → `weave opinit start executor -d`)
11. **Start IBC relayer** (requires Docker Desktop: `weave relayer init` → `weave relayer start -d`)
12. **Import Gas Station key** into both initiad and minitiad keyrings
13. **Verify health**: appchain producing blocks, executor running, relayer connected, Gas Station funded

**After restart**: Docker manages relayer automatically, but must manually restart:
```
weave rollup start -d
weave opinit start executor -d
```

### Contract Development by VM [A1]

**Move (BlockForge Blueprint Pattern):**
- Modules defined with `module <address>::<name> { ... }`
- Key abilities: `key` (storable), `copy`, `drop`
- Build: `minitiad move build --language-version=2.1 --named-addresses <name>=<hex>`
- Deploy: `minitiad move deploy --build --language-version=2.1 --named-addresses <name>=<hex> --from gas-station`
- No separate instantiate step — modules initialize on first interaction
- Gotcha: `BACKWARD_INCOMPATIBLE_MODULE_UPDATE` on redeploy → use fresh account

**EVM (MiniBank Blueprint Pattern):**
- Standard Solidity development with Foundry (Forge)
- Address format conversion between Cosmos (init1...) and EVM (0x...)
- ERC20 creation via factory or custom
- IBC hooks for cross-chain calls
- Connect Oracle integration for price feeds

**Wasm (MemoBoard Blueprint Pattern):**
- Rust + CosmWasm contracts
- Requires Rust & Cargo installed
- IBC hooks available for cross-chain messaging
- Highest setup friction of the three VMs

### Frontend Integration Pattern [A1]

```
Stack: Vite + React + InterwovenKit + initia.js + TanStack Query + wagmi
```

Required wrapper hierarchy:
1. `WagmiProvider` (config)
2. `QueryClientProvider` (TanStack)
3. `InterwovenKitProvider` (chain config, enableAutoSign)

Key hooks:
- `useInterwovenKit()` — wallet state, autoSign object
- `autoSign.enable(chainId, { permissions: [...] })` — enable ghost wallet
- `autoSign.disable(chainId)` — revoke grants
- `requestTxSync(...)` — send transactions with optional auto-signing

Environment variables needed: `VITE_APPCHAIN_ID`, `VITE_INITIA_RPC_URL`, `VITE_INITIA_REST_URL`, `VITE_MODULE_ADDRESS`, `VITE_NATIVE_DENOM`, `VITE_NATIVE_SYMBOL`

### Known Technical Issues (as of 2026-04-06) [C3]

1. **Testnet faucet intermittently down** — manuel.init acknowledged, testnet upgrade in progress
2. **Registry API (registry.testnet.initia.xyz) was returning 404** on /chains — InterwovenKit depends on it
3. **Move genesis balance must stay ≤ 10^19** to avoid u64 overflow [A1]
4. **`BACKWARD_INCOMPATIBLE_MODULE_UPDATE`** error on Move redeploy — must use fresh deployer account [A1]
5. **Inventory query lag** — wait ~2 seconds after transaction before querying state [A1]
6. **Local rollup only works on deployer's machine** — SuyashAlphaC deployed contracts on minievm testnet for judge verification [C3]

### AI Track Specific Guidance [A1]

**BOTTOM LINE:** Run inference offchain, use appchain for on-chain guarantees. You do NOT need to run model inference onchain.

- **Offchain AI**: Generate content, recommendations, copilots, agents, classification, summarization
- **Onchain Appchain**: Ownership/state, rewards/payments, access/reputation, marketplace/escrow coordination
- **Allowed AI providers**: OpenAI, Anthropic (Claude), Google Gemini
- **Security**: Store API keys in `.env`, never commit to GitHub or expose in demo
- **Demo flexibility**: "Mocked, cached, or pre-generated AI outputs" allowed if clearly disclosed
- **Judges prioritize**: Product, appchain integration, and UX over whether inference is truly hosted onchain

---

## Ecosystem Products [A1] [B2]

| Product | Purpose | Integration Depth | Docs URL |
|---------|---------|:---:|---|
| InterwovenKit | Wallet connection + txn flows (REQUIRED) | Deep — mandatory | https://docs.initia.xyz/interwovenkit |
| OPinit Stack | Optimistic rollup framework | Deep — runs your chain | https://github.com/initia-labs/OPinit |
| IBC Relayer | Cross-chain messaging (Docker) | Medium — bridge setup | Via `weave relayer init` |
| InitiaDEX | Token swaps, liquidity | Optional | https://initia.xyz |
| Oracle Price Feed | L1 price feeds for L2 | Optional — enable in weave init | Via weave CLI |
| Initia Usernames | .init human-readable names | Native feature option | https://docs.initia.xyz |
| InitiaScan | Block explorer | Reference only | https://scan.initia.xyz |

### Existing Ecosystem Projects [B2]

- **DeFi**: Inertia (LRT/lending), Contro (fair trading), Cabal (income generation)
- **Gaming**: Kamigotchi (on-chain RPG), InfinityGround (AI + blockchain gaming)
- **SocialFi**: Civitia (gamified SocialFi), Zaar (NFT marketplace)
- **Analytics**: Minity (asset tracking)

**SO WHAT:** The ecosystem is early-stage. There's room to build something that becomes a flagship app. Judges likely value projects that could become real ecosystem pillars.

---

## Competitor Landscape

### Competitor Registry

| # | Project | Track | Threat | Tech | Description | Source |
|---|---------|-------|:---:|---|---|---|
| 1 | SocialYield | DeFi | **HIGH** | EVM, MEV, batch auctions | Eliminates front-running, redistributes MEV as yield to .init holders | [A1] |
| 2 | AppSwap | DeFi | **HIGH** | AMM, cross-rollup routing | Unified DEX across Initia rollups | [A1] |
| 3 | IntentOS | AI & Tooling | **HIGH** | AI, NLP, DeFi | Natural language → on-chain DeFi strategies | [A1] |
| 4 | SwarmFi | DeFi | **HIGH** | CosmWasm, swarm AI, oracles | Multi-agent stigmergic consensus for oracle data, prediction markets | [A1] |
| 5 | InitPage | AI & Tooling | **HIGH** | AI, commerce, Shopify | AI-native commerce for humans and agents on appchain | [A1] |
| 6 | Caleb | AI & Tooling | MEDIUM | AI agents, verification | Verifiable AI agents handling money. Live MVP | [A1]+[C3] |
| 7 | SIGIL | AI & Tooling | MEDIUM | AI marketplace | Deploy/rent/compose autonomous agents | [A1] |
| 8 | InitCode | AI & Tooling | MEDIUM | Browser IDE | Browser-based contract editor + deploy | [A1] |
| 9 | Sinergy | AI & Tooling | MEDIUM | ZK, dark pools | Private AI agent-driven appchain for traders | [A1] |
| 10 | Carnage of Gods | Gaming | MEDIUM | CosmWasm, PvP | On-chain mythological battle game | [A1] |
| 11 | Initia Brawlers | Gaming | MEDIUM | Move, pixel art | PvP autobattler with on-chain store | [A1] |
| 12 | Gam3Hub | Gaming | MEDIUM | Provably fair | Gaming platform with in-house games | [A1] |
| 13 | Initpay | DeFi | MEDIUM | MiniEVM, multi-chain | Crypto payroll with 7 features | [A1] |
| 14 | Smart Yield | DeFi | MEDIUM | AI, DeFi vault | AI-driven yield vault, auto-rebalances | [A1] |
| 15 | InitiaAI Yield Agent | AI & Tooling | MEDIUM | Claude, DeFi | AI agent for yield optimization with auto-signing | [A1] |
| 16 | Initia-B2B-Escrow | DeFi | MEDIUM | KYC/AML, RWA | B2B trade escrow replacing Letters of Credit | [A1] |
| 17 | AgentCommerce | AI & Tooling | LOW | AI agents | Hire AI services on-chain | [A1] |
| 18 | Stream-Pay | Gaming & Consumer | LOW | Tipping, walletless | One-tap tipping for live streams | [A1] |
| 19 | initiaLink | Gaming & Consumer | LOW | Move, .init names | On-chain link-in-bio | [A1] |
| 20 | Hunch | Gaming & Consumer | LOW | Betting | Fast betting markets for mobile | [A1] |
| 21 | Impulsive Markets | Gaming & Consumer | LOW | Prediction markets | AI-assisted resolution prediction markets | [A1] |
| 22 | Arcade Chess Arena | Gaming & Consumer | LOW | Chess, GameFi | Competitive chess with capture duels | [A1] |
| 23 | InitBet | Gaming & Consumer | LOW | GameFi | Betting/GameFi (minimal detail) | [A1] |
| 24 | Pulse | AI & Tooling | LOW | AI analytics | AI reads ecosystem, writes on-chain | [A1] |
| 25 | giuliano (unnamed) | AI & Tooling | LOW | AI security | Web3 security for AI agents — no MVP, late joiner | [C3] |

### Competition Density Map

| Track | Est. Teams | Activity Level | Density |
|-------|:---:|---|:---:|
| AI & Tooling | 10+ | High — most submissions | **HIGH** |
| DeFi | 7+ | High — strongest technical builders | **MEDIUM** |
| Gaming & Consumer | 8+ | Medium — mostly casual/early | **MEDIUM** |

### Saturated Sub-Niches

- **AI + DeFi yield agents**: IntentOS, Smart Yield, InitiaAI Yield Agent — 3 projects doing essentially the same thing [A1]
- **AI agent marketplace/commerce**: InitPage, AgentCommerce, SIGIL — overlapping concepts [A1]
- **Betting/prediction markets**: Hunch, InitBet, Impulsive Markets — 3 projects [A1]

**BOTTOM LINE:** AI & Tooling is the most crowded but weakest in quality. DeFi has fewer but stronger builders. Gaming has the weakest competition overall.
**CONFIDENCE:** High — based on all 25 DoraHacks submissions + Discord activity
**SO WHAT:** Gaming track offers the best risk-adjusted opportunity — lower density, weaker competition, and gaming is highlighted as a priority in Initia's ecosystem direction. DeFi is viable if you can differentiate technically from SocialYield/AppSwap.

---

## Past Editions Analysis

**BOTTOM LINE:** This is Season 1 — no past editions exist. No historical winner data to analyze.
**EVIDENCE:** DoraHacks page explicitly states "INITIATE: The Initia Hackathon (Season 1)" [A1]
**CONFIDENCE:** High
**SO WHAT:** No established "what wins" pattern to follow or avoid. Judges have no precedent. First-mover advantage — whatever wins here sets the template.

### Cross-Hackathon Winner Patterns (General Intelligence)

Since no Initia-specific winner data exists, these patterns from ETHGlobal, Chainlink, and Solana hackathons apply:

| Pattern | Relevance to INITIATE | Priority |
|---------|----------------------|----------|
| Limit to 3 features max | Very high — judges evaluate 25+ projects quickly | P0 |
| Working demo beats ambitious scope | Very high — "Working Demo & Completeness" is 20% of score | P0 |
| Deep sponsor tech integration > bolted-on | Very high — "Technical Execution & Initia Integration" is 30% | P0 |
| Target less popular bounties/tracks | High — Gaming track has weakest competition | P1 |
| Clean README with screenshots | High — judges skim before demoing | P1 |
| Pre-seeded demo data | Medium — makes demo feel real and polished | P2 |
| Study the judges | Low — no judge names announced yet | P3 |

### What Likely Wins This Hackathon

Based on scoring weights (Technical 30%, Demo 20%, UX 20%, Originality 20%, Market 10%):

1. **A project with its own working rollup** that judges can verify via chain ID or txn link
2. **Deep InterwovenKit integration** where the native feature actually improves UX (not checkbox)
3. **Polished, end-to-end working demo** — the 20% demo weight rewards completeness over ambition
4. **Original concept** that isn't a blueprint clone or saturated sub-niche
5. **Clear articulation** of who uses it and why on Initia specifically

---

## Broader Market Context

**BOTTOM LINE:** Initia is a well-funded but early-stage ecosystem with low token price and modest TVL, positioned in the Cosmos/modular blockchain space. The appchain thesis is gaining traction but Initia's ecosystem is still nascent.

**EVIDENCE:**
- Initia raised $7.5M seed (TechCrunch, Feb 2024) [A1]
- Mainnet launched April 24, 2025 [A1]
- INIT price: $0.083, market cap $15M, FDV ~$83M [B2]
- Founded by Stan Liu and Ezaan Mangalji (ex-Terraform Labs) [B2]
- Cosmos ecosystem facing headwinds — Leap Wallet shut down, Intergaze NFT platform winding down (April 2026) [C3]
- Next token unlock: April 24, 2026 — 82.94M INIT ($6.75M, 8.3% of supply) [B2]
- Partnerships: Interchain Foundation, Celestia, All in Bits [B2]

**CONFIDENCE:** Medium — market data current but ecosystem health indicators are mixed
**SO WHAT:** Initia is betting on appchain adoption. A hackathon winner that becomes a real ecosystem project is extremely valuable to them — they need success stories. The EIR/funding post-hackathon path may be more valuable than the $25K prize.

### Market Narratives Relevant to Track Selection

| Narrative | Strength (2026) | Relevant Track | Opportunity |
|-----------|:---:|---|---|
| AI agents managing on-chain assets | Very Strong | AI & Tooling | Saturated in this hackathon — 3+ yield agents. Need novel angle. |
| Appchain-specific gaming | Strong | Gaming & Consumer | Underexplored in this hackathon. Auto-signing enables invisible-infra gaming UX. |
| Cross-chain DeFi / unified liquidity | Strong | DeFi | AppSwap already targets this. Hard to differentiate. |
| Creator economy / social on-chain | Medium | Gaming & Consumer | initiaLink exists but basic. Room for richer social features with .init names. |
| RWA / institutional DeFi | Medium | DeFi | Initia-B2B-Escrow exists. Niche but credible. |
| AI security / guardrails for Web3 | Emerging | AI & Tooling | giuliano attempting this but no MVP. Could be high-novelty if executed. |
| Privacy / ZK on appchains | Weak on Initia | AI & Tooling | Sinergy targets this but ZK on Cosmos is hard. High risk. |

### Initia-Specific Ecosystem Signals

- **INIT token at $0.083** with $15M market cap — significantly down from $900M FDV at launch [B2]. Ecosystem needs catalysts.
- **Token unlock April 24** (82.94M INIT, 8.3% of supply) — potential price pressure within days of hackathon results [B2]
- **Cosmos ecosystem headwinds** — Leap Wallet shutdown, Intergaze winding down [C3]. Initia needs to prove differentiation from broader Cosmos struggles.
- **Initia has AI agent skills infrastructure** (`npx skills add initia-labs/agent-skills`) — they're actively investing in AI-assisted development [A1]
- **Docs MCP available** — AI agents can connect directly to Initia documentation via Model Context Protocol [A1]

### Time Constraint Analysis

| Factor | Impact | Mitigation |
|--------|--------|------------|
| 8 days remaining (as of April 7) | Must ship end-to-end in ~7 working days | Use a blueprint as starting point, customize heavily |
| MVP Demo Day already passed | No Mac Mini hardware award opportunity | Focus entirely on final submission quality |
| Testnet instability | Could block development | Build locally with `weave init`, deploy to testnet later |
| Solo builder (assumed) | Scope must be realistic for 1 person | 3 features max. Pick the simplest VM for your skillset. |
| Demo video required | Need 1-3 min polished video | Plan demo script early, record after build is stable |

---

## Key Links & Resources

| Resource | URL |
|----------|-----|
| **Official Hackathon Page** | https://dorahacks.io/hackathon/initiate/detail |
| **Hackathon Docs** | https://docs.initia.xyz/hackathon |
| **Get Started (Setup Guide)** | https://docs.initia.xyz/hackathon/get-started |
| **Builder Guide** | https://docs.initia.xyz/hackathon/builder-guide |
| **Submission Requirements** | https://docs.initia.xyz/hackathon/submission-requirements |
| **AI Track Guidance** | https://docs.initia.xyz/hackathon/ai-track-guidance |
| **BlockForge Blueprint (Move)** | https://docs.initia.xyz/hackathon/examples/move-game |
| **MiniBank Blueprint (EVM)** | https://docs.initia.xyz/hackathon/examples/evm-bank |
| **MemoBoard Blueprint (Wasm)** | https://docs.initia.xyz/hackathon/examples/wasm-social |
| **Reward Structure (Notion)** | https://initia-xyz.notion.site/INITIATE-Reward-Structure-32c86c34856f80b582d2f188ebdd5dbb |
| **Docs Full Index** | https://docs.initia.xyz/llms.txt |
| **Testnet Faucet** | https://app.testnet.initia.xyz/faucet |
| **InterwovenKit Docs** | https://docs.initia.xyz/interwovenkit |
| **Auto-signing Usage** | https://docs.initia.xyz/interwovenkit/features/autosign/usage |
| **Initia.js SDK** | https://docs.initia.xyz/developers/developer-guides/tools/sdks/initia-js |
| **AI Agent Skills** | https://docs.initia.xyz/ai/agent-skills |
| **Docs MCP (AI context)** | https://docs.initia.xyz/ai/docs-mcp |
| **GitHub: initia** | https://github.com/initia-labs/initia |
| **GitHub: minimove** | https://github.com/initia-labs/minimove |
| **GitHub: minievm** | https://github.com/initia-labs/minievm |
| **GitHub: OPinit** | https://github.com/initia-labs/OPinit |
| **NPM: react-wallet-widget** | https://www.npmjs.com/package/@initia/react-wallet-widget |
| **NPM: initia.js** | https://www.npmjs.com/package/@initia/initia.js |
| **Discord** | https://discord.gg/initia |
| **Twitter/X** | https://x.com/initia |
| **Medium** | https://medium.com/@initialabs |
| **Ecosystem Page** | https://initia.xyz/ecosystem |
| **CoinMarketCap** | https://coinmarketcap.com/currencies/initia/ |

---

## Social Intel

Social intelligence gathered from Discord #hackathon channel (2026-04-02 through 2026-04-07). Twitter/X review skipped — noted as coverage gap.

### Strategic Implications from Social Intel

**BOTTOM LINE:** The field is weaker than the 25-project count suggests. Most builders are stuck on infrastructure, many are solo, and few have working MVPs. A polished submission with working rollup will stand out significantly.
**EVIDENCE:** Discord shows multiple builders blocked by faucet/testnet issues [C3]. Only 1 live MVP (Caleb) visible. Multiple licensing/deadline confusion signals suggest first-time hackathon participants. [C3]
**CONFIDENCE:** Medium — Discord sample may not represent all 383 registered hackers
**SO WHAT:** Execution quality matters more than idea novelty here. Ship something that works end-to-end and you're likely in the top quartile.

### Key Discord Findings [C3]

**Infrastructure Issues:**
- Testnet registry API was down (404 on /chains) — InterwovenKit couldn't mount [C3]
- Faucet not working for multiple days — several builders blocked [C3]
- Testnet undergoing upgrade — manuel.init acknowledged delays [C3]

**Builder Confusion:**
- Common misunderstanding: deploying on L1 testnet vs spinning up own rollup — **confirmed by manuel.init: you MUST spin up your own rollup** [B2]
- Local-only rollup problem — one builder deployed contracts on public minievm testnet for judge verification [C3]
- Licensing requirements never answered despite multiple asks [C3]
- MVP Demo Day deadline confusion (timezone, exact time) [C3]

**Organizer Signals:**
- MVP Demo Day deadline was April 5, 2026 (already passed) — Mac Mini hardware awards for top 2 [B2]
- su.init confirmed: can skip rollup for MVP, submit demo now, deploy chain later [B2]
- Active mods: manuel.init, su.init (Militia Generals) [C3]
- 2,469 members online in Discord [C3]

**Competitor Activity:**
- ~10-12 active builders visible in channel
- Most struggling with infrastructure, not building features
- One live MVP (Caleb at caleb.sandpark.co) — rest are WIP
- Multiple submissions are individuals, not teams

---

## Strategic Opportunity Assessment

**BOTTOM LINE:** The highest expected-value play is **Gaming & Consumer track with MoveVM + auto-signing**, targeting the gap between polished existing games and the weak competition field.

### Track-by-Track Opportunity Ranking

| Rank | Track | Why | Risk | Best VM |
|------|-------|-----|------|---------|
| 1 | **Gaming & Consumer** | Weakest competition, gaming aligns with Initia's MoveVM strength, auto-signing enables invisible-infra UX that judges will love | Medium — need to ship a fun, playable game | MoveVM |
| 2 | **DeFi** | Strong technical alignment with EVM, fewer but stronger competitors | High — SocialYield and AppSwap are polished | EVM |
| 3 | **AI & Tooling** | Most crowded, 3+ yield agents already, quality is uneven | Very High — need extreme differentiation | WasmVM |

### What's Missing in the Current Field

| Gap | Track | Why It's Valuable |
|-----|-------|-------------------|
| No real-time multiplayer game | Gaming | Would showcase Initia's 500ms block times + auto-signing |
| No social/community app beyond initiaLink | Consumer | .init usernames are underutilized as social identity |
| No creator tools / content monetization | Consumer | Creator economy narrative is strong, no one building it |
| No cross-rollup application (uses IBC between rollups) | DeFi | Would demonstrate Initia's core "interwoven" thesis |
| No developer tooling beyond InitCode | AI & Tooling | DevEx tools score high with organizer judges |

### Submission Checklist (Pre-Build)

Before building, confirm these will be in place by deadline:
- [ ] Own rollup deployed with unique chain ID via `weave init`
- [ ] InterwovenKit integrated for wallet connection
- [ ] At least one native feature (auto-signing / bridge / usernames)
- [ ] `.initia/submission.json` with all 10 fields
- [ ] `README.md` with required sections
- [ ] 1-3 minute demo video on YouTube/Loom
- [ ] GitHub repo with code at specified commit SHA
- [ ] Custom logic beyond blueprint — meaningful differentiation

---

## Kill List

Ideas matching ANY of these categories are dead on arrival:

### 1. Saturated
- **AI yield optimizer / DeFi agent** — 3+ projects already (IntentOS, Smart Yield, InitiaAI Yield Agent). This exact concept is overdone.
- **AI agent marketplace** — InitPage, AgentCommerce, SIGIL all overlap here
- **Betting / prediction markets** — Hunch, InitBet, Impulsive Markets. Three already.
- **Generic DEX / swap protocol** — AppSwap already has clear positioning as unified cross-rollup DEX

### 2. Broken Dependencies
- **Anything requiring stable testnet faucet right now** — faucet was down as of April 4-6, testnet upgrade in progress [C3]
- **Projects depending on registry.testnet.initia.xyz** — was returning 404 [C3]
- **On-chain AI inference** — Initia's own AI guidance says "you do NOT need to run model inference onchain" [A1]. Don't fight the architecture.

### 3. Already Built
- **Link-in-bio / social profile** — initiaLink already does this with .init names
- **Cross-chain payroll** — Initpay covers this with 7 features
- **B2B escrow** — Initia-B2B-Escrow exists
- **Browser-based contract IDE** — InitCode already submitted
- **Pixel art battler / PvP autobattler** — Initia Brawlers exists

### 4. Zero Alignment
- **Pure AI chatbot with no on-chain component** — requires appchain deployment, judging weights favor Initia integration (30%)
- **Non-Initia chain deployment** — must be own Initia rollup, not Ethereum/Solana/etc.
- **Backend-only project with no frontend** — InterwovenKit is mandatory, judges need working demo (20%)
- **Blueprint clone without customization** — explicitly ineligible for prizes [A1]
