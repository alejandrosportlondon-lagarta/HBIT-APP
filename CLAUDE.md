# HBIT — Project Instructions for Claude Code

HBIT is an iOS app: a verification-based alarm + scored morning routine.
v1 scope = "The Verified Morning". The full PRD lives at `docs/PRD.md` — read it before any feature work.

## What we're building (one paragraph)

An alarm that cannot be dismissed without completing a proof (photo-match, barcode scan, math, or steps), followed by a Wake-Up Check, then a 3–5 item scored morning mission list. Every morning is a timestamped WIN/LOSS. Wake time + missions lock 4 hours before the alarm. An emergency exit always exists but escalates in cost (+100 taps per use, resets after 30 days) and records the morning as a LOSS.

## Stack (do not substitute without asking)

- **Client:** Swift 6, SwiftUI, Swift Concurrency (async/await, actors), Observation framework (`@Observable`, not ObservableObject), WidgetKit, ActivityKit (P1 only), AVFoundation, CoreMotion, Vision (photo similarity only — never object recognition)
- **Min target:** iOS 17.0
- **Backend:** Supabase (Postgres, Auth, Edge Functions in TypeScript)
- **Services:** RevenueCat, PostHog, Sentry, Resend
- **No third-party UI libraries.** No CocoaPods — SPM only.

## Architecture rules

- Offline-first is non-negotiable: the alarm, all proofs, scoring, and streaks MUST work with zero connectivity. Supabase sync is background reconciliation, never a dependency of the core loop.
- Single source of truth: the `mornings` table / local equivalent: `(user_id, date, wake_target, wake_actual, result, score, missions jsonb)`. Local store is SwiftData; sync layer reconciles to Supabase.
- Feature modules: `AlarmEngine`, `ProofKit`, `MorningKit` (missions + scoring), `SyncKit`, `PaywallKit`. Each is an SPM local package with its own tests.
- The AlarmEngine has a documented reliability strategy (stacked local notifications every 30–60s as a chain, critical alerts if entitlement granted, audio keep-alive when foregrounded). Never rely on a single scheduled notification.
- All times stored in UTC; all scheduling done in the user's timezone; DST transitions must have explicit tests.

## Product guardrails (do not violate)

- NO paywall during onboarding. First alarm must be settable end-to-end free.
- Free tier: 1 alarm, math + steps proofs, 3 missions, score, streak, widget. Pro gates: photo/barcode proofs, mission chaining, unlimited missions, proof-attached missions, streak freeze, stats.
- Emergency exit must always be reachable from the dismiss screen. We enforce discipline, we never trap users. Its use = LOSS morning, never a crash-out.
- Verification must be deterministic. If a proof can produce a false negative (user did it, app says no), redesign it. This is the #1 trust killer per competitor reviews.
- No dark patterns: subscription terms fully visible pre-trial, one-tap cancel path documented.

## Engineering conventions

- Tests first for AlarmEngine and scoring logic (these are the two zero-defect zones). UI can be tested via previews + snapshot tests later.
- Every PR-sized change: build passes, tests pass, `swiftlint` clean.
- Commit style: conventional commits (`feat:`, `fix:`, `test:`, `chore:`).
- Do not add analytics events ad hoc — the event taxonomy lives in `docs/analytics-events.md`; propose additions there first.
- Secrets: never in the repo. Use `.env` + xcconfig; `Config.example.xcconfig` is committed, real one is gitignored.

## Working style

- Work milestone by milestone from `docs/TASKS.md`. Do not start a later milestone early.
- When a task is ambiguous, ask one focused question rather than guessing on product behavior; make reasonable calls on pure implementation details and note them in the PR description.
- If an iOS platform limitation blocks the intended behavior (e.g., notification limits, background execution), document the constraint and the chosen workaround in `docs/decisions/` as a short ADR before coding around it.
- Update `docs/TASKS.md` checkboxes as you complete work.
