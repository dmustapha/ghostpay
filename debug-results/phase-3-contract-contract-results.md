# Phase 3: Integration Tests — Contract↔Contract Results

**Status: PASS**
**Tests: 20 total, 20 passed, 0 failed**
**Test file: `contracts/test/debug-p3-integration.t.sol`**

## Connection Points Tested

### 1. StreamSender → PaymentRegistry (processPayment) — 6 tests
| Test | Result |
|------|--------|
| sendTick calls registry processPayment | PASS |
| Multiple ticks accumulate in registry | PASS |
| Stream completes in both sender + registry | PASS |
| Revert: non-owner calls sendTick | PASS |
| Revert: stream expired | PASS |
| Revert: tick too soon | PASS |

### 2. PaymentRegistry → StreamReceiver (onReceivePayment) — 3 tests
| Test | Result |
|------|--------|
| sendTick credits receiver claimable | PASS |
| Multiple ticks accumulate in receiver | PASS |
| Revert: non-registry calls onReceivePayment | PASS |

### 3. StreamSender cancel → PaymentRegistry cancelStream — 3 tests
| Test | Result |
|------|--------|
| Cancel updates registry status to CANCELLED | PASS |
| Cancel without ticks succeeds (BUG — see below) | PASS |
| Revert: non-owner calls cancel | PASS |

### 4. PaymentRegistry Access Control — 2 tests
| Test | Result |
|------|--------|
| processPayment rejects non-StreamSender caller | PASS |
| cancelStream rejects non-StreamSender caller | PASS |

### 5. Contract↔Precompile (ICosmos failures) — 3 tests
| Test | Result |
|------|--------|
| execute_cosmos failure → sendTick reverts | PASS |
| execute_cosmos failure → cancel refund reverts | PASS |
| execute_cosmos failure → claim reverts | PASS |

### 6. Full E2E Flows — 3 tests
| Test | Result |
|------|--------|
| Create → 10 ticks → claim (all 3 contracts consistent) | PASS |
| Create → 3 ticks → cancel (partial stream) | PASS |
| Multiple independent streams, same sender | PASS |

## Bugs Found

### BUG-1: Stack-too-deep in `_sendToRegistry` (FIXED)
**File:** `contracts/src/StreamSender.sol`
**Severity:** Build-breaking (prevents compilation when all 3 contracts compiled together)
**Cause:** `_sendToRegistry` combined string concatenation for cosmos bank send JSON + 6 storage reads from `StreamInfo` + 9-param call to `processPayment` — exceeded Yul stack limit.
**Fix:** Split `_sendToRegistry` into two functions: `_sendTokensToReceiver` (cosmos bank send) and `_notifyRegistry` (registry call via `abi.encodeCall` + low-level `.call`). All existing tests continue to pass.

### BUG-2: `PaymentRegistry.cancelStream` accepts unregistered streams (NOT FIXED — documented)
**File:** `contracts/src/PaymentRegistry.sol` line 126
**Severity:** Low (no fund loss, bookkeeping only)
**Cause:** Default `StreamStatus` enum value (0) == `ACTIVE`. `cancelStream` checks `s.status == StreamStatus.ACTIVE`, which passes for streams that were never registered via `processPayment`.
**Impact:** A StreamSender can cancel a stream that was never registered, setting its status to CANCELLED. No token movement occurs (no funds at risk), but it creates a phantom cancelled stream entry.
**Recommended fix:** Add `require(s.startTime > 0, "Stream not registered")` in `cancelStream`.

## Source Changes Made

| File | Change |
|------|--------|
| `contracts/src/StreamSender.sol` | Refactored `_sendToRegistry` into `_sendTokensToReceiver` + `_notifyRegistry` to fix stack-too-deep |

## Full Test Suite Impact
- All 115 non-fuzz tests pass (20 new + 95 existing)
- 1 pre-existing fuzz test failure in `SimpleCosmos.sol` (unrelated)
