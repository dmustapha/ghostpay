# Phase 2: Known Risks Triage — GhostPay

Generated: 2026-04-18
Test file: `contracts/test/KnownRisks.t.sol` (9/9 passing)

## Risk Triage Table

| # | Risk | Classification | Disposition | Details |
|---|------|---------------|-------------|---------|
| 1 | Oracle feed inactive on local minitias — ETH/USD returns price=0 | TESTABLE | RISK-CLEARED | `_getUsdValue()` in PaymentRegistry handles both `oracleAddress==address(0)` (returns 0) and oracle revert (try/catch returns 0). Two tests confirm: `test_risk1_oracleInactive_returnsZeroUsd` and `test_risk1_oracleReverts_gracefulDegradation`. Payments process normally with usdValue=0. |
| 2 | Relayer key on L1 has 3 INIT — may need topping up | EXTERNAL | RISK-ACCEPTED | Relayer balance is an L1 operational concern. Mitigation: top up relayer key before demo via `initiad tx bank send`. DEV-007 means all contracts are single-chain, so IBC relaying is only needed for L1-Settlement bridge (token transfers). 3 INIT is sufficient for short demo. |
| 3 | All contracts on single chain (Settlement) — cross-chain narrative weakened | STRUCTURAL | RISK-ACCEPTED | DEV-007 is a deliberate architecture decision. Verified: all 3 contracts (StreamSender, PaymentRegistry, StreamReceiver) deploy and interact correctly on the same chain via direct EVM calls. No IBC hooks involved. Cross-chain narrative is addressed in documentation/submission by explaining the hub-and-spoke topology constraint. Code is correct for single-chain deployment. |
| 4 | `execute_cosmos` queued msg execution — no mid-EVM cosmos state changes | STRUCTURAL | RISK-CLEARED | Verified code ordering in `_sendToRegistry()`: (1) `execute_cosmos` queues the cosmos bank send, (2) `processPayment` does EVM bookkeeping, (3) `onReceivePayment` credits claimable balance. The cosmos bank send executes after EVM returns but before any subsequent tx. This is correct because: StreamSender sends tokens directly to StreamReceiver (DEV-009), so no chained cosmos sends exist. `test_risk4_sendTickCallOrder` confirms the full flow completes. |
| 5 | StreamSender must be pre-funded via cosmos bank send before createStream | TESTABLE | RISK-CLEARED | `createStream()` does not transfer tokens — it only records a reservation via `totalReserved`. Tokens move only on `sendTick()` via cosmos bank send. Tests confirm: `test_risk5_createStream_noTransfer_justReservation` (amountSent=0 at creation) and `test_risk5_multipleStreams_reservationsStack` (reservations accumulate correctly). Frontend must handle the 2-step flow (fund then create), but the contract logic is sound. |
| 6 | sendTick requires 2M gas (DEV-010) | TESTABLE | RISK-CLEARED | Full call chain verified in forge test: `sendTick` -> `_sendToRegistry` -> `execute_cosmos` + `processPayment` -> `onReceivePayment`. `test_risk6_sendTickFullCallChain` confirms the entire chain executes and receiver gets credited. On-chain gas_used was 472K (per BUILD-REPORT 4.3), so 2M gas limit provides ~4x headroom. Wallet/InterwovenKit must set `gas: 2000000`. |
| 7 | Deployer key derivation mismatch (DEV-012) | STRUCTURAL | RISK-CLEARED | Verified: contracts use `owner = msg.sender` pattern. The deployer address only matters for `owner`-gated admin functions (`setStreamSender`, `setPaymentRegistry`, `setDenom`, `setOraclePairId`). Once these are set during deployment/seed, the deployer address is irrelevant for runtime operations. `test_risk7_contractsIndependentOfDeployer` confirms contracts work identically regardless of deployer. Seed script correctly uses the keyring-derived (coin_type 118) address. |

## Summary

| Disposition | Count |
|-------------|-------|
| RISK-CLEARED | 5 |
| RISK-HARDENED | 0 |
| RISK-DISMISSED | 0 |
| RISK-ACCEPTED | 2 |

**Bugs found: 0**

All 7 known risks have been triaged. 5 risks were verified with passing tests (9/9 in `KnownRisks.t.sol`). 2 risks are external/structural concerns with documented mitigations (relayer balance and single-chain architecture). No code fixes were needed — the existing implementation handles all risks correctly.

## Test Results

```
Ran 9 tests for test/KnownRisks.t.sol:KnownRisksTest
[PASS] test_receiverRejectsUnauthorizedCaller()
[PASS] test_registryRejectsUnauthorizedCaller()
[PASS] test_risk1_oracleInactive_returnsZeroUsd()
[PASS] test_risk1_oracleReverts_gracefulDegradation()
[PASS] test_risk4_sendTickCallOrder()
[PASS] test_risk5_createStream_noTransfer_justReservation()
[PASS] test_risk5_multipleStreams_reservationsStack()
[PASS] test_risk6_sendTickFullCallChain()
[PASS] test_risk7_contractsIndependentOfDeployer()
Suite result: ok. 9 passed; 0 failed; 0 skipped
```
