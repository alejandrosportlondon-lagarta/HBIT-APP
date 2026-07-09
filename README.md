# HBIT

Verification-based alarm + scored morning routine for iOS.
v1 scope = **"The Verified Morning"** — see `docs/PRD.md` and `docs/TASKS.md`.

## Repo layout

```
HBIT.xcodeproj       Xcode project (checked in) — open it and press Run
HBIT/                App target sources (SwiftUI app, SwiftData models, DesignSystem, services)
Packages/            Local SPM feature modules: AlarmEngine, ProofKit, MorningKit, SyncKit, PaywallKit
Config/              xcconfig files. Base.xcconfig is committed; real keys go in Config.xcconfig
supabase/migrations/ Postgres schema + RLS for the Supabase backend
docs/                PRD, task breakdown, analytics event taxonomy, ADRs (docs/decisions/)
```

## Getting started

1. Open `HBIT.xcodeproj` in Xcode 16 or newer.
2. Pick an iOS 17+ simulator and press ⌘R. That's it — with no keys configured
   the app runs in local-only mode (auth/sync/telemetry disabled).
3. When you have real keys (Supabase URL + anon key, Sentry DSN, PostHog API
   key): duplicate `Config/Config.example.xcconfig`, rename the copy to
   `Config/Config.xcconfig`, and fill it in. It is gitignored and picked up
   automatically via an optional include in `Config/Base.xcconfig`.

The app folder is a file-system-synchronized group (Xcode 16), so new source
files added under `HBIT/` join the target automatically — no project surgery.

## Conventions

See `CLAUDE.md`. Highlights: Swift 6 strict concurrency, iOS 17 min, offline-first
(the alarm/proof/scoring core never depends on connectivity), SPM only,
conventional commits, tests first for AlarmEngine + scoring.
