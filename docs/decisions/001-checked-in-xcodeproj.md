# ADR 001 — Check in HBIT.xcodeproj (supersedes ADR 000)

**Status:** accepted · **Date:** 2026-07-09 · **Milestone:** 0

## Context

ADR 000 generated the Xcode project from `project.yml` via XcodeGen. That
required every checkout to run Terminal commands (`brew install xcodegen`,
`xcodegen generate`) before the project would open — friction the founder
explicitly asked to remove: the desired flow is *clone → open → ⌘R*, no
Terminal.

## Decision

`HBIT.xcodeproj` is committed to the repo; `project.yml` and the XcodeGen
step are removed. Two choices keep the checked-in project low-maintenance:

- The `HBIT/` folder is a **file-system-synchronized root group** (Xcode 16
  project format, `objectVersion 77`): files added/removed under `HBIT/`
  join or leave the target automatically, so the pbxproj rarely changes and
  merge conflicts stay rare. This sets the minimum tooling to **Xcode 16**.
- The target's base configuration is the committed `Config/Base.xcconfig`
  (empty defaults = local-only mode), which optionally includes the
  gitignored `Config/Config.xcconfig` (`#include?`). A fresh clone builds
  with zero setup; real keys are a file-duplicate away, still never
  committed.

## Consequences

- Clone → open → run works with no tools beyond Xcode 16+; CI drops the
  XcodeGen install/generate steps.
- Target settings are no longer reviewable YAML; changes to build settings
  now show up as pbxproj diffs. Synchronized groups keep those diffs small.
- If pbxproj conflicts become a real problem as the team grows, revisit
  generation (XcodeGen/Tuist) — ADR 000 documents that setup.
