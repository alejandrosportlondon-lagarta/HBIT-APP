# ADR 002 — Alarm reliability strategy

**Status:** accepted · **Date:** 2026-07-09 · **Milestone:** 1

(TASKS.md refers to this as `001-alarm-reliability.md`; 001 was taken by the
checked-in-xcodeproj decision, so it lives here as 002.)

## Context

iOS gives third-party apps no true alarm primitive on our iOS 17 baseline:
no guaranteed background execution at an arbitrary time, no unbounded
notification sound, and users can force-quit the app. A single scheduled
notification is trivially missed (one 5-second sound while the phone is
face-down). Alarm reliability is HBIT's core promise, so the strategy — and
its honest limits — must be explicit.

## Decision

Defense in depth, in this order:

1. **Notification chain.** For each alarm occurrence we schedule a chain of
   local notifications: default one every 60 s for 30 minutes, capped at
   **30 pending requests**. iOS caps an app's pending local notifications at
   64; capping the chain at 30 leaves headroom for the Wake-Up Check (M3)
   and future alarms. Every entry carries the same thread/category so they
   collapse reasonably in Notification Center. The whole chain is cancelled
   by identifier prefix the moment the alarm is dismissed.
2. **Time-sensitive interruption level** on every chain entry, so alarms
   break through most Focus modes once the capability is enabled on the App
   ID (until then iOS silently demotes it — no crash).
3. **Critical alerts** (bypass silent switch + DND) once Apple grants the
   entitlement — request text lives in
   `docs/critical-alerts-entitlement-request.md`, submission blocked on the
   founder's Apple Developer account.
4. **Audio keep-alive when foregrounded.** When the app is frontmost (or
   launched from a chain notification) we play a looping, volume-ramping
   alarm tone via AVFoundation with an active `.playback` audio session —
   this is the "real alarm" experience and ignores the silent switch. We do
   **not** claim the background-audio entitlement to fake a background
   alarm: App Review rejects it and it burns battery all night.
5. **Restart resilience.** The active occurrence (id, fire date, state) is
   persisted. On every launch we compare `now` against the ring window
   (fire date + 30 min): inside the window with a non-terminal state means
   the app was killed/rebooted mid-ring → we resume the ringing UI and
   audio immediately. Past the window → the morning is recorded as a LOSS
   (`expired`).

## Known limits (documented, not hidden)

| Scenario | Behavior |
| --- | --- |
| App killed / phone rebooted, app not opened | Chain notifications still fire (30 min of repeated banners+sound), but each sound is ≤ 30 s and respects silent switch until critical alerts are granted. No full-screen UI until the user taps one. |
| Silent switch on | Notification sounds muted (until critical alerts); in-app audio still plays if the user opens the app. |
| Focus / DND | Suppressed until the time-sensitive capability is on; critical alerts pierce everything. |
| User disables notifications | Nothing can fire. Detected via authorization status; UI must warn loudly (harness scenario). |
| 64-notification budget | Chain cap 30; other HBIT notifications must stay under the remainder. |
| Force-quit + never reopening | Unsolvable on iOS. The streak (a LOSS is recorded) is the product-level deterrent. |

## Future

Apple's AlarmKit (iOS 26+) provides first-class third-party alarms. When our
deployment target allows, adopt it behind the same `AlarmEngine` API with
the chain as fallback for older iOS. Revisit after v1 ships.
