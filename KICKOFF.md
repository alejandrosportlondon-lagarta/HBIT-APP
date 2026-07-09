# HBIT — Claude Code Handoff

## Repo setup (one time)

```bash
mkdir hbit && cd hbit
git init
mkdir -p docs/decisions
# Drop the handoff files in:
#   CLAUDE.md        → repo root
#   TASKS.md         → docs/TASKS.md
#   HBIT-v1-plan.md  → docs/PRD.md
git add -A && git commit -m "chore: project handoff docs"
claude
```

(Claude Code install & setup, if needed: https://docs.claude.com/en/docs/claude-code/overview)

## Kickoff prompt (paste as your first message)

```
Read CLAUDE.md, docs/PRD.md, and docs/TASKS.md in full before doing anything.

Then start Milestone 0 from docs/TASKS.md. Before writing code, give me:
1. A one-paragraph restatement of the v1 product so I can confirm you've got it
2. Your proposed project structure (targets, local SPM packages, folder layout)
3. Any Milestone 0 tasks you can't complete without credentials or my input
   (Supabase project keys, Apple developer account, Sentry/PostHog/RevenueCat keys)
   — list them so I can prepare them while you scaffold everything that doesn't need them.

Then proceed. Check off tasks in docs/TASKS.md as you complete them, and commit
in small conventional-commit increments.
```

## What Claude Code will need from you (prepare in parallel)

- Apple Developer account access (signing, entitlement requests, later App Store Connect)
- A Supabase project (URL + anon/service keys) — or let it write migrations locally first
- RevenueCat, PostHog, Sentry accounts + API keys (Milestone 0 integrates them behind a facade; keys can come later via xcconfig)
- Two physical iPhones for the Milestone 1 alarm reliability dogfood — simulators are not sufficient for alarm/audio testing

## Session rhythm that works well

- One milestone (or half-milestone) per session; start each session with "read CLAUDE.md and docs/TASKS.md, continue from the first unchecked task"
- Review the ADRs it writes in docs/decisions/ — that's where the risky iOS trade-offs will surface
- You personally test every Milestone 1 exit criterion on a real device before allowing Milestone 2
```
