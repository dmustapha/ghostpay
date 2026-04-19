# Phase 5: Frontend Edge Cases — GhostPay

## Summary

| Severity | Count |
|----------|-------|
| BUG      | 5     |
| WARNING  | 7     |
| NOTE     | 4     |

---

## BUGs (will crash or show wrong data during demo)

### BUG-1: Contract addresses default to zero address — all reads silently return empty/zero
**File:** `frontend/src/config/contracts.ts:5-7`
**Issue:** `STREAM_SENDER_ADDRESS`, `STREAM_RECEIVER_ADDRESS`, and `PAYMENT_REGISTRY_ADDRESS` all fall back to `0x0000000000000000000000000000000000000000` when env vars are missing. The viem `readContract` calls will succeed against the zero address but return garbage/zero data, making the app look "working" but showing nothing. No warning is surfaced to the user or developer.
**Impact:** During demo, if `.env` is misconfigured the entire app silently shows zero streams and zero balances with no indication of misconfiguration.

### BUG-2: Dashboard claim button has no loading/disabled state — double-click fires duplicate tx
**File:** `frontend/src/pages/Dashboard.tsx:40-62`
**Issue:** The "Claim Funds" button's `onClick` handler is an async function with no `isLoading` guard. Clicking twice rapidly fires two `wallet.submitTxBlock` calls. Unlike `CreateStream` (which has `isCreating` guard), Dashboard claim has none.
**Impact:** Double-click during demo submits duplicate claim transactions.

### BUG-3: Dashboard claim has no error handling — unhandled promise rejection on tx failure
**File:** `frontend/src/pages/Dashboard.tsx:42-56`
**Issue:** The `onClick` handler does `await wallet.submitTxBlock(...)` with no try/catch. If the transaction fails (network error, contract revert), the promise rejection is unhandled. This will trigger a console error and potentially crash React's error boundary if one exists.
**Impact:** Any claim failure during demo shows uncaught error in console; no user feedback.

### BUG-4: `getSenderStreams` passes bech32 address as EVM address type
**File:** `frontend/src/hooks/useStreams.ts:24-28`
**Issue:** `senderAddress` comes from `VITE_DEMO_SENDER_ADDRESS` (likely a bech32 `init1...` address for Initia). It is cast as `` `0x${string}` `` and passed to `getSenderStreams(address)` which expects a Solidity `address` type. A bech32 string is not a valid EVM address — this call will revert or return empty.
**Impact:** Streams will never load if the sender address is bech32 format. The Dashboard and DemoView will always show "No streams."

### BUG-5: `getClaimable` passes bech32 receiver address as EVM address type
**File:** `frontend/src/hooks/useStreams.ts:70-75`
**Issue:** Same as BUG-4 but for `receiverAddress` in `useClaimableBalance`. The `VITE_DEMO_RECEIVER_ADDRESS` is likely bech32, but `getClaimable(address)` expects an EVM `address`. The call will fail silently (returns 0n) or revert.
**Impact:** Claimable balance always shows 0 during demo.

---

## WARNINGs (code quality issue, may cause problems)

### WARNING-1: StreamCounter interpolation can overshoot total amount
**File:** `frontend/src/components/StreamCounter.tsx:23-27`
**Issue:** The client-side interpolation (`baseValueRef.current + increment`) has no cap against the stream's `totalAmount`. Between poll intervals, the counter can display a value exceeding the total deposited amount.
**Impact:** Visually misleading — streamed amount may briefly exceed total before next poll corrects it.

### WARNING-2: `submitTxBlock` in App.tsx is a no-op — only logs
**File:** `frontend/src/App.tsx:30-33`
**Issue:** The demo `submitTxBlock` just logs and sets `lastTickTime`. It does not actually submit transactions. `CreateStream.handleCreate` calls `submitTxBlock` then navigates to `/` assuming success, but no stream was actually created on-chain.
**Impact:** In demo mode this is intentional, but there's no clear path to swap in real tx submission. The 2-step flow (bank send then createStream) is documented in the UI text but not enforced or guided.

