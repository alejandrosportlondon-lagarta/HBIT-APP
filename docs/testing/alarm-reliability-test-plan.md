# Alarm reliability test plan (Milestone 1)

Manual scenario matrix for the reliability harness. Run on **physical
devices** (simulators do not reproduce audio-session, silent-switch, Focus,
or Low Power behavior). Record pass/fail per device per iOS version in the
in-app Debug Harness screen (Debug builds: Home → "Reliability Harness"),
which persists the checklist.

Setup for every scenario: schedule a test alarm 2 minutes out from the
harness screen, then put the app in the state under test before fire time.

| # | Scenario | Steps | Expected |
| --- | --- | --- | --- |
| 1 | Foreground ring | Keep app open until fire time | Full-screen ringing UI + looping ramping audio at fire time; chain cancelled on dismiss |
| 2 | Background ring | Home-screen the app before fire | Notification banner + sound every ~60 s; tapping any banner opens ringing UI with audio; dismiss cancels the rest of the chain |
| 3 | App killed | Force-quit the app before fire | Chain notifications still fire; tapping one relaunches into ringing UI |
| 4 | Reboot mid-ring | Let it start ringing, reboot the phone, reopen the app within 30 min | App resumes ringing state on launch |
| 5 | Silent switch on | Mute switch on, app backgrounded | Documented limit pre-critical-alerts: banners fire silently. In-app audio still plays when opened. Verify no false "dismissed" state |
| 6 | Focus / DND on | Enable a Focus mode | With time-sensitive capability: banners break through. Without: documented limit — verify chain still visible in Notification Center |
| 7 | Low Power Mode | Enable before fire | Chain fires on time (local notifications are unaffected); note any audio-ramp anomalies |
| 8 | Storage nearly full | Fill device storage | Chain still schedules (64-slot budget unaffected by storage); app remains launchable |
| 9 | DST spring-forward | Set device date to the night of a spring-forward, alarm inside/after the gap | Fires at the correct wall-clock moment per `AlarmOccurrenceCalculator` tests (automated) + manual device confirmation |
| 10 | DST fall-back | Same for fall-back night | Fires once, at the first occurrence of the wall-clock time |
| 11 | Notifications denied | Revoke notification permission | App detects and shows a blocking warning before letting the user rely on an alarm |
| 12 | Ring-window expiry | Let the alarm ring unattended > 30 min, then open | Morning recorded as LOSS (expired); no stuck ringing UI |

Exit criterion (TASKS.md): 7-day dogfood, ≥ 2 physical devices, zero missed
alarms, every scenario above marked pass/fail.
