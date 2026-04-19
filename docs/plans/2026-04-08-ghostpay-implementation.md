# GhostPay Implementation Plan

**Project:** GhostPay — Cross-rollup payment streaming infrastructure
**Hackathon:** INITIATE: The Initia Hackathon (Season 1)
**Deadline:** 2026-04-15 (7 days remaining, 6 build days)
**Stack:** Solidity (Foundry) + TypeScript (Vite/React) + InterwovenKit + TanStack Query
**Architecture Doc:** `ARCHITECTURE.md` (THE source of truth for all code — 3113 lines, 35 files)
**PRD:** `PRD.md` (534 lines, 14 risks)

---

## How to Use This Plan

1. Read in order. Do not skip phases. Do not reorder tasks.
2. Every phase has a GATE checklist. Verify every item before proceeding.
3. When you see a decision point, test BOTH paths and follow the one that matches.
4. Copy code from ARCHITECTURE.md — do not improvise.
5. Commit after every task using the specified commit messages.
6. Save deployed addresses / credentials to `.env` immediately.
7. If something fails and isn't covered by a decision tree: STOP. Report the error. Do not guess.
8. **VERIFY-MILESTONE tasks are mandatory** — they appear at phase boundaries and cannot be skipped. Failure stops the plan.
9. **seed-demo.ts** must be implemented before any demo-related phase. Run it before every E2E test.
10. **forge snapshot** must be run after initial contract deployment. This establishes the gas baseline.

---

## Phase Overview

| Phase | Purpose | Est. Time | Day(s) | Depends On |
|:---:|---------|-----------|:---:|-----------|
| 0 | Infrastructure: Minitias + IBC Relayers + Go/No-Go | 1 day | 1 (Apr 8) | — |
| 1 | Smart Contracts: Deploy + Unit Tests + IBC Verify | 1 day | 2 (Apr 9) | Phase 0 |
| 2+3 | Auto-Signing + Oracle + Frontend UI (parallel) | 1 day | 3 (Apr 10) | Phase 1 |
| 4 | Integration: E2E Testing + Bug Fixes + Demo Seed | 1 day | 4 (Apr 11) | Phase 2, 3 |
| 5 | Polish: Feature Freeze + Submission Prep | 1 day | 5 (Apr 12) | Phase 4 |
| 6 | Demo Video + Submission | 1 day | 6 (Apr 13) | Phase 5 |

**Buffer:** Apr 14-15 (2 days) reserved for demo re-recording, emergency fixes, and final submission. Phase 6 tasks may spill into buffer if needed.

---

## Phase 0: Infrastructure — Minitias + IBC + Go/No-Go

**Purpose:** Deploy 3 EVM Minitias (Settlement, Rollup A, Rollup B), start 3 IBC relayers, and test the CRITICAL hook-to-IBC callback pattern. This phase is the entire project's go/no-go gate.
**Estimated time:** 1 full day (Apr 8)
**PRD Risks addressed:** #1 (relayer setup), #2 (Minitia deployment), #13 (hook-to-IBC)

### Task 0.1: Prerequisites — Tools & Accounts

**Files:**
- Create: `.env` (from ARCHITECTURE.md Section 20, `.env.example`)

**Steps:**

1. Install Go (required for weave CLI):
   ```bash
   brew install go
   go version
   ```
   Expected: `go version go1.22+`

2. Install weave CLI:
   ```bash
   go install github.com/initia-labs/weave@latest
   weave version
   ```
   Expected: Version string printed

3. Install Foundry:
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   forge --version
   ```
   Expected: `forge 0.x.x`

4. Install Node.js 20+:
   ```bash
   node --version
   ```
   Expected: `v20.x.x` or higher

5. Generate deployer wallet:
   ```bash
   cast wallet new
   ```
   Save the private key and address. Record in `.env` as `DEPLOYER_PRIVATE_KEY`.

6. Set up Gitcoin Passport for faucet access:
   ```bash
   open https://passport.gitcoin.co
   ```
   - Create an account (GitHub or wallet login)
   - Verify at least 2 stamps (GitHub, Google, or Discord)
   - Score must be ≥ 15 for Initia faucet

7. Request testnet INIT from https://faucet.testnet.initia.xyz/ (need ~10 INIT for OPinit bots + deployment gas).

8. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```
   Fill in `DEPLOYER_PRIVATE_KEY` with the generated key.

#### Decision Point: Faucet Access (Risk #2, #9)

Run: Visit https://faucet.testnet.initia.xyz/ and request tokens.
Expected: INIT tokens received in deployer wallet.

- **If it works:** Continue to Task 0.2.

- **If faucet requires Gitcoin Passport and you don't have one:**
  1. Go to https://passport.gitcoin.co
  2. Create passport and verify stamps
  3. Retry faucet
  4. If still blocked: ask in Initia Discord #developers for testnet tokens

- **If faucet is down or rate-limited:**
  1. Check Initia Discord for alternative faucets
  2. Try requesting from a different wallet address
  3. If completely blocked: proceed with local devnet setup (see Task 0.2 alternative path)

**Commit:**
```bash
git init
git add .env.example
git commit -m "chore: initialize project with env template"
```

---

### Task 0.2: Deploy Settlement Minitia

**References:** ARCHITECTURE.md Section 22 (Deployment Sequence, step 1)

**Commit:**
```bash
git add .env.example
git commit -m "infra: deploy Settlement Minitia and record RPC endpoints"
```

**Steps:**

1. Launch Settlement Minitia (the GhostPay routing hub):
   ```bash
   weave rollup launch
   ```
   Interactive prompts — select:
   - VM type: **EVM**
   - Chain ID: `ghostpay-settlement-1`
   - Enable oracle: **Yes** (required for price feeds)
   - Enable IBC: **Yes**

2. Wait for the rollup to start producing blocks.

3. Verify Settlement Minitia is running:
   ```bash
   curl -s -X POST -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
     http://localhost:8546
   ```
   Expected: `{"jsonrpc":"2.0","id":1,"result":"0x..."}` (non-zero block number)

4. Update `.env`:
   ```
   SETTLEMENT_RPC=http://localhost:8546
   SETTLEMENT_REST=http://localhost:1318
   ```

#### Decision Point: Minitia Deployment (Risk #2)

Run: `curl -s http://localhost:8546` (or whatever port weave assigns)
Expected: JSON-RPC response

- **If it works:** Continue to Task 0.3.

- **If `weave rollup launch` fails with dependency errors:**
  1. Check Go version: `go version` (need 1.22+)
  2. Update weave: `go install github.com/initia-labs/weave@latest`
  3. Retry launch

- **If Minitia starts but crashes immediately:**
  1. Check logs: `weave rollup logs`
  2. Common issue: insufficient INIT for OPinit bot — check bot wallet balance
  3. If OPinit bot funding issue: fund from faucet, restart

- **If nothing works after 2 hours:**
  1. **FALLBACK: L1-only settlement.** Deploy PaymentRegistry directly on Initia L1 testnet.
  2. This reduces architecture from 4-hop to 2-hop (Rollup A → L1 → Rollup B).
  3. Score impact: drops from ~8.0 to ~6.5 (lose "own rollup" points).
  4. Continue from Task 0.5 using L1 RPC (`https://rpc.testnet.initia.xyz`).

---

### Task 0.3: Deploy Rollup A and Rollup B

**References:** ARCHITECTURE.md Section 22 (Deployment Sequence, steps 2-3)

**Steps:**

1. Launch Rollup A:
   ```bash
   weave rollup launch
   ```
   Select:
   - VM type: **EVM**
   - Chain ID: `ghostpay-rollup-a-1`
   - Enable oracle: **No**
   - Enable IBC: **Yes**

2. Verify Rollup A:
   ```bash
   curl -s -X POST -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
     http://localhost:8545
   ```

3. Launch Rollup B:
   ```bash
   weave rollup launch
   ```
   Select:
   - VM type: **EVM**
   - Chain ID: `ghostpay-rollup-b-1`
   - Enable oracle: **No**
   - Enable IBC: **Yes**

4. Verify Rollup B:
   ```bash
   curl -s -X POST -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
     http://localhost:8547
   ```

5. Update `.env` with all chain RPCs:
   ```
   ROLLUP_A_RPC=http://localhost:8545
   ROLLUP_A_REST=http://localhost:1317
   ROLLUP_B_RPC=http://localhost:8547
   ROLLUP_B_REST=http://localhost:1319
   ```

**Note:** Port numbers may differ from the defaults above — use whatever `weave rollup launch` assigns. Record the actual ports in `.env`.

**Commit:**
```bash
git add .env.example
git commit -m "infra: record chain RPC endpoints after Minitia deployment"
```

---

### Task 0.4: Start IBC Relayers

**References:** ARCHITECTURE.md Section 22 (Deployment Sequence, steps 4-7) and Section 24 (Integration Map — IBC Relayer entries)

**Commit:**
```bash
git add .env.example
git commit -m "infra: start IBC relayers and record channel IDs"
```

