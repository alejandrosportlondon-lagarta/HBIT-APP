# HBIT

Verification-based alarm + scored morning routine for iOS.
v1 scope = **"The Verified Morning"** — see `docs/PRD.md` and `docs/TASKS.md`.

## Repo layout

```
project.yml          XcodeGen spec — run `xcodegen generate` to produce HBIT.xcodeproj
HBIT/                App target sources (SwiftUI app, SwiftData models, DesignSystem, services)
Packages/            Local SPM feature modules: AlarmEngine, ProofKit, MorningKit, SyncKit, PaywallKit
Config/              xcconfig files. Copy Config.example.xcconfig → Config.xcconfig and fill in keys
supabase/migrations/ Postgres schema + RLS for the Supabase backend
docs/                PRD, task breakdown, analytics event taxonomy, ADRs (docs/decisions/)
```

## Getting started

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
2. `cp Config/Config.example.xcconfig Config/Config.xcconfig` and fill in your keys
   (Supabase URL + anon key, Sentry DSN, PostHog API key). The app runs fine with
   them empty — backends are disabled until configured.
3. `xcodegen generate && open HBIT.xcodeproj`

The generated `HBIT.xcodeproj` is gitignored; `project.yml` is the source of truth.

## Conventions

See `CLAUDE.md`. Highlights: Swift 6 strict concurrency, iOS 17 min, offline-first
(the alarm/proof/scoring core never depends on connectivity), SPM only,
conventional commits, tests first for AlarmEngine + scoring.
