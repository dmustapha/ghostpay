# concerns.md — GhostPay

## CRITICAL [C]
[C] Demo failure: Cross-rollup payment stream must work end-to-end (Rollup A → Settlement → Rollup B) without manual intervention
[C] Integration failure: IBC relayer must be running and settlement Minitia must be producing blocks during demo
[C] Auto-signing failure: Ghost wallet must fire micro-transactions without user wallet popups
[C] Submission compliance: Own rollup deployed with chain ID, InterwovenKit integrated, auto-signing + bridge as native features, .initia/submission.json complete
[C] Day 1 go/no-go: If Minitia deploy + IBC relayer both fail by EOD 1, must switch to L1-only fallback

## IMPORTANT [I]
[I] Scope creep: Core feature set locked — no additions during build. Stream creation + visualization + bridge crossing only.
[I] Oracle integration: USD conversion must display correctly on streams — oracle feed must be enabled and queried
[I] Demo data: Pre-seeded streams with visible activity for demo recording — not starting from empty state
[I] Code quality: Solidity contracts must compile and deploy without errors. Frontend must build without warnings.
[I] Time budget: Feature-freeze Day 6. Demo prep Days 7-8. No exceptions.

## ADVISORY [A]
[A] Polish: UI animations are advisory — function and demo flow take priority over visual polish
[A] .init usernames: Nice-to-have display feature, not required for core flow
[A] Multi-stream convergence: Bonus demo moment if time permits, not core requirement