**Steps:**

1. Start relayer for L1 ↔ Settlement:
   ```bash
   weave relayer start --chain-a initia-testnet --chain-b ghostpay-settlement-1
   ```

2. Start relayer for L1 ↔ Rollup A:
   ```bash
   weave relayer start --chain-a initia-testnet --chain-b ghostpay-rollup-a-1
   ```

3. Start relayer for L1 ↔ Rollup B:
   ```bash
   weave relayer start --chain-a initia-testnet --chain-b ghostpay-rollup-b-1
   ```

4. Verify all relayers are active:
   ```bash
   weave relayer status
   ```
   Expected: 3 active relayers shown

5. Record IBC channel IDs:
   ```bash
   weave relayer channels
   ```
   Update `.env`:
   ```
   SETTLEMENT_CHANNEL=channel-N  (L1↔Settlement channel from Rollup A's perspective)
   DEST_CHANNEL=channel-M        (L1↔Rollup B channel from Settlement's perspective)
   ```

#### Decision Point: IBC Relayer Setup (Risk #1)

Run: `weave relayer status`
Expected: 3 active relayers

- **If all 3 work:** Continue to Task 0.5.

- **If relayer fails to start with channel creation error:**
  1. Check that both chains are producing blocks
  2. Try manual channel creation: `weave relayer create-channel --chain-a X --chain-b Y`
  3. Restart relayer after channel exists

- **If relayer starts but packets are not relayed:**
  1. Check relayer logs: `weave relayer logs`
  2. Common issue: relayer wallet needs funding on both chains
  3. Fund relayer wallet from faucet on both L1 and Minitia

- **If Settlement relayer works but Rollup A/B relayers fail:**
  1. Use existing testnet Minitias instead of deploying your own for Rollup A/B
  2. Query Initia registry for available testnet Minitias with IBC channels
  3. Deploy StreamSender/StreamReceiver to existing Minitias

- **If no relayers work after 3 hours:**
  1. **FALLBACK: All contracts on L1.** Deploy all 3 contracts to Initia L1 testnet.
  2. Replace IBC transfers with direct contract calls.
  3. Score impact: drops to ~5.0 (no own rollup, no IBC demo).
  4. Skip Tasks 0.5. Proceed to Phase 1 using L1 addresses.

---

### Task 0.5: Test Hook-to-IBC Callback Pattern (CRITICAL Go/No-Go)

**Purpose:** Verify that a contract can call `execute_cosmos(MsgTransfer)` from within an IBC hook callback. This is the architectural linchpin — if it fails, the 4-hop routing breaks.
**Note:** This test validates the hook-to-IBC *pattern* only (1-arg test function). The actual 8-arg `processPayment` calldata encoding is validated later in Task 1.8.
**References:** ARCHITECTURE.md Section 7 (StreamSender `_sendIbcWithHook`) and Section 8 (PaymentRegistry `_forwardToDestination`) — both rely on this pattern.

**Commit:**
```bash
git add contracts/src/test/HookToIbcTest.sol
git commit -m "test(ibc): verify hook-to-IBC callback pattern on Settlement"
```

**Files:**
- Create: `contracts/src/test/HookToIbcTest.sol` (temporary test contract — not in Architecture Doc)

**Steps:**

1. Write a minimal test contract:
   ```solidity
   // SPDX-License-Identifier: MIT
   pragma solidity ^0.8.24;

   interface ICosmos {
       function execute_cosmos(string memory msg) external;
       function to_cosmos_address(address addr) external view returns (string memory);
   }

   contract HookToIbcTest {
       ICosmos constant COSMOS = ICosmos(0x00000000000000000000000000000000000000f1);
       event HookFired(bool ibcSent);

       // This function will be called via IBC hook memo
       function onHookReceive(string calldata destChannel) external {
           string memory sender = COSMOS.to_cosmos_address(address(this));
           string memory msgTransfer = string(abi.encodePacked(
               '{"@type":"/ibc.applications.transfer.v1.MsgTransfer",',
               '"source_port":"transfer",',
               '"source_channel":"', destChannel, '",',
               '"token":{"denom":"uinit","amount":"1"},',
               '"sender":"', sender, '",',
               '"receiver":"', sender, '",',  // send to self for testing
               '"timeout_timestamp":"99999999999999999999"}'
           ));
           COSMOS.execute_cosmos(msgTransfer);
           emit HookFired(true);
       }
   }
   ```

2. Deploy to Settlement Minitia:
   ```bash
   cd contracts
   forge create src/test/HookToIbcTest.sol:HookToIbcTest \
     --rpc-url $SETTLEMENT_RPC \
     --private-key $DEPLOYER_PRIVATE_KEY \
     --via-ir
   ```
   Record the deployed address.

3. Send an IBC transfer from Rollup A to Settlement with a hook memo that calls `onHookReceive`:
   ```bash
   # Build the hook memo (replace CONTRACT_ADDR with deployed address)
   # The calldata for onHookReceive(destChannel) where destChannel = "channel-M"
   CALLDATA=$(cast calldata "onHookReceive(string)" "channel-M")

   # Send IBC transfer with memo from Rollup A
   # Use initiad or cast to call ICosmos precompile
   cast send 0x00000000000000000000000000000000000000f1 \
     "execute_cosmos(string)" \
     '{"@type":"/ibc.applications.transfer.v1.MsgTransfer","source_port":"transfer","source_channel":"'$SETTLEMENT_CHANNEL'","token":{"denom":"uinit","amount":"100"},"sender":"DEPLOYER_COSMOS_ADDR","receiver":"CONTRACT_COSMOS_ADDR","timeout_timestamp":"99999999999999999999","memo":"{\"evm\":{\"message\":{\"contract_addr\":\"CONTRACT_ADDR\",\"input\":\"0x'$CALLDATA'\"}}}"}' \
     --rpc-url $ROLLUP_A_RPC \
     --private-key $DEPLOYER_PRIVATE_KEY
   ```

4. Wait 30-60 seconds for IBC relay.

5. Check if the hook fired AND the outbound IBC transfer was initiated:
   ```bash
   # Check HookFired event on Settlement
   cast logs --from-block 0 --address $HOOK_TEST_CONTRACT --rpc-url $SETTLEMENT_RPC
   ```

#### Decision Point: Hook-to-IBC Pattern (Risk #13 — CRITICAL)

Run: Check logs for `HookFired(true)` event on Settlement Minitia.
Expected: Event emitted, AND outbound IBC packet visible in relayer logs.

- **If both hook fires AND outbound IBC works:** Full 4-hop architecture confirmed. Continue to Phase 0 Gate.

- **If hook fires but outbound IBC fails (reentrancy guard blocks MsgTransfer inside hook):**
  1. **FALLBACK: Deploy PaymentRegistry on L1 directly.**
  2. StreamSender sends IBC to L1 (1 hop). PaymentRegistry on L1 sends IBC to Rollup B (1 hop). Total: 2 hops.
  3. Settlement Minitia becomes viewer-only (oracle queries, no routing).
  4. Update `.env`: `PAYMENT_REGISTRY_RPC` = L1 RPC.
  5. Architecture impact: PaymentRegistry deployment target changes from Settlement to L1. All code stays the same — only the RPC URL for deployment changes.
  6. Score impact: drops from ~8.0 to ~7.0 (still use own rollup, but routing is simpler).

- **If hook doesn't fire at all (memo format wrong):**
  1. Check IBC hook memo format. Verify `contract_addr` uses lowercase hex with `0x` prefix.
  2. Check that `input` field has `0x` prefix and correct ABI encoding.
  3. Verify the token actually arrived on Settlement (check IBC escrow).
  4. Try alternative memo format: `{"evm":{"async_callback":{"contract_addr":"...","input":"..."}}}`

- **If nothing works:**
  1. Deploy ALL contracts to L1 testnet. Replace IBC transfers with direct contract calls.
  2. Settlement Minitia becomes demo-only ("we deployed our own rollup" talking point).
  3. Score impact: ~5.5 (concept works, no live cross-rollup demo).

---

### Task 0.6: Query Oracle Address on Settlement

**References:** ARCHITECTURE.md Section 5 (IConnectOracle Interface) and Section 20 (Configuration Reference — ORACLE_ADDRESS)

**Steps:**

1. Query the ConnectOracle contract address:
   ```bash
   curl -s $SETTLEMENT_REST/minievm/evm/v1/connect_oracle | jq .
   ```
   Expected: `{"address": "0x031ECb63480983FD216D17BB6e1d393f3816b72F"}` (or similar)

2. Record in `.env`:
   ```
   ORACLE_ADDRESS=0x031ECb63480983FD216D17BB6e1d393f3816b72F
   ```

3. Query available oracle pairs:
   ```bash
   cast call $ORACLE_ADDRESS "get_all_currency_pairs()" --rpc-url $SETTLEMENT_RPC
   ```

#### Decision Point: Oracle Pair Availability (Risk #5)

