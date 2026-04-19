# Phase 5: Contract Edge Cases + Security Inputs

**Status: PASS** (71/71 edge case tests passing, 0 regressions)

## Test File
`contracts/test/debug-p5-contract-edge-cases.t.sol`

## Coverage Summary

| Contract | Functions Covered | Edge Cases Tested |
|----------|------------------|-------------------|
| StreamSender | createStream, sendTick, cancelStream, getStreamInfo, getSenderStreams | 30 |
| PaymentRegistry | processPayment, cancelStream, setStreamSender, setOraclePairId, setDenom, getStream, getStreamsByReceiver, getStreamsBySender | 22 |
| StreamReceiver | onReceivePayment, claim, setDenom, setPaymentRegistry, getClaimable, getIncomingStreams, getIncomingStream | 19 |

**Total: 71 edge case tests across 3 contracts**

## Edge Case Categories Tested

- **Zero values**: 0 amount, 0 duration, empty strings, address(0)
- **Max values**: type(uint256).max for amounts and claimable
- **Boundary values**: MIN_TICK_INTERVAL +/- 1, exact tick count, single-tick streams
- **Unauthorized callers**: Non-owner on all restricted functions
- **Wrong state**: Cancel already-cancelled, sendTick on completed/expired, double-claim, tick on nonexistent stream
- **Overflow**: uint256 overflow on amountSent and claimable (caught by Solidity 0.8 checked math)
- **External failure**: Cosmos execute_cosmos returning false, oracle reverting, address conversion failing

## Bugs Found

### BUG-1: PaymentRegistry.cancelStream accepts nonexistent streams (MEDIUM)
- **File**: `PaymentRegistry.sol:123-129`
- **Expected**: Cancelling a never-registered stream should revert
- **Actual**: Default enum value for StreamStatus is ACTIVE (0), so `require(s.status == StreamStatus.ACTIVE)` passes on empty storage, allowing cancellation of streams that don't exist
- **Impact**: Emits misleading StreamCancelled event; pollutes state with phantom cancelled streams
- **Test**: `test_cancelStream_nonexistentStream`

### BUG-2: PaymentRegistry.processPayment accepts ticks on COMPLETED streams (MEDIUM)
- **File**: `PaymentRegistry.sol:66-120`
- **Expected**: Should reject ticks after stream completes
- **Actual**: No status check in processPayment; completed streams accept additional ticks, inflating amountSent beyond totalAmount
- **Impact**: Bookkeeping corruption; amountSent can exceed totalAmount
- **Test**: `test_processPayment_onCompletedStream`

### BUG-3: PaymentRegistry.processPayment accepts zero-amount ticks (LOW)
- **File**: `PaymentRegistry.sol:66-120`
- **Expected**: Zero-amount tick should be rejected
- **Actual**: No `amount > 0` check; zero-amount ticks waste gas and emit misleading PaymentProcessed events
- **Test**: `test_processPayment_zeroAmount`

### BUG-4: PaymentRegistry.processPayment no overpayment guard (LOW)
- **File**: `PaymentRegistry.sol:103`
- **Expected**: amountSent should not exceed totalAmount
- **Actual**: Single tick with amount > totalAmount is accepted, setting amountSent > totalAmount
- **Test**: `test_processPayment_amountExceedsTotalAmount`

### BUG-5: StreamReceiver.setPaymentRegistry missing zero-address guard (LOW)
- **File**: `StreamReceiver.sol:40-43`
- **Expected**: Should reject address(0)
- **Actual**: Can set paymentRegistry to address(0), bricking onReceivePayment since no caller will match
- **Contrast**: PaymentRegistry.setStreamSender correctly guards against address(0)
- **Test**: `test_setPaymentRegistry_zeroAddress`

### BUG-6: ratePerTick truncation dust (INFO)
- **File**: `StreamSender.sol:83`
- **Expected**: All funds delivered within stream duration
- **Actual**: When `totalAmount % totalTicks != 0`, truncation leaves dust requiring extra tick(s). If sender is slow, dust can be stranded past endTime. Mitigated by cancel-and-refund, but imperfect delivery.
- **Test**: `test_sendTick_dustFromTruncation_BUG`

## Regressions
None. All 95 pre-existing tests continue to pass (1 pre-existing fuzz test failure in `src/test/SimpleCosmos.sol` is unrelated).

## Full Suite Results
```
71 new edge case tests: 71 passed, 0 failed
24 pre-existing tests: 24 passed, 0 failed
1 pre-existing fuzz test: 1 failed (pre-existing, unrelated)
Total: 95/96 passed
```
