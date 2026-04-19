# Phase 7 — Contracts Senior Dev Critique

**Reviewed:** StreamSender.sol, PaymentRegistry.sol, StreamReceiver.sol, ICosmos.sol, IConnectOracle.sol, HexUtils.sol, Deploy.s.sol
**Context:** DEV-007 single-chain deployment (direct EVM calls, no IBC)

---

## MUST-FIX (3)

### M1. cancelStream reverts on never-registered stream (PaymentRegistry:126)
**File:** `contracts/src/PaymentRegistry.sol:126`
If a user creates a stream in StreamSender and cancels it *before* the first `sendTick`, `cancelStream` calls `IPaymentRegistry(paymentRegistry).cancelStream(streamId)` (StreamSender:156). In the Registry, `s.status` will be `StreamStatus.ACTIVE` (enum default = 0), so the status check passes — but `s.startTime == 0` meaning this stream was never registered. The function silently "cancels" a phantom stream. While it won't revert, it emits a misleading `StreamCancelled` event with `amountSent: 0` for a stream that doesn't actually exist in the registry's mappings (no sender/receiver arrays entry). Receivers polling `getStreamsByReceiver` won't see it, but event-based indexing could show phantom cancellations.

**Demo risk:** If demo shows a cancel-before-first-tick flow, the event log will look wrong. Low probability in a 3-min demo but fragile.

**Fix:** Add a guard in `PaymentRegistry.cancelStream`:
```solidity
require(s.startTime != 0, "Stream not registered");
```

### M2. Dust loss from integer division in ratePerTick (StreamSender:83)
**File:** `contracts/src/StreamSender.sol:83`
`ratePerTick = amount / totalTicks` truncates. For example, 100 tokens over 3 ticks = 33 per tick, 99 sent, 1 token permanently locked. The last tick sends `remaining` (line 117) which covers this — but only if the stream runs to completion. If cancelled after tick 2, `refund = totalAmount - amountSent = 100 - 66 = 34`, which is correct. However, `totalReserved` was incremented by `amount` (100) and decremented by ticks (33+33=66) + cancel refund path decrements `totalAmount - amountSent` (34). So 66+34=100, accounting is correct.

**Actually OK on accounting.** But: if `amount=10`, `durationSeconds=300`, then `totalTicks=10`, `ratePerTick=1` — fine. But `amount=10`, `durationSeconds=301` → `totalTicks=10`, `ratePerTick=1`, and the extra second is silently ignored (stream ends at `startTime+301` but all funds sent by tick 10). This is cosmetic.

**Downgrading to SHOULD-FIX.** Removing from MUST-FIX count.