Run: Decode the output of `get_all_currency_pairs()`.
Expected: `INIT/USD` in the list.

- **If INIT/USD is available:** Set `ORACLE_PAIR_ID=INIT/USD` in `.env`. Continue.

- **If only ETH/USD and BTC/USD are available:**
  1. Set `ORACLE_PAIR_ID=ETH/USD` in `.env`.
  2. Frontend will display ETH/USD price instead of INIT/USD — acceptable for demo.
  3. Add a comment in the demo video: "Production would use INIT/USD when available."

- **If oracle endpoint doesn't respond or no pairs exist:**
  1. Set `ORACLE_ADDRESS=0x0000000000000000000000000000000000000000` in `.env`.
  2. PaymentRegistry._getUsdValue() will return 0 (graceful fallback — payments still work).
  3. Frontend shows token amounts only, no USD conversion.

**Commit:**
```bash
git add .env.example
git commit -m "infra: complete Minitia deployment with IBC channels and oracle config"
```

---

### Phase 0 Gate

Before proceeding to Phase 1, verify:
- [ ] Settlement Minitia producing blocks: `curl -s $SETTLEMENT_RPC` returns JSON-RPC response
- [ ] Rollup A producing blocks: `curl -s $ROLLUP_A_RPC` returns JSON-RPC response
- [ ] Rollup B producing blocks: `curl -s $ROLLUP_B_RPC` returns JSON-RPC response
- [ ] 3 IBC relayers active: `weave relayer status` shows 3 active
- [ ] IBC channel IDs recorded in `.env` (`SETTLEMENT_CHANNEL`, `DEST_CHANNEL`)
- [ ] Hook-to-IBC pattern tested (PASS or FALLBACK decision recorded)
- [ ] Oracle address recorded in `.env` (or 0x0 for graceful degradation)
- [ ] Deployer wallet funded on all 3 chains
- [ ] All commits made for Phase 0

**If any check fails: DO NOT proceed. Fix the failing check first.**
**If go/no-go failed: Verify fallback path is documented and `.env` is updated for the chosen fallback.**

---

## Phase 1: Smart Contracts — Build, Test, Deploy

**Purpose:** Create all Solidity contracts, run Foundry unit tests, deploy to all 3 chains, and verify basic IBC transfer manually.
**Estimated time:** 1 day (Apr 9)
**PRD Risks addressed:** #8 (IBC hooks), #11 (JSON memo building), #14 (IBC denom handling)

### Task 1.1: Initialize Foundry Project

**Files:**
- Create: `contracts/foundry.toml` (from ARCHITECTURE.md Section 12)

**Steps:**

1. Create project structure:
   ```bash
   mkdir -p contracts/src/interfaces contracts/src/lib contracts/script contracts/test
   ```

2. Initialize Foundry:
   ```bash
   cd contracts
   forge init --no-commit --force .
   ```

3. Install OpenZeppelin:
   ```bash
   forge install OpenZeppelin/openzeppelin-contracts --no-commit
   ```

4. Copy `foundry.toml` from ARCHITECTURE.md Section 12:
   ```bash
   cat > foundry.toml << 'EOF'
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
   EOF
   ```

5. Add OpenZeppelin remapping if needed:
   ```bash
   echo '@openzeppelin/=lib/openzeppelin-contracts/' >> remappings.txt
   ```

6. Verify compilation works:
   ```bash
   forge build --via-ir
   ```
   Expected: No errors (contracts not written yet, but toolchain validated).

**Commit:**
```bash
cd ..
git add contracts/foundry.toml contracts/lib contracts/remappings.txt
git commit -m "build(contracts): initialize Foundry project with OpenZeppelin"
```

---

### Task 1.2: Create Interfaces and Libraries

**Files:**
- Create: `contracts/src/interfaces/ICosmos.sol` (from ARCHITECTURE.md Section 4)
- Create: `contracts/src/interfaces/IConnectOracle.sol` (from ARCHITECTURE.md Section 5)
- Create: `contracts/src/lib/HexUtils.sol` (from ARCHITECTURE.md Section 6)

**Steps:**

1. Copy `ICosmos.sol` exactly from ARCHITECTURE.md Section 4 (lines 269-295).
2. Copy `IConnectOracle.sol` exactly from ARCHITECTURE.md Section 5 (lines 316-340).
3. Copy `HexUtils.sol` exactly from ARCHITECTURE.md Section 6 (lines 360-384).

4. Verify compilation:
   ```bash
   cd contracts && forge build --via-ir
   ```
   Expected: `Compiler run successful`

**Commit:**
```bash
cd ..
git add contracts/src/interfaces/ contracts/src/lib/
git commit -m "feat(contracts): add ICosmos, IConnectOracle interfaces and HexUtils library"
```

---

### Task 1.3: Create Core Contracts

**Files:**
- Create: `contracts/src/StreamSender.sol` (from ARCHITECTURE.md Section 7)
- Create: `contracts/src/PaymentRegistry.sol` (from ARCHITECTURE.md Section 8)
- Create: `contracts/src/StreamReceiver.sol` (from ARCHITECTURE.md Section 9)

**Steps:**

1. Copy `StreamSender.sol` exactly from ARCHITECTURE.md Section 7 (lines 403-606).
2. Copy `PaymentRegistry.sol` exactly from ARCHITECTURE.md Section 8 (lines 637-855).
3. Copy `StreamReceiver.sol` exactly from ARCHITECTURE.md Section 9 (lines 882-999).

4. Compile all contracts:
   ```bash
   cd contracts && forge build --via-ir
   ```
   Expected: `Compiler run successful` with no errors.

#### Decision Point: Compilation Errors

Run: `forge build --via-ir`
Expected: Clean compilation.

- **If `Strings.sol` import fails:**
  1. Check remappings: `cat remappings.txt`
  2. Should have: `@openzeppelin/=lib/openzeppelin-contracts/`
  3. If missing: `echo '@openzeppelin/=lib/openzeppelin-contracts/' >> remappings.txt`
  4. Retry: `forge build --via-ir`

- **If `via-ir` causes stack-too-deep:**
  1. Remove `via_ir = true` from foundry.toml
  2. Use `--via-ir` only for deployment, not for testing
  3. Retry: `forge build`

- **If ICosmos interface signature doesn't match precompile:**
  1. Verify against https://github.com/initia-labs/initia-evm-contracts/blob/main/src/interfaces/ICosmos.sol
  2. Update interface to match the canonical version
  3. Retry compilation

**Commit:**
```bash
cd ..
git add contracts/src/StreamSender.sol contracts/src/PaymentRegistry.sol contracts/src/StreamReceiver.sol
git commit -m "feat(contracts): add StreamSender, PaymentRegistry, and StreamReceiver"
```

---

### Task 1.4: Create Deploy Scripts

**Files:**
- Create: `contracts/script/Deploy.s.sol` (from ARCHITECTURE.md Section 10)

**Steps:**

1. Copy `Deploy.s.sol` exactly from ARCHITECTURE.md Section 10 (lines 1022-1073).

2. Verify it compiles:
   ```bash
   cd contracts && forge build --via-ir
   ```
   Expected: All scripts compile.

**Commit:**
```bash
cd ..
git add contracts/script/Deploy.s.sol
git commit -m "feat(contracts): add deployment scripts for all 3 chains"
```

---

### Task 1.5: Create and Run Unit Tests

**Files:**
- Create: `contracts/test/StreamSender.t.sol` (from ARCHITECTURE.md Section 11)
- Create: `contracts/test/PaymentRegistry.t.sol` (from ARCHITECTURE.md Section 11)
- Create: `contracts/test/StreamReceiver.t.sol` (from ARCHITECTURE.md Section 11)

**Steps:**

1. Copy all 3 test files from ARCHITECTURE.md Section 11 (lines 1112-1342).

2. Run all tests:
   ```bash
   cd contracts && forge test --via-ir -vvv
   ```
   Expected: All tests pass.

3. Run tests individually to isolate any failures:
   ```bash
   forge test --match-contract StreamSenderTest --via-ir -vvv
   forge test --match-contract PaymentRegistryTest --via-ir -vvv
   forge test --match-contract StreamReceiverTest --via-ir -vvv
   ```

#### Decision Point: Test Failures

Run: `forge test --via-ir -vvv`
Expected: All tests green.

- **If `vm.mockCall` for ICosmos doesn't work:**
  1. The precompile at `0xf1` may need a different mock approach.
  2. Try deploying a mock contract instead:
     ```solidity
     contract MockCosmos {
         function execute_cosmos(string memory) external {}
         function to_cosmos_address(address) external pure returns (string memory) {
             return "init1mockaddr...";
         }
     }
     ```
  3. Deploy mock at 0xf1 using `vm.etch(0xf1, mockBytecode)` in setUp.

- **If `_escapeJson` causes gas limit issues in tests:**
  1. Increase gas limit: `forge test --gas-limit 30000000`
  2. Or skip IBC-related tests: `forge test --no-match-test testSendTick`

