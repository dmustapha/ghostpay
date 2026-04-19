# Phase 7 — Frontend Senior Dev Critique

**Domain:** Frontend (React + Vite + Tailwind)
**Date:** 2026-04-18
**Reviewer:** Phase 7 Subagent

---

## Summary

| Severity | Count |
|----------|-------|
| MUST-FIX | 4 |
| SHOULD-FIX | 5 |
| NOTE | 3 |

---

## MUST-FIX (demo-visible, could crash)

### MF-1: CreateStream passes wrong signature to submitTxBlock
**File:** `frontend/src/pages/CreateStream.tsx:50`
**Issue:** `CreateStream` calls `submitTxBlock({ msgs: [...] })` (object with `msgs` key), but `App.tsx:50` passes the Dashboard wallet a function `(chainId, msgs) => submitTxBlock({ msgs })`. The CreateStream component receives `submitTxBlock` directly from App (line 62), which expects `{ msgs }` — but it never passes `chainId`. Meanwhile Dashboard's wallet wrapper expects `(chainId, msgs)`. The two call conventions are inconsistent. During demo, CreateStream's `submitTxBlock` call will work (it's the raw function), but the Dashboard claim path uses `wallet.submitTxBlock(chainId, msgs)` which wraps it. If anyone tries to wire real InterwovenKit, these mismatched signatures will cause silent failures or type errors.
**Impact:** Demo mode works by accident (console.log stub). Real wallet integration will break immediately.
**Fix:** Standardize on one signature. Either always `(chainId, msgs)` or always `{ chainId, msgs }`.

### MF-2: StreamCounter interpolation drifts unbounded past totalAmount
**File:** `frontend/src/components/StreamCounter.tsx:24-27`
**Issue:** The client-side interpolation calculates `increment = elapsed * ratePerSecond` with no upper bound. If the on-chain poll is slow or the stream has ended, the counter will show a value higher than `totalAmount`. During a 3-minute demo, this means the "Streamed" counter can exceed the "Total" amount, which looks like a bug to judges.
**Fix:** Clamp: `setDisplayValue(min(baseValueRef.current + increment, totalAmount))`. Requires passing `totalAmount` as a prop or adding a `max` prop.

### MF-3: BigInt precision loss in StreamCounter and StreamCard
**File:** `frontend/src/components/StreamCounter.tsx:34`, `StreamCard.tsx:69-71`
**Issue:** `Number(displayValue) / 1e6` — if `displayValue` exceeds `Number.MAX_SAFE_INTEGER` (9e15 in micro-units = 9 billion MIN), precision is silently lost. While unlikely in demo with small amounts, the pattern is unsafe. More critically, `Number((stream.amountSent * 100n) / stream.totalAmount)` in StreamCard.tsx:14 will produce `NaN` if `totalAmount` is `0n` despite the guard, because `0n > 0n` is false but the division by zero is on the same line as the ternary. Wait — actually the ternary guards it. However, if both are 0n the progress bar shows 0 which is correct. **Revised:** The real issue is `rate / 30n` in StreamCounter line 25 — integer division. If rate is e.g. `29n`, `rate / 30n = 0n` and the counter never animates. For small stream amounts in a demo, the counter will appear frozen.
**Fix:** Use sub-bigint math: compute in a larger unit then scale down, or use Number for the interpolation (safe for demo amounts).

### MF-4: No index.css / Tailwind base styles verified
**File:** `frontend/src/main.tsx:4`
**Issue:** `main.tsx` imports `./index.css` but this file was not in the review list. If it's missing or doesn't include Tailwind directives (`@tailwind base; @tailwind components; @tailwind utilities;`), the entire UI renders as unstyled HTML. Also, `ghost-500`, `ghost-600` are custom Tailwind colors used throughout (Layout, Dashboard, StreamCard, CreateStream, BridgeVisualization) — if `tailwind.config.js` doesn't define them, those classes are silently dropped and buttons/accents are invisible.
**Fix:** Verify `index.css` has Tailwind directives and `tailwind.config.js` defines `ghost` color palette. This is the #1 "app looks broken" risk.

---

## SHOULD-FIX (code quality, no direct demo crash)

### SF-1: Oracle fallback from INIT/USD to ETH/USD is misleading
**File:** `frontend/src/hooks/useOracle.ts:13-16`
**Issue:** If INIT/USD oracle is unavailable (likely on a local testnet), it silently falls back to ETH/USD price. This means all USD values displayed are wildly incorrect (ETH price applied to MIN amounts). During demo, "$3,200.00" next to "1 MIN" would confuse judges.
**Fix:** Either show no USD value when INIT/USD is unavailable, or use a hardcoded demo price.

### SF-2: PAYMENT_REGISTRY_ABI exported but never used
**File:** `frontend/src/config/contracts.ts:152-190`
**Issue:** `PAYMENT_REGISTRY_ABI` and `PAYMENT_REGISTRY_ADDRESS` are exported but zero components import or use them. Dead code that adds 40 lines of noise.
**Fix:** Remove or add a `// TODO: wire for registry view` comment.

### SF-3: Unused StreamStatus enum and multiple unused types
**File:** `frontend/src/types/index.ts:1-5, 21-35, 37-43, 60-66`
**Issue:** `StreamStatus`, `RegistryStream`, `IncomingStream`, `CreateStreamParams` are defined but never imported anywhere in the frontend. Dead types.
**Fix:** Remove or keep only if planned for use.

### SF-4: autoSign state in CreateStream is disconnected from App
**File:** `frontend/src/pages/CreateStream.tsx:25, 28-35, 149-156`
**Issue:** `CreateStream` maintains its own `autoSignEnabled` local state, but the `autoSign.enabled` prop from App is never checked or synced. The "Enable Ghost Wallet" button calls `autoSign.enable()` (a console.log no-op) and flips local state, but if the user navigates away and back, the state resets. During demo this is cosmetic only, but it's a false affordance — the button pretends to do something.
**Fix:** Either remove the auto-sign button from demo mode, or sync with App-level state.

### SF-5: No error boundary — unhandled RPC errors crash the app
**File:** `frontend/src/App.tsx` (entire tree)
**Issue:** No React error boundary wraps the app. If the RPC endpoint is unreachable (e.g., localhost:8545 not running), viem's `readContract` throws, React Query retries 2x, then the error propagates. `useQuery` won't crash React, but any render-time access of `data` properties without null checks could. Currently the code handles this OK with optional chaining, but one missed check crashes the whole app with a white screen.
**Fix:** Add a top-level `<ErrorBoundary>` component with a "something went wrong" fallback.

---

## NOTE (future concerns)

### N-1: EVM chain ID defaults to 1 (mainnet)
**File:** `frontend/src/config/chains.ts:7`
**Issue:** `Number(import.meta.env.VITE_SETTLEMENT_EVM_CHAIN_ID || 1)` — defaulting to chain ID 1 (Ethereum mainnet) is technically wrong for a Minitia. If MetaMask or any wallet extension is present, it may try to switch to mainnet. Low risk for demo mode with no real wallet, but a footgun.

### N-2: Packet animation never triggers in demo mode
**File:** `frontend/src/components/BridgeVisualization.tsx:18-21`
**Issue:** `lastTickTime` only updates when `submitTxBlock` is called in App.tsx:32. But in demo mode, no ticks are actually fired (useStreamTick is unwired). The bridge visualization will always show "No streams" with zero animation. The visual centerpiece of the demo (per PRD) is inert.
**Workaround:** Either wire useStreamTick into DemoView, or add a simulated tick timer for demo mode.

### N-3: receiverAddress in DemoView queries with bech32 address
**File:** `frontend/src/pages/DemoView.tsx:15`
**Issue:** Same class as known BUG-4/BUG-5 (bech32-as-EVM). `useClaimableBalance(receiverAddress)` passes the bech32 `VITE_DEMO_RECEIVER_ADDRESS` to a contract that expects an EVM address. Already documented as known, but noting it affects DemoView specifically — the receiver panel will always show 0 claimable.

---

## Cross-Cutting Observations

**Demo readiness:** The demo flow (navigate to /demo, see split screen) will render but be mostly static. The bridge animation won't animate, the counter won't tick, and claim is a no-op. For a 3-minute hackathon demo, the app will look like a mockup rather than a working product. The PRD emphasizes "money visibly leaving one rollup, crossing through the settlement layer" as the visual centerpiece — this is currently broken.

**Positive notes:** Error handling in CreateStream is solid (try/catch, error display, loading state). Component decomposition is clean. TanStack Query usage is correct. The code is well-commented with DEV-xxx markers showing architectural decisions were tracked.