### M2 (revised). `sendTick` callable by anyone after stream expires — no auto-complete (StreamSender:113)
**File:** `contracts/src/StreamSender.sol:113`
`require(block.timestamp <= s.endTime, "Stream expired")` prevents ticks after expiry. But if a stream expires with unsent funds (e.g., user didn't call enough ticks), those funds are permanently locked — `totalReserved` still counts them, and there's no `finalizeStream` or expiry-reclaim function. The sender can't cancel (stream must be active + not expired won't help since `cancelStream` doesn't check time). Actually, `cancelStream` only checks `s.active` — so sender CAN cancel an expired stream to reclaim. This is fine.

**Revised analysis:** The real issue is that `sendTick` has `require(block.timestamp <= s.endTime)` but the last tick should still be sendable even after endTime to flush remaining funds. If the user's last setInterval fires 1 second after endTime, the stream is stuck with unsent funds and the user must manually cancel.

**Demo risk:** A 60-second demo stream that drifts by even 1 second past endTime will fail to complete, showing an error in the demo.

**Fix:** Change to `require(s.active, "Stream not active")` only — remove the endTime check, or change to a soft check that still allows the final tick.

### M3. `receive() external payable {}` is dead code on minievm (all 3 contracts)
**File:** `contracts/src/StreamSender.sol:203`, `PaymentRegistry.sol:174`, `StreamReceiver.sol:124`
Per DEV-008, "msg.value doesn't work on minievm (EVM balance always 0)." The `receive()` fallback accepts ETH that can never arrive. Not a crash risk but misleading — a user sending native ETH thinking it funds the contract will lose nothing (it just won't work) but it's confusing.

**Demo risk:** None directly, but if someone tries to fund via MetaMask "send ETH" it silently does nothing.

**Downgrading to NOTE.**

---

## Revised MUST-FIX (2)

### M1. cancelStream on never-registered stream emits phantom event
**File:** `contracts/src/PaymentRegistry.sol:126`
See above.

### M2. sendTick rejects after endTime — final tick may fail in demo
**File:** `contracts/src/StreamSender.sol:113`
`require(block.timestamp <= s.endTime)` — if the frontend's setInterval drifts past endTime by even 1 second, the final tick reverts. For a short demo stream (60-120s), this timing edge case is very likely.

**Fix:** Remove or relax the endTime guard:
```solidity
require(s.active, "Stream not active");
// Allow ticks after endTime to flush remaining funds
```

---

## SHOULD-FIX (5)

### S1. HexUtils library is dead code
**File:** `contracts/src/lib/HexUtils.sol`
Not imported by any contract. The ARCHITECTURE.md dependency graph claims StreamSender and PaymentRegistry use it, but they don't. Should be removed to avoid confusion during judging.

### S2. Duplicate `ICosmos` constant across all 3 contracts
**Files:** StreamSender:30, PaymentRegistry:15, StreamReceiver:10
`ICosmos constant COSMOS = ICosmos(0x...f1)` is defined identically in 3 places. Should be in a shared base or imported from ICosmos.sol.

### S3. Inconsistent access control pattern — no `onlyOwner` modifier
**Files:** PaymentRegistry (lines 144, 150, 155), StreamReceiver (lines 36, 41)
Each admin function repeats `require(msg.sender == owner, "Not owner")`. Standard practice is an `onlyOwner` modifier or using OZ Ownable. Minor but looks amateur during code review.

### S4. Integer division dust in ratePerTick
**File:** `contracts/src/StreamSender.sol:83`
`ratePerTick = amount / totalTicks` truncates. The final tick handles this via `min(ratePerTick, remaining)` (line 117), so funds aren't lost. But `totalTicks * ratePerTick < amount` means the stream needs `totalTicks + 1` ticks to fully drain. If the frontend only fires `totalTicks` ticks, the stream won't complete. Frontend must tick until `amountSent >= totalAmount`, not count ticks.

### S5. No event on stream registration in processPayment
**File:** `contracts/src/PaymentRegistry.sol:100`
`StreamRegistered` event is emitted on first tick — this is correct. But `processPayment` creates the stream AND processes the first tick in one call without separating concerns. If the registry call fails on tick 1, the entire tick (including the cosmos bank send that was already queued) becomes inconsistent. DEV-009 notes explain this is expected, but it means the token send succeeds while bookkeeping fails — funds arrive at StreamReceiver without a registry entry.

---

## NOTE (4)

### N1. `receive() external payable {}` on all contracts is misleading on minievm
See M3 analysis above. Not harmful but confusing.

### N2. No reentrancy guard on claim()
**File:** `contracts/src/StreamReceiver.sol:81-100`
`claim()` zeroes balance before the cosmos call (CEI pattern), so reentrancy is not exploitable. But `execute_cosmos` is an external precompile call — adding a nonReentrant guard would be defense-in-depth. Not needed for demo.

### N3. Hardcoded gas limit (500000) for execute_cosmos
**Files:** StreamSender:153, StreamSender:189, StreamReceiver:97
`500000` gas for cosmos execution is hardcoded in 3 places. If the chain adjusts gas costs, all 3 need updating. Should be a configurable parameter. Not a demo risk since the current value works.

### N4. Architecture diagram is stale
**File:** `ARCHITECTURE.md`
The diagram shows 3 contracts on 3 separate chains (Rollup A, Settlement, Rollup B) with IBC between them. DEV-007 consolidates everything to one chain. The architecture doc should be updated to match reality, especially for hackathon judges reviewing docs.

---

## Summary

| Severity | Count |
|----------|-------|
| MUST-FIX | 2 |
| SHOULD-FIX | 5 |
| NOTE | 4 |

### All MUST-FIX items:
| ID | File | Line | Issue |
|----|------|------|-------|
| M1 | PaymentRegistry.sol | 126 | cancelStream on unregistered stream emits phantom event |
| M2 | StreamSender.sol | 113 | sendTick rejects after endTime — final tick may fail during demo |