**Commit:**
```bash
cd ..
git add contracts/test/
git commit -m "test(contracts): add unit tests for all 3 contracts with ICosmos mocks"
```

---

### Task 1.6: Deploy Contracts to Chains

**References:** ARCHITECTURE.md Section 10 (Deploy Scripts) and Section 22 (Deployment Sequence, steps 8-10)

**Steps:**

Deploy in dependency order (StreamReceiver first, then PaymentRegistry, then StreamSender):

1. Deploy StreamReceiver on Rollup B:
   ```bash
   cd contracts
   STREAM_DENOM=uinit \
   forge script script/Deploy.s.sol:DeployStreamReceiver \
     --rpc-url $ROLLUP_B_RPC \
     --private-key $DEPLOYER_PRIVATE_KEY \
     --broadcast --via-ir --with-gas-price 0 --skip-simulation
   ```
   Record the address printed to console. Update `.env`:
   ```
   STREAM_RECEIVER_ADDRESS=0x...
   ```

2. Deploy PaymentRegistry on Settlement:
   ```bash
   STREAM_DENOM=uinit \
   ORACLE_ADDRESS=$ORACLE_ADDRESS \
   ORACLE_PAIR_ID=$ORACLE_PAIR_ID \
   STREAM_RECEIVER_ADDRESS=$STREAM_RECEIVER_ADDRESS \
   forge script script/Deploy.s.sol:DeployPaymentRegistry \
     --rpc-url $SETTLEMENT_RPC \
     --private-key $DEPLOYER_PRIVATE_KEY \
     --broadcast --via-ir --with-gas-price 0 --skip-simulation
   ```
   Record address. Update `.env`:
   ```
   PAYMENT_REGISTRY_ADDRESS=0x...
   ```

3. Deploy StreamSender on Rollup A:
   ```bash
   STREAM_DENOM=uinit \
   SETTLEMENT_CHANNEL=$SETTLEMENT_CHANNEL \
   PAYMENT_REGISTRY_ADDRESS=$PAYMENT_REGISTRY_ADDRESS \
   forge script script/Deploy.s.sol:DeployStreamSender \
     --rpc-url $ROLLUP_A_RPC \
     --private-key $DEPLOYER_PRIVATE_KEY \
     --broadcast --via-ir --with-gas-price 0 --skip-simulation
   ```
   Record address. Update `.env`:
   ```
   STREAM_SENDER_ADDRESS=0x...
   ```

4. Verify all deployments:
   ```bash
   # Check StreamReceiver
   cast call $STREAM_RECEIVER_ADDRESS "denom()" --rpc-url $ROLLUP_B_RPC

   # Check PaymentRegistry
   cast call $PAYMENT_REGISTRY_ADDRESS "denom()" --rpc-url $SETTLEMENT_RPC

   # Check StreamSender
   cast call $STREAM_SENDER_ADDRESS "denom()" --rpc-url $ROLLUP_A_RPC
   ```
   Expected: All return the denom string.

#### Decision Point: Deployment Failures

Run: Deploy commands above.
Expected: All 3 contracts deployed with addresses logged.

- **If `--with-gas-price 0` fails:**
  1. Try without it: remove `--with-gas-price 0`
  2. Or try explicit low gas price: `--with-gas-price 1`
  3. Minitias typically have 0 gas price, but config may vary

- **If `--skip-simulation` causes issues:**
  1. Remove `--skip-simulation` and let Foundry simulate first
  2. If simulation fails but you need to force: use `--slow` flag instead

- **If contract deployment reverts:**
  1. Check deployer balance on that chain: `cast balance $DEPLOYER_ADDRESS --rpc-url $RPC`
  2. Fund if needed via faucet or cross-chain transfer
  3. Retry deployment

**Commit:**
```bash
cd ..
git add .env.example contracts/
git commit -m "deploy(contracts): deploy all 3 contracts to Minitias"
```

---

### Task 1.7: Establish Gas Baseline

**References:** ARCHITECTURE.md Section 21 (Testing Strategy — gas snapshot) and Section 27 (Performance Budgets)

**Files:**
- Create: `.gas-snapshot` (auto-generated by forge)

**Steps:**

1. Run gas snapshot:
   ```bash
   cd contracts && forge snapshot --via-ir
   ```

2. Verify `.gas-snapshot` file was created:
   ```bash
   cat .gas-snapshot
   ```
   Expected: Gas costs for each test function.

**Commit:**
```bash
cd ..
git add contracts/.gas-snapshot
git commit -m "test(gas): establish gas baseline with forge snapshot"
```

---

### Task 1.8: Manual IBC Verification

**References:** ARCHITECTURE.md Section 7 (StreamSender — createStream, sendTick), Section 8 (PaymentRegistry — processPayment), Section 9 (StreamReceiver — getClaimable), and Section 24 (Integration Map)

**Purpose:** Verify the full stream tick flow works end-to-end: Rollup A → Settlement → Rollup B.

**Steps:**

1. Create a test stream on StreamSender (Rollup A):
   ```bash
   cast send $STREAM_SENDER_ADDRESS \
     "createStream(string,string,uint256)" \
     "init1testrecv..." "$DEST_CHANNEL" 300 \
     --value 10000000000000000000 \
     --rpc-url $ROLLUP_A_RPC \
     --private-key $DEPLOYER_PRIVATE_KEY
   ```
   Record the returned streamId from logs.

2. Send one tick:
   ```bash
   cast send $STREAM_SENDER_ADDRESS \
     "sendTick(bytes32)" \
     $STREAM_ID \
     --rpc-url $ROLLUP_A_RPC \
     --private-key $DEPLOYER_PRIVATE_KEY
   ```

3. Wait 30-60 seconds for IBC relay (2 hops: Rollup A → L1 → Settlement).

4. Check PaymentRegistry on Settlement:
   ```bash
   cast call $PAYMENT_REGISTRY_ADDRESS \
     "getStream(bytes32)" \
     $STREAM_ID \
     --rpc-url $SETTLEMENT_RPC
   ```
   Expected: Non-zero `amountSent` value.

5. Wait another 30-60 seconds for the second hop (Settlement → L1 → Rollup B).

6. Check StreamReceiver on Rollup B:
   ```bash
   # Use the derived EVM address for the test receiver
   cast call $STREAM_RECEIVER_ADDRESS \
     "getClaimable(address)" \
     $TEST_RECEIVER_ADDRESS \
     --rpc-url $ROLLUP_B_RPC
   ```
   Expected: Non-zero claimable amount.

#### Decision Point: IBC Hook Execution (Risk #8)

Run: Steps 4-6 above.
Expected: Funds arrive at PaymentRegistry AND forward to StreamReceiver.

- **If funds arrive at Settlement but don't forward to Rollup B:**
  1. Check the IBC denom on Settlement: the token received may be `ibc/HASH` not `uinit`.
  2. Call `setDenom` on PaymentRegistry with the actual IBC denom:
     ```bash
     cast send $PAYMENT_REGISTRY_ADDRESS \
       "setDenom(string)" \
       "ibc/ACTUAL_HASH_HERE" \
       --rpc-url $SETTLEMENT_RPC \
       --private-key $DEPLOYER_PRIVATE_KEY
     ```
  3. Retry the tick and check forwarding.
  4. **This is Risk #14 materialized.** The fix is always to update the denom.

- **If funds don't arrive at Settlement at all:**
  1. Check relayer status: `weave relayer status`
  2. Check if the IBC transfer was sent: look at tx receipt on Rollup A for MsgTransfer events
  3. Check hook memo format — ensure `contract_addr` is correct hex with `0x` prefix

- **If hook memo doesn't trigger processPayment:**
  1. Verify memo JSON format matches: `{"evm":{"message":{"contract_addr":"0x...","input":"0x..."}}}`
  2. Check that `input` is valid ABI-encoded calldata for `processPayment`
  3. Try a simpler test: send IBC transfer with no memo, verify tokens arrive, then add memo back

**Commit:**
```bash
git add .
git commit -m "test(ibc): verify end-to-end IBC transfer flow across all 3 chains"
```

---

### Task 1.9: VERIFY-MILESTONE Checkpoint — Core Infrastructure

**References:** ARCHITECTURE.md Section 25 (Acceptance Criteria) and Section 21 (Testing Strategy)

**Purpose:** Mid-build quality gate. Validates that the foundation is solid before building frontend.

**Commit:**
```bash
git add .
git commit -m "milestone: verify core infrastructure — contracts deployed, IBC verified"
```

**Steps:**
1. Verify all 3 contracts deployed and responding.
2. Verify at least one IBC transfer completed the full Rollup A → Settlement → Rollup B path.
3. Verify unit tests pass: `cd contracts && forge test --via-ir -vvv`

