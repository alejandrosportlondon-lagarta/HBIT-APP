# HBIT v1 — Task Breakdown

Work top to bottom. Do not start a milestone until the previous one's exit criteria pass.
PRD reference: `docs/PRD.md`. Conventions: `CLAUDE.md`.

## Milestone 0 — Project foundation (week 1–2)

- [x] Xcode project: SwiftUI app target `HBIT`, iOS 17 min, Swift 6 strict concurrency *(checked-in `HBIT.xcodeproj`, Xcode 16+ — see ADR 001)*
- [x] Local SPM packages scaffolded: `AlarmEngine`, `ProofKit`, `MorningKit`, `SyncKit`, `PaywallKit` — each with a test target
- [x] SwiftData models: `Morning`, `Mission`, `AlarmConfig`, `ProofReference`, `StreakState`
- [ ] Supabase project: schema migration for `profiles`, `mornings`, `missions`, `proof_references`; RLS policies (users read/write only their own rows) *(migration written in `supabase/migrations/`; **blocked**: needs an HBIT Supabase project to apply it to)*
- [ ] Auth: Sign in with Apple + email magic link (Supabase Auth) *(client implemented; **blocked**: needs Supabase keys + Apple provider config + Apple Developer App ID)*
- [x] Design tokens: colors (#0F1115 bg, #181B22 surface, #4ADE80 primary, #FF6B35 accent, #22C55E success, #F8FAFC text, #94A3B8 secondary), type scale, spacing scale — as a `DesignSystem` enum
- [x] CI: GitHub Actions — build + test on PR
- [x] Sentry + PostHog SDK integrated behind a `Telemetry` facade (no direct SDK calls in features) *(keys come later via `Config.xcconfig`; backends stay disabled until then)*
- [x] `docs/analytics-events.md` created with initial funnel events

**Exit criteria:** app builds, signs in, writes a dummy Morning locally and syncs it to Supabase; CI green.

## Milestone 1 — Alarm engine + reliability harness (week 3–4) ← HIGHEST RISK, DO FIRST

- [x] `AlarmScheduler`: schedules a notification chain (repeating every 30–60s for up to 30 min) for a target time; cancels chain on dismissal *(`NotificationChainPlan` + `UserNotificationScheduler`, unit-tested)*
- [x] Alarm audio: looping, volume-ramping sound via AVFoundation when app is foreground/launched from notification
- [x] Full-screen dismiss UI launched from notification tap; alarm state machine: `scheduled → ringing → proofInProgress → dismissed | emergencyExited | expired` *(state machine exhaustively unit-tested; proof step is a placeholder until Milestone 2)*
- [x] Restart resilience: if device reboots or app is killed while ringing, next app launch within the ring window resumes ringing state *(persisted snapshot + `RingWindow` resume; needs physical-device confirmation in the dogfood)*
- [x] Reliability test harness: a debug screen + UI test plan covering: app killed, silent switch on, Focus/DND on, Low Power Mode, storage-full notification limits, DST boundary alarms *(harness screen in Debug builds; plan in `docs/testing/alarm-reliability-test-plan.md`; manual runs pending)*
- [x] `docs/decisions/001-alarm-reliability.md` ADR documenting the chosen strategy and its known limits *(lives at `002-alarm-reliability.md` — 001 was taken)*
- [x] Critical alerts entitlement request drafted (needs founder's Apple developer account to submit) *(`docs/critical-alerts-entitlement-request.md`)*

**Exit criteria:** 7-day manual dogfood with zero missed alarms across ≥ 2 physical devices; all harness scenarios documented pass/fail.

## Milestone 2 — Proof system, part 1 (week 5–6)

- [x] `Proof` protocol in ProofKit: `configure() → ProofReference`, `verify() async → ProofResult` *(realized as `ProofConfig` payloads + per-proof session state machines — the package can't see the app's SwiftData `ProofReference`, so it owns the payload half)*
- [x] Math proof: 3 difficulty levels, generated locally, keyboard UX usable half-asleep (large targets)
- [x] Steps proof: CoreMotion pedometer, walk N steps (configurable 10–100), live count on screen *(pedometer needs a physical device; Debug builds have a step-injection button for the simulator)*
- [x] Barcode/QR proof: register any code via camera; dismissal scan must match registered payload; fully offline
- [x] Proof selection + configuration flow in alarm settings *(in the home alarm card; barcode labelled Pro — paywall enforcement is Milestone 5)*
- [x] Unit tests: proof state machines; barcode payload matching edge cases *(incl. UPC-A ↔ EAN-13 leading-zero equivalence)*

**Exit criteria:** an alarm configured with each proof type can only be dismissed by completing it.

## Milestone 3 — Proof system, part 2 + enforcement layer (week 7–8)

- [x] Photo-match proof: register reference photo; dismissal shows ghost overlay of reference; on-device similarity via Vision feature-print distance; tunable threshold behind a debug slider (final value set in beta) *(threshold slider in the Reliability Harness; needs devices + testers to tune)*
- [x] Wake-Up Check: configurable 3–10 min post-dismissal local notification; missing it re-fires the alarm once *(acknowledge via notification tap, "I'm up" action, or the home-screen card)*
- [x] Emergency exit: moving-target tap challenge, 100 taps base, +100 per use per user, 30-day reset; records morning as LOSS; reachable from every proof screen *(server-side counter on `profiles` reconciled when signed in; **reinstall persistence unverifiable until the Supabase project exists**)*
- [x] Anti-cheat pass: proof screens block screenshots of reference image; time changes (manual clock rollback) detected and flagged on the morning record *(secure-canvas rendering + screenshot telemetry; rollback detector latches onto `Morning.clockTampered`)*

**Exit criteria:** photo proof false-negative rate < 5% across 3 testers' homes at default threshold; emergency exit escalation persists across reinstall (server-side counter).

## Milestone 4 — Mornings: missions, score, streak, lock (week 9–10)

- [x] Morning mission list: 3–5 items, templates (drink water, push-ups, read, no-phone, custom); check-off interaction with score animation
- [x] Proof-attached missions (Pro): attach barcode or photo proof to any mission
- [x] Today's Score: weighted formula (wake-on-time ≈ 40%; remainder split across missions); morning closes at user-set deadline; score locks *(deadline = 2/3/4h after wake target, default 3 — implementation call pending the real PRD)*
- [x] Goal lock: wake time + mission list immutable from T-4h until morning close; countdown shown in UI
- [x] Streak engine: consecutive WIN mornings; history strip (last 30 days) on home screen; streak logic fully unit-tested incl. timezone travel + DST
- [x] Home screen: next alarm, streak, history strip, today's state

**Exit criteria:** full loop demo — set alarm at night, wake, proof, check, complete missions, score locks, streak increments.

## Milestone 5 — Widget, onboarding, paywall (week 11)

- [ ] WidgetKit widget (small + medium): streak, today's score, next alarm
- [ ] Onboarding: value promise → account → first alarm + proof registration → 3 starter missions; target < 3 min; NO paywall in this flow
- [ ] RevenueCat: Pro entitlement, €39.99/yr + €5.99/mo, 7-day trial; paywall shown contextually when a Pro feature is tapped
- [ ] Free-tier limits enforced (1 alarm, math/steps only, 3 missions)
- [ ] Funnel analytics wired end-to-end per `docs/analytics-events.md`

**Exit criteria:** TestFlight build a stranger can go from install → verified wake next morning without help.

## Milestone 6 — Hardening + beta (week 12–13)

- [ ] Dogfood week: whole team wakes with HBIT daily; triage board for issues
- [ ] Device matrix pass: iPhone SE 2 → 16 Pro Max, iOS 17/18
- [ ] Accessibility pass: Dynamic Type, VoiceOver on dismiss + mission screens
- [ ] TestFlight beta (100–200 users); crash-free ≥ 99.5%; photo-match threshold finalized from beta data
- [ ] App Store assets: screenshots, privacy nutrition labels, subscription disclosures

## Milestone 7 — Submission (week 14)

- [ ] App Review notes prepared (explain alarm behavior, subscription terms, camera usage strings)
- [ ] Launch Definition of Done checklist from PRD §12 fully green
- [ ] Submit