### WARNING-3: `useStreamTick` is imported nowhere — dead code
**File:** `frontend/src/hooks/useStreamTick.ts`
**Issue:** No component imports or uses `useStreamTick`. The auto-tick mechanism is defined but never wired into the UI. Without this, streams cannot auto-advance on-chain during the demo.
**Impact:** The core "ghost wallet auto-signing ticks" feature is not actually connected. Streams will not progress unless manually ticked.

### WARNING-4: DemoView claim button is a no-op
**File:** `frontend/src/pages/DemoView.tsx:77-80`
**Issue:** The claim button in DemoView only does `console.log(...)`. It has no wallet integration, unlike the Dashboard claim button. During a demo, clicking "Claim Funds" on the receiver side does nothing visible.
**Impact:** Demo narrative breaks if presenter clicks claim on the receiver panel.

### WARNING-5: Oracle fallback uses ETH/USD price for INIT token
**File:** `frontend/src/hooks/useOracle.ts:13-16`
**Issue:** If `INIT/USD` oracle returns non-OK, the fallback queries `ETH/USD` and uses that price. ETH and INIT have vastly different prices. All USD values will be wildly incorrect.
**Impact:** Misleading USD values during demo if INIT/USD is unavailable.

### WARNING-6: BridgeVisualization packets accumulate unbounded
**File:** `frontend/src/components/BridgeVisualization.tsx:21`
**Issue:** Each `lastTickTime` change pushes a new packet. While completed packets are filtered out, if ticks come fast or the filter has timing issues, the packet array grows. The 50ms interval re-renders the entire packet list every tick.
**Impact:** Minor performance concern during long demo sessions.

### WARNING-7: `StreamCard` accesses `stream.sender?.slice(0,12)` with optional chain but `sender` is typed as `string` (not optional)
**File:** `frontend/src/components/StreamCard.tsx:37`
**Issue:** The optional chaining `stream.sender?.slice(0, 12)` suggests `sender` might be undefined, but the `StreamView` type declares it as `string`. If the contract returns an empty string, the display shows `...` which is confusing but not a crash.
**Impact:** Minor display issue with empty sender strings.

---

## NOTEs (minor concern, no immediate impact)

### NOTE-1: No network switch handling
**Issue:** There is no chain ID validation or network switch detection. If the user switches networks mid-session, RPC calls go to the wrong chain silently. For a demo this is acceptable since there's no real wallet integration yet.

### NOTE-2: No input validation on CreateStream form fields
**File:** `frontend/src/pages/CreateStream.tsx:43`
**Issue:** `BigInt(amount)` will throw if `amount` contains non-numeric characters (e.g., decimals from the number input). The `type="number"` input allows decimals and negative values. The regex check on line 72 only guards the preview, not the submit.
**Impact:** Entering "1.5" or "-100" and clicking submit will throw an uncaught BigInt conversion error.

### NOTE-3: Missing key prop is NOT an issue
All `.map()` calls use proper `key` props (`stream.streamId`, `p.id`).

### NOTE-4: useEffect cleanup is properly implemented
Both `useStreamTick` and `StreamCounter` properly clean up intervals on unmount. `BridgeVisualization` also cleans up its animation interval.

---

## 2-Step Flow Analysis

The UI mentions the 2-step flow in a help text on line 116 of `CreateStream.tsx`:
> "Note: You must pre-fund the StreamSender contract via cosmos bank send before creating."

However, the UI does not:
- Guide the user through the bank send step
- Verify the contract has sufficient funds before calling createStream
- Show the bank send command or provide a button for it

This is a **WARNING-2** concern — the feature is documented but not implemented in the UI flow.

## Contract Address Configuration

All three contract addresses (`STREAM_SENDER_ADDRESS`, `STREAM_RECEIVER_ADDRESS`, `PAYMENT_REGISTRY_ADDRESS`) default to zero address. See **BUG-1**.

## Oracle Graceful Degradation

The `formatUsdValue` function correctly returns `$?.??` when `price === 0n` or price is null/undefined (line 41 of `useOracle.ts`). The oracle hook returns `null` on any fetch failure. UI components conditionally render USD values only when `oraclePrice` is truthy. This is handled well.