**Gate (MANDATORY):**
- [ ] All 3 contracts deployed with addresses in `.env`
- [ ] `forge test --via-ir` passes (all unit tests green)
- [ ] At least 1 manual IBC tick verified end-to-end (or fallback path documented)
- [ ] Gas snapshot exists (`.gas-snapshot`)
- [ ] IBC denom recorded (if different from `uinit`, `setDenom` called)

**If gate fails: STOP. Do not proceed to Phase 2. Fix the failing check.**

---

### Phase 1 Gate

Before proceeding to Phase 2, verify ALL of the above plus:
- [ ] StreamSender deployed on Rollup A: `cast call $STREAM_SENDER_ADDRESS "denom()" --rpc-url $ROLLUP_A_RPC`
- [ ] PaymentRegistry deployed on Settlement: `cast call $PAYMENT_REGISTRY_ADDRESS "denom()" --rpc-url $SETTLEMENT_RPC`
- [ ] StreamReceiver deployed on Rollup B: `cast call $STREAM_RECEIVER_ADDRESS "denom()" --rpc-url $ROLLUP_B_RPC`
- [ ] All unit tests pass: `cd contracts && forge test --via-ir`
- [ ] Manual IBC tick verified OR fallback documented
- [ ] All deployed addresses recorded in `.env`
- [ ] All commits made for Phase 1

---

## Phase 2: Auto-Signing + Oracle + Stream Execution

**Purpose:** Integrate InterwovenKit auto-signing (ghost wallet), verify oracle price feeds, and achieve a working automated stream tick cycle.
**Estimated time:** 0.5 day (Apr 10 AM) — run in parallel with Phase 3
**PRD Risks addressed:** #3 (auto-signing), #5 (oracle), #12 (InterwovenKit)

### Task 2.1: Initialize Frontend Project

**Files:**
- Create: `frontend/package.json` (from ARCHITECTURE.md Section 13)
- Create: `frontend/vite.config.ts` (from ARCHITECTURE.md Section 13)
- Create: `frontend/tsconfig.json` (from ARCHITECTURE.md Section 13)
- Create: `frontend/tailwind.config.ts` (from ARCHITECTURE.md Section 13)
- Create: `frontend/postcss.config.js` (from ARCHITECTURE.md Section 13)
- Create: `frontend/index.html` (from ARCHITECTURE.md Section 13)
- Create: `frontend/src/main.tsx` (from ARCHITECTURE.md Section 18)
- Create: `frontend/src/index.css` (from ARCHITECTURE.md Section 13)

**Steps:**

1. Create frontend directory:
   ```bash
   mkdir -p frontend/src/{config,types,hooks,pages,components}
   ```

2. Copy all config files from ARCHITECTURE.md Section 13.

3. Install dependencies:
   ```bash
   cd frontend && npm install
   ```
   Expected: Clean install with no errors.

4. Verify dev server starts:
   ```bash
   npm run dev
   ```
   Expected: Vite dev server running on localhost:5173.

**Commit:**
```bash
cd ..
git add frontend/
git commit -m "feat(frontend): initialize Vite + React + InterwovenKit project"
```

---

### Task 2.2: Create Shared Types and Config

**Files:**
- Create: `frontend/src/types/index.ts` (from ARCHITECTURE.md Section 3)
- Create: `frontend/src/config/chains.ts` (from ARCHITECTURE.md Section 14)
- Create: `frontend/src/config/contracts.ts` (from ARCHITECTURE.md Section 14)

**Steps:**

1. Copy `types/index.ts` from ARCHITECTURE.md Section 3 (lines 187-253).
2. Copy `chains.ts` from ARCHITECTURE.md Section 14.
3. Copy `contracts.ts` from ARCHITECTURE.md Section 14.

4. Verify TypeScript compiles:
   ```bash
   cd frontend && npx tsc --noEmit
   ```

**Commit:**
```bash
cd ..
git add frontend/src/types/ frontend/src/config/
git commit -m "feat(frontend): add shared types, chain config, and contract ABIs"
```

---

### Task 2.3: Create Hooks — useStreams + useStreamTick + useOracle

**Files:**
- Create: `frontend/src/hooks/useStreams.ts` (from ARCHITECTURE.md Section 15)
- Create: `frontend/src/hooks/useStreamTick.ts` (from ARCHITECTURE.md Section 15)
- Create: `frontend/src/hooks/useOracle.ts` (from ARCHITECTURE.md Section 15)

**Steps:**

1. Copy all 3 hook files from ARCHITECTURE.md Section 15.

2. Key implementation notes:
   - `useStreamTick` uses `useRef` (not `useState`) for `isSending` to prevent infinite re-renders.
   - `useStreams` uses explicit `chain` parameter in both `createPublicClient` calls.
   - `useOracle` uses `tokenDecimals` parameter (default 18) in `formatUsdValue`.

3. Verify TypeScript:
   ```bash
   cd frontend && npx tsc --noEmit
   ```

#### Decision Point: InterwovenKit Auto-Sign API (Risk #3)

After implementing `useStreamTick`:

Run: Start the app, connect wallet, enable auto-sign, create a stream, verify tick fires.
Expected: Ghost wallet signs the tick transaction without a wallet popup.

- **If `autoSign.enable(chainId)` is not available in the InterwovenKit API:**
  1. Check InterwovenKit docs for the current auto-sign API
  2. Look for alternative: `enableAutoSign`, `createSessionKey`, or similar
  3. Update the hook to match the actual API
  4. If auto-sign is completely unavailable: fall back to manual signing per tick (user clicks "approve" each 30s)

- **If auto-sign enables but tick transactions fail:**
  1. Check the authz grant message types. Ensure `/minievm.evm.v1.MsgCall` is in the allowed list.
  2. Try `GenericAuthorization` instead of typed authorization
  3. Check feegrant is active for the ghost wallet

- **If InterwovenKit can't connect to custom Minitias:**
  1. Verify chain config has correct chain ID, RPC URL, and REST URL
  2. Check if InterwovenKit requires chains to be registered in Initia's chain registry
  3. If registry-required: add chains to the registry or use a different wallet connector

**Commit:**
```bash
cd ..
git add frontend/src/hooks/
git commit -m "feat(frontend): add useStreams, useStreamTick, and useOracle hooks"
```

---

### Task 2.4: Test Oracle Integration

**References:** ARCHITECTURE.md Section 5 (IConnectOracle — get_price) and Section 15 (useOracle hook)

**Steps:**

1. Verify oracle responds on Settlement:
   ```bash
   cast call $ORACLE_ADDRESS "get_price(string)" "$ORACLE_PAIR_ID" --rpc-url $SETTLEMENT_RPC
   ```
   Expected: Non-zero price value.

2. Verify from frontend hook (browser console):
   ```javascript
   // After connecting to Settlement in the app
   const price = await oracleContract.read.get_price(["INIT/USD"])
   console.log(price)
   ```

3. If oracle returns data, the frontend `useOracle` hook should display USD values.

**Commit:**
```bash
git add .
git commit -m "feat(oracle): verify oracle price feed integration on Settlement"
```

---

### Phase 2 Gate

Before proceeding to Phase 3, verify:
- [ ] Frontend dev server starts without errors: `cd frontend && npm run dev`
- [ ] TypeScript compiles clean: `cd frontend && npx tsc --noEmit`
- [ ] Hooks created: `useStreams.ts`, `useStreamTick.ts`, `useOracle.ts`
- [ ] Shared types and config files created
- [ ] Auto-sign tested (or fallback to manual signing documented)
- [ ] Oracle tested (or graceful degradation confirmed — shows 0 USD)
- [ ] All commits made for Phase 2

---

## Phase 3: Frontend — UI + Visualization

**Purpose:** Build all UI components and pages. Wire them to the hooks from Phase 2.
**Estimated time:** 0.5 day (Apr 10 PM) — run in parallel with Phase 2
**PRD Risks addressed:** #6 (Web Worker tab focus), #10 (scope creep)

### Task 3.1: Create Layout and Shared Components

**Files:**
- Create: `frontend/src/components/Layout.tsx` (from ARCHITECTURE.md Section 16)
- Create: `frontend/src/components/StreamCard.tsx` (from ARCHITECTURE.md Section 16)
- Create: `frontend/src/components/StreamCounter.tsx` (from ARCHITECTURE.md Section 16)
- Create: `frontend/src/components/BridgeVisualization.tsx` (from ARCHITECTURE.md Section 16)

**Steps:**

1. Copy all 4 component files from ARCHITECTURE.md Section 16.
2. Key notes:
   - `BridgeVisualization` uses `useRef` (not `useState`) for `nextId` to prevent stale closures.
   - `StreamCounter` animates balance increase using `requestAnimationFrame`.

3. Verify components render:
   ```bash
   cd frontend && npm run dev
   ```

**Commit:**
```bash
cd ..
git add frontend/src/components/
git commit -m "feat(frontend): add Layout, StreamCard, StreamCounter, BridgeVisualization"
```

---

### Task 3.2: Create Pages

