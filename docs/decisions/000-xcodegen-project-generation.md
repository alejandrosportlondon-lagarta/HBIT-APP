# ADR 000 — Generate the Xcode project with XcodeGen

**Status:** superseded by [ADR 001](001-checked-in-xcodeproj.md) · **Date:** 2026-07-09 · **Milestone:** 0

## Context

Milestone 0 was scaffolded from a Linux environment with no Xcode toolchain,
and `.xcodeproj` files are merge-conflict magnets once several branches touch
target settings. We need a project definition that is reviewable in PRs,
deterministic, and creatable/verifiable without a Mac in the loop.

## Decision

The Xcode project is generated from `project.yml` by
[XcodeGen](https://github.com/yonaskolb/XcodeGen); `HBIT.xcodeproj` is
gitignored. Developers and CI run `xcodegen generate` (CI installs it via
Homebrew). XcodeGen is a build-time dev tool, not an app dependency, so this
does not violate the "SPM only, no third-party libraries" rule.

## Consequences

- All target settings, SPM dependencies, entitlements and Info.plist keys are
  code-reviewable YAML; no pbxproj merge conflicts.
- One extra setup step (`brew install xcodegen`), documented in the README.
- If we ever need hand-maintained project state (e.g. Xcode-managed
  capabilities), we can check in the generated project and retire this — the
  YAML remains valid documentation of intent.