**Files:**
- Create: `frontend/src/pages/Dashboard.tsx` (from ARCHITECTURE.md Section 17)
- Create: `frontend/src/pages/CreateStream.tsx` (from ARCHITECTURE.md Section 17)
- Create: `frontend/src/pages/DemoView.tsx` (from ARCHITECTURE.md Section 17)

**Steps:**

1. Copy all 3 page files from ARCHITECTURE.md Section 17.
2. Key notes:
   - `Dashboard` receives `wallet` prop (passed from App.tsx route).
   - `DemoView` is the split-screen view for demo recording.

**Commit:**
```bash
cd ..
git add frontend/src/pages/
git commit -m "feat(frontend): add Dashboard, CreateStream, and DemoView pages"
```

---

### Task 3.3: Create App Shell and Routing

**Files:**
- Create: `frontend/src/App.tsx` (from ARCHITECTURE.md Section 18)

**Steps:**

1. Copy `App.tsx` from ARCHITECTURE.md Section 18 (line 2649+).
2. Ensure `wallet` prop is passed to Dashboard in the route element.

3. Verify full app runs:
   ```bash
   cd frontend && npm run dev
   ```
   Expected: App loads at localhost:5173 with routing working.

4. Verify build:
   ```bash
   npm run build
   ```
   Expected: Clean build with no TypeScript errors.

#### Decision Point: Web Worker Tab Focus (Risk #6)

After app is running:

Run: Open app in browser. Start a stream. Switch to a different tab for 60 seconds. Switch back.
Expected: Stream ticks continued while tab was backgrounded.

- **If ticks stop when tab loses focus:**
  1. Add `visibilitychange` event listener in `useStreamTick`:
     ```typescript
     document.addEventListener('visibilitychange', () => {
       if (!document.hidden && streamActive) {
         sendTick(); // Fire immediate tick on tab return
       }
     });
     ```
  2. For demo recording: keep the GhostPay tab visible at all times (dedicated browser window).

- **If setInterval is throttled by browser:**
  1. Use Web Worker for the timer (move interval logic to a Worker)
  2. Or accept 30s intervals may stretch to 60s when backgrounded — demo-acceptable

**Commit:**
```bash
cd ..
git add frontend/src/App.tsx
git commit -m "feat(frontend): add App shell with routing and InterwovenKit provider"
```

---

### Phase 3 Gate

Before proceeding to Phase 4, verify:
- [ ] Frontend builds without errors: `cd frontend && npm run build`
- [ ] All pages render: Dashboard, CreateStream, DemoView
- [ ] BridgeVisualization animates (even with mock data)
- [ ] StreamCounter shows incrementing numbers
- [ ] Routing works: `/`, `/create`, `/demo` all load correct pages
- [ ] Scope check: NO features added beyond stream create + visualize + bridge cross
- [ ] All commits made for Phase 3

---

## Phase 4: Integration — E2E Testing + Demo Seed

**Purpose:** Wire everything together. Test the full flow end-to-end. Create demo seed data. Fix bugs.
**Estimated time:** 1 day (Apr 11)
**PRD Risks addressed:** #4 (latency), #6 (tab focus), #7 (testnet instability)

### Task 4.1: Create .env.example with All Values

**Files:**
- Update: `.env.example` (from ARCHITECTURE.md Section 20)

**Steps:**

1. Copy `.env.example` from ARCHITECTURE.md Section 20 (lines 2882-2928).
2. Populate `.env` with all actual values (deployed addresses, chain IDs, RPC URLs).
3. Populate all `VITE_` frontend env vars (see ARCHITECTURE.md Section 20 `.env.example` for full list):
   ```
   VITE_ROLLUP_A_RPC=...
   VITE_ROLLUP_A_REST=...
   VITE_ROLLUP_A_CHAIN_ID=ghostpay-rollup-a-1
   VITE_SETTLEMENT_RPC=...
   VITE_SETTLEMENT_REST=...
   VITE_SETTLEMENT_CHAIN_ID=ghostpay-settlement-1
   VITE_ROLLUP_B_RPC=...
   VITE_ROLLUP_B_REST=...
   VITE_ROLLUP_B_CHAIN_ID=ghostpay-rollup-b-1
   VITE_STREAM_SENDER_ADDRESS=...
   VITE_PAYMENT_REGISTRY_ADDRESS=...
   VITE_STREAM_RECEIVER_ADDRESS=...
   VITE_DEST_CHANNEL=...
   ```

**Commit:**
```bash
git add .env.example
git commit -m "config: update env template with all deployed addresses and chain config"
```

---

### Task 4.2: Implement Demo Seed Script

**Files:**
- Create: `scripts/seed-demo.ts` (from ARCHITECTURE.md Section 19)

**Steps:**

1. Copy `seed-demo.ts` from ARCHITECTURE.md Section 19 (lines 2769-2848).

2. Install script dependencies:
   ```bash
   npm install -D tsx viem dotenv
   ```
   Add `import 'dotenv/config'` as the first line of `seed-demo.ts` (loads `.env` automatically).

3. Run the seed script:
   ```bash
   npx tsx scripts/seed-demo.ts
   ```
   Expected: Stream created, tx hash logged, seed complete message.

4. Verify seed state:
   ```bash
   # Check stream exists on Rollup A
   cast call $STREAM_SENDER_ADDRESS "getSenderStreams(address)" $DEPLOYER_ADDRESS --rpc-url $ROLLUP_A_RPC
   ```

**Gate:** `npx tsx scripts/seed-demo.ts` runs to completion with no errors. Idempotent — safe to run multiple times.

**Commit:**
```bash
git add scripts/ package.json
git commit -m "seed(demo): implement seed-demo.ts from PRD Demo Prerequisites"
```

---

### Task 4.3: Full E2E Integration Test

**References:** ARCHITECTURE.md Section 24 (Integration Map — full data flow) and Section 27 (Performance Budgets — IBC latency targets)

**Steps:**

1. Start all services:
   - 3 Minitias running (from Phase 0)
   - 3 IBC relayers running (from Phase 0)
   - Frontend dev server: `cd frontend && npm run dev`

2. Run the seed script to create demo state:
   ```bash
   npx tsx scripts/seed-demo.ts
   ```

3. Open the app in browser. Connect wallet (deployer wallet).

4. **Test stream creation flow:**
   - Navigate to `/create`
   - Fill form: 5 INIT, 3 minutes, receiver address, Rollup B channel
   - Enable auto-sign
   - Click "Start Stream"
   - Expected: Stream appears on Dashboard

5. **Test stream execution:**
   - Wait 30 seconds for first tick
   - Expected: TickSent event on Rollup A (check browser console)
   - Wait 30-60s more for IBC relay
   - Expected: PaymentProcessed event on Settlement
   - Wait 30-60s more for second hop
   - Expected: Claimable balance increases on Rollup B

6. **Test DemoView:**
   - Navigate to `/demo`
   - Expected: Split-screen showing sender (left), bridge (center), receiver (right)
   - Expected: Bridge animation shows packets crossing
   - Expected: Receiver counter climbing

7. **Test claim:**
   - Switch to receiver wallet on Rollup B
   - Click "Claim" button
   - Expected: Funds transferred to receiver wallet via Cosmos MsgSend (not EVM transfer)
   - **Verify via Cosmos bank balance** (EVM balance won't change — claim uses `execute_cosmos`):
     ```bash
     curl -s "$ROLLUP_B_REST/cosmos/bank/v1beta1/balances/$(cast call 0xf1 'to_cosmos_address(address)' $TEST_RECEIVER_ADDRESS --rpc-url $ROLLUP_B_RPC)" | jq .
     ```

#### Decision Point: IBC Latency Too High (Risk #4)

Run: Time the full tick cycle (Rollup A → Settlement → Rollup B).
Expected: < 30 seconds for both hops combined.

- **If latency is 30-60 seconds (acceptable for demo):**
  1. Increase tick interval from 30s to 45s in `useStreamTick` to avoid overlapping ticks.
  2. Pre-seed multiple ticks so demo always has active bridge crossings.

- **If latency is > 60 seconds (too slow for compelling demo):**
  1. Pre-seed several completed ticks so receiver already has a climbing balance.
  2. Start demo with an already-running stream (~2 minutes in).
  3. Focus demo narrative on "this is live IBC" rather than speed.
  4. Consider: if using the L1 fallback (2 hops instead of 4), latency drops significantly.

- **If IBC packets timeout (> 10 minutes):**
  1. Check relayer status — may have crashed
  2. Restart relayer: `weave relayer restart`
  3. If persistent: increase timeout in MsgTransfer from 600s to 1800s

**Commit:**
```bash
git add .
git commit -m "test(e2e): verify full stream lifecycle across all 3 chains"
```

---

### Task 4.4: IBC Denom Fix (Risk #14)

**References:** ARCHITECTURE.md Section 8 (PaymentRegistry — setDenom) and Section 9 (StreamReceiver — setDenom)

**Purpose:** After the first IBC transfer lands on Settlement and Rollup B, verify the actual IBC denom and update contracts if needed.

**Steps:**

1. After Task 4.3 sends at least one tick, query the actual denom on Settlement:
   ```bash
   # Check what denom the PaymentRegistry received
   # Look at the bank balance of the PaymentRegistry contract's Cosmos address
   curl -s "$SETTLEMENT_REST/cosmos/bank/v1beta1/balances/$(cast call 0xf1 'to_cosmos_address(address)' $PAYMENT_REGISTRY_ADDRESS --rpc-url $SETTLEMENT_RPC)" | jq .
   ```
   Look for the `ibc/HASH` denom in the balances.

2. If the denom is not `uinit`, update PaymentRegistry:
   ```bash
   cast send $PAYMENT_REGISTRY_ADDRESS \
     "setDenom(string)" \
     "ibc/ACTUAL_HASH_HERE" \
     --rpc-url $SETTLEMENT_RPC \
     --private-key $DEPLOYER_PRIVATE_KEY
   ```

3. **WARNING:** The IBC denom on Settlement (`ibc/HASH_A`) and Rollup B (`ibc/HASH_B`) will be DIFFERENT — they traverse different IBC channel paths. Query each chain's bank balances independently.

4. Check the denom on Rollup B and update StreamReceiver:
   ```bash
   cast send $STREAM_RECEIVER_ADDRESS \
     "setDenom(string)" \
     "ibc/ACTUAL_HASH_ON_ROLLUP_B" \
     --rpc-url $ROLLUP_B_RPC \
     --private-key $DEPLOYER_PRIVATE_KEY
   ```

5. Retry the tick and verify funds forward correctly.

**Commit:**
```bash
git add .
git commit -m "fix(ibc): update IBC denoms on Settlement and Rollup B contracts"
```

---

### Task 4.5: VERIFY-MILESTONE Checkpoint — Integration Complete

**References:** ARCHITECTURE.md Section 25 (Acceptance Criteria) and Section 24 (Integration Map)

**Purpose:** Mid-build quality gate at ~60% completion. Verifies the core demo flow works.

**Commit:**
```bash
git add .
git commit -m "milestone: verify integration complete — E2E stream lifecycle working"
```

**Steps:**
1. Run seed script: `npx tsx scripts/seed-demo.ts`
2. Create a new stream via the UI
3. Verify at least 2 ticks complete the full cross-chain journey
4. Verify DemoView shows the bridge animation with real data

**Gate (MANDATORY — cannot be skipped):**
- [ ] Stream creation works from UI (tx confirmed on-chain)
- [ ] Auto-sign fires ticks without wallet popups (or manual fallback documented)
- [ ] At least 1 tick fully traverses Rollup A → Settlement → Rollup B
- [ ] DemoView renders with real stream data
- [ ] Receiver can see claimable balance increasing
- [ ] Oracle USD display shows value (or graceful "—" if oracle unavailable)

**If gate fails: STOP. Do not proceed to Phase 5. Debug and fix.**

---

### Phase 4 Gate

Before proceeding to Phase 5, verify:
- [ ] Full E2E flow works: create → auto-sign → IBC → receive → claim
- [ ] DemoView split-screen renders correctly with live data
- [ ] Bridge animation shows packets crossing
- [ ] IBC denom correctly set on all contracts
- [ ] Seed script runs successfully
- [ ] No blocking bugs
- [ ] All commits made for Phase 4

---

## Phase 5: Polish + Feature Freeze + Submission Prep

**Purpose:** Feature freeze. Bug fixes only. Prepare submission artifacts.
**Estimated time:** 1 day (Apr 12)
**PRD Concern addressed:** [I] Time budget — feature-freeze Day 5, no exceptions.

### SCOPE ENFORCEMENT (Risk #10)

**From this point forward: NO NEW FEATURES.** Only allowed:
- Bug fixes for existing features
- CSS/styling improvements for demo readability
- Submission artifact creation
- Demo data refinement

If you find yourself writing new functionality, STOP. It's scope creep.

### Task 5.1: Bug Fix Pass

**References:** ARCHITECTURE.md Section 26 (Security Considerations) and Section 27 (Performance Budgets)

**Steps:**

1. Run through the full demo flow 3 times. Record any bugs.
2. Fix each bug with a focused commit.
3. Re-run after each fix to verify no regressions.

Common bugs to check:
- [ ] Stream creation form validation (empty fields, zero amount)
- [ ] StreamCounter animation smooth (no jumps or resets)
- [ ] BridgeVisualization doesn't leak memory (check for interval cleanup)
- [ ] Wallet connection handles disconnection gracefully
- [ ] Tab switch doesn't break stream ticks
- [ ] Multiple streams don't conflict

**Commit per bug:**
```bash
git commit -m "fix: {specific bug description}"
```

---

### Task 5.2: Create Submission Artifacts

**References:** ARCHITECTURE.md Section 23 (Addresses) and Section 20 (Configuration Reference)

**Files:**
- Create: `.initia/submission.json`

**Steps:**

1. Create submission directory:
   ```bash
   mkdir -p .initia
   ```

2. Create `submission.json`:
   ```json
   {
     "project_name": "GhostPay",
     "track": "DeFi",
     "description": "Cross-rollup payment streaming infrastructure on Initia. Turns lump-sum payments into continuous money streams that flow automatically between rollups via IBC.",
     "team": ["builder-name"],
     "contracts": {
       "stream_sender": {
         "address": "<STREAM_SENDER_ADDRESS>",
         "chain": "ghostpay-rollup-a-1"
       },
       "payment_registry": {
         "address": "<PAYMENT_REGISTRY_ADDRESS>",
         "chain": "ghostpay-settlement-1"
       },
       "stream_receiver": {
         "address": "<STREAM_RECEIVER_ADDRESS>",
         "chain": "ghostpay-rollup-b-1"
       }
     },
     "initia_features": [
       "own_minitia",
       "ibc_transfers",
       "authz_feegrant",
       "connect_oracle",
       "interwovenkit"
     ],
     "repo": "https://github.com/<your-repo>"
   }
   ```

3. Update addresses with actual deployed values from `.env`.

**Commit:**
```bash
git add .initia/
git commit -m "chore: create submission.json with deployed contract addresses"
```

---

### Task 5.3: Demo Data Refinement

**References:** ARCHITECTURE.md Section 19 (Seed Demo Script)

**Steps:**

1. Run seed script to reset demo state:
   ```bash
   npx tsx scripts/seed-demo.ts
   ```

2. Create 2-3 pre-seeded streams at different stages:
   - One that's ~2 minutes in (most of the balance transferred)
   - One that's just starting (active bridge crossings)
   - One that's completed (shows final state)

3. Verify DemoView looks compelling with this data.

4. Take a screenshot of the DemoView for submission:
   ```bash
   # Open http://localhost:5173/demo in browser
   # Take screenshot manually
   ```

**Commit:**
```bash
git add .
git commit -m "demo: refine seed data for compelling demo recording"
```

---

### Task 5.4: Repository Cleanup

**References:** ARCHITECTURE.md Section 20 (Configuration Reference — .gitignore, .env.example)

**Steps:**

1. Ensure `.gitignore` excludes sensitive files:
   ```
   .env
   node_modules/
   contracts/out/
   contracts/cache/
   ```

2. Verify no private keys in committed files:
   ```bash
   git log --all -p | grep -i "private.key" | head -5
   ```

3. Clean build:
   ```bash
   cd frontend && npm run build
   cd ../contracts && forge build --via-ir
   ```

**Commit:**
```bash
git add .gitignore
git commit -m "chore: repository cleanup and .gitignore"
```

---

### Phase 5 Gate

Before proceeding to Phase 6, verify:
- [ ] **FEATURE FREEZE CONFIRMED** — no new features added
- [ ] All known bugs fixed
- [ ] `.initia/submission.json` created with correct addresses
- [ ] Demo data seeded and DemoView looks compelling
- [ ] Frontend builds clean: `cd frontend && npm run build`
- [ ] Contracts compile clean: `cd contracts && forge build --via-ir`
- [ ] No private keys in git history
- [ ] All commits made for Phase 5

---

## Phase 6: Demo Video + Submission

**Purpose:** Record the demo video. Package and submit.
**Estimated time:** 1 day (Apr 13) + 2 days buffer (Apr 14-15)
**PRD Risks addressed:** #7 (testnet instability during recording)

### Task 6.1: Demo Recording Prep

**References:** ARCHITECTURE.md Section 19 (Seed Demo Script) and Section 17 (DemoView page)

**Commit:**
```bash
git add .
git commit -m "demo: prep recording environment and verify seed data"
```

**Steps:**

1. Ensure all services are running:
   - 3 Minitias producing blocks
   - 3 IBC relayers active
   - Frontend dev server running

2. Run seed script fresh:
   ```bash
   npx tsx scripts/seed-demo.ts
   ```

3. Open DemoView in a dedicated browser window (not a tab — prevents focus loss).

4. Launch QuickTime screen recording (macOS built-in):
   ```bash
   open -a "QuickTime Player"
   ```
   Then: File → New Screen Recording → select 1920x1080 area → enable microphone input.

5. Recording settings:
   - Resolution: 1920x1080
   - Format: MP4 (QuickTime exports .mov — convert with `ffmpeg -i recording.mov -c copy recording.mp4`)
   - Audio: Microphone for voiceover (or record voiceover separately)

### Task 6.2: Record Demo (Following PRD Section 6)

**References:** ARCHITECTURE.md Section 17 (DemoView page layout) and PRD Section 6 (Demo Script — 7 scenes)

Follow the demo script from PRD Section 6 exactly:

1. **Scene 1 (0:00-0:25):** Problem statement — title card + pain points
2. **Scene 2 (0:25-0:50):** Architecture animation — money flow diagram
3. **Scene 3 (0:50-1:30):** Create a stream — live app, fill form, enable auto-sign
4. **Scene 4 (1:30-2:30):** Bridge crossing centerpiece — split-screen, real ticks crossing
5. **Scene 5 (2:30-3:00):** Multiple streams — second stream converges on receiver
6. **Scene 6 (3:00-3:30):** Why Initia — 5 native features diagram
7. **Scene 7 (3:30-3:45):** Close — logo, GitHub, team

**Recording tips:**
- Record each scene separately. Edit together later.
- For Scene 4: start recording with pre-seeded stream already running, then wait for live ticks.
- Multiple takes are expected. Plan for 3-5 takes of Scene 4 (the bridge crossing).
- If testnet is unstable: use pre-recorded clips of successful crossings.

#### Decision Point: Testnet Instability During Recording (Risk #7)

Expected: All scenes recorded cleanly in 2-3 hours.

- **If a Minitia crashes during recording:**
  1. Restart the crashed chain
  2. Re-run seed script
  3. Re-record the affected scene only

- **If IBC stops relaying during recording:**
  1. Restart relayers: `weave relayer restart`
  2. Wait 2 minutes for relay to resume
  3. Re-record from the last clean scene

- **If persistent instability:**
  1. Record Scene 4 (bridge crossing) first — it's the most infrastructure-dependent
  2. Record UI-only scenes (1, 2, 6, 7) afterward — they don't need live IBC
  3. If bridge crossing never works on camera: use terminal output showing cast commands and their results as "proof of cross-chain execution"

**Commit:**
```bash
git add .
git commit -m "demo: finalize demo recording assets"
```

---

### Task 6.3: Submit to Hackathon

**References:** ARCHITECTURE.md Section 23 (Addresses — all deployed contracts) and Section 20 (Configuration Reference)

**Steps:**

1. Push repository to GitHub:
   ```bash
   git remote add origin https://github.com/<your-repo>
   git push -u origin main
   ```

2. Upload demo video to YouTube (unlisted) or directly to the submission platform.

3. Fill submission form on the hackathon platform (DoraHacks, Devpost, etc.):
   - Project name: GhostPay
   - Track: DeFi
   - Description: From PRD Section 1
   - Demo video URL
   - GitHub repo URL
   - Contract addresses (from `.initia/submission.json`)
   - Initia features used: Own Minitia, IBC, authz+feegrant, ConnectOracle, InterwovenKit

4. Verify submission is confirmed.

**Commit:**
```bash
git add .
git commit -m "chore: final submission prep"
git push
```

---

### Phase 6 Gate (Final)

- [ ] Demo video recorded (3-4 minutes)
- [ ] Video uploaded to hosting platform
- [ ] Repository pushed to GitHub
- [ ] `.initia/submission.json` in repo with correct data
- [ ] Hackathon submission form completed
- [ ] All commits pushed to remote

---

## Appendix: Quick Reference

### All Addresses

| Item | Address | Network |
|------|---------|---------|
| ICosmos precompile | `0x00000000000000000000000000000000000000f1` | All EVM Minitias |
| ConnectOracle | Query `$SETTLEMENT_REST/minievm/evm/v1/connect_oracle` | Settlement |
| StreamSender | Record after deploy | Rollup A |
| PaymentRegistry | Record after deploy | Settlement |
| StreamReceiver | Record after deploy | Rollup B |

### All Commands

| Phase | Task | Command | Purpose |
|:---:|:---:|---------|---------|
| 0 | 0.1 | `go install github.com/initia-labs/weave@latest` | Install weave CLI |
| 0 | 0.2 | `weave rollup launch` | Deploy Settlement Minitia |
| 0 | 0.4 | `weave relayer start` | Start IBC relayer |
| 0 | 0.4 | `weave relayer channels` | Get IBC channel IDs |
| 1 | 1.1 | `forge init --no-commit --force .` | Initialize Foundry |
| 1 | 1.1 | `forge install OpenZeppelin/openzeppelin-contracts --no-commit` | Install OZ |
| 1 | 1.5 | `forge test --via-ir -vvv` | Run all contract tests |
| 1 | 1.6 | `forge script script/Deploy.s.sol:Deploy* ...` | Deploy contracts |
| 1 | 1.7 | `forge snapshot --via-ir` | Gas baseline |
| 2 | 2.1 | `cd frontend && npm install` | Install frontend deps |
| 2 | 2.1 | `cd frontend && npm run dev` | Start dev server |
| 4 | 4.2 | `npx tsx scripts/seed-demo.ts` | Seed demo data |
| 5 | 5.4 | `cd frontend && npm run build` | Production build |

### Troubleshooting

| Error | Likely Cause | Fix |
|-------|-------------|-----|
| `weave: command not found` | Go bin not in PATH | `export PATH=$PATH:$(go env GOPATH)/bin` |
| `forge build` stack-too-deep | Complex contract with `via_ir` | Try without `--via-ir` for testing |
| IBC packet timeout | Relayer down or chain halted | Restart relayer: `weave relayer restart` |
| `execute_cosmos` reverts | Wrong JSON format or insufficient funds | Check JSON escaping and contract balance |
| Frontend can't connect wallet | InterwovenKit config mismatch | Verify chain IDs match between config and running chains |
| `setDenom` needed | IBC denom on destination is `ibc/HASH` | Query bank balance, call `setDenom` with actual hash |
| Auto-sign not working | authz grant expired or wrong msg types | Re-enable auto-sign, check message type URLs |
| StreamCounter not animating | `useRef` not `useState` | Verify BridgeVisualization and useStreamTick use refs |
| Gas snapshot check fails | Gas regression from code changes | Run `forge snapshot --via-ir` to update baseline |

### Decision Tree Summary

| Risk # | Severity | Decision Point | Plan Location |
|:---:|:---:|---|---|
| 1 | CRITICAL | IBC relayer setup | Phase 0, Task 0.4 |
| 2 | CRITICAL | Minitia deployment | Phase 0, Task 0.2 |
| 3 | HIGH | Auto-sign API | Phase 2, Task 2.3 |
| 4 | HIGH | IBC latency | Phase 4, Task 4.3 |
| 5 | HIGH | Oracle pair availability | Phase 0, Task 0.6 |
| 8 | HIGH | IBC hook execution | Phase 1, Task 1.8 |
| 9 | MEDIUM | Faucet access | Phase 0, Task 0.1 |
| 10 | HIGH | Scope creep | Phase 5 (enforcement) |
| 13 | CRITICAL | Hook-to-IBC callback | Phase 0, Task 0.5 |
| 14 | HIGH | IBC denom mismatch | Phase 4, Task 4.4 |

### Architecture Doc Section Reference

| Section | Content | Referenced By |
|:---:|---------|---|
| 3 | Shared Types (`types/index.ts`) | Task 2.2 |
| 4 | ICosmos Interface | Task 1.2 |
| 5 | IConnectOracle Interface | Task 1.2 |
| 6 | HexUtils Library | Task 1.2 |
| 7 | StreamSender Contract | Task 1.3 |
| 8 | PaymentRegistry Contract | Task 1.3 |
| 9 | StreamReceiver Contract | Task 1.3 |
| 10 | Deploy Scripts | Task 1.4 |
| 11 | Contract Tests | Task 1.5 |
| 12 | Foundry Config | Task 1.1 |
| 13 | Frontend Config | Task 2.1 |
| 14 | Chain & Contract Config | Task 2.2 |
| 15 | Frontend Hooks | Task 2.3 |
| 16 | Frontend Components | Task 3.1 |
| 17 | Frontend Pages | Task 3.2 |
| 18 | App Shell | Task 3.3 |
| 19 | Seed Demo Script | Task 4.2 |
| 20 | Configuration Reference | Task 4.1 |
| 21 | Testing Strategy | Task 1.5 |
| 22 | Deployment Sequence | Task 1.6 |
| 23 | Addresses | Appendix |
| 24 | Integration Map | Task 4.3 |
| 25 | Acceptance Criteria | Task 4.5 |
| 26 | Security Considerations | Task 5.1 |
| 27 | Performance Budgets | Task 4.3 |
