# Critical Alerts entitlement request (draft)

Submit at: https://developer.apple.com/contact/request/notifications-critical-alerts-entitlement/
**Blocked on:** founder's Apple Developer account (submission must come from
the team that owns the App ID).

---

**App name:** HBIT
**Bundle ID:** com.hbit.app

**Describe your app.**
HBIT is an alarm clock whose alarms can only be dismissed by completing a
physical wake-up verification (solving math problems, walking a number of
steps, scanning a barcode the user registered in another room, or matching a
reference photo). Users rely on it as their primary morning alarm.

**Why does your app need critical alerts?**
HBIT's sole safety-critical function is waking the user at the time they
chose. Standard local notifications are muted by the silent switch and by
Focus/Do Not Disturb — the exact states a sleeping user's phone is usually
in overnight. A missed alarm is not a degraded experience but a total
product failure with real-world consequences (missed work, flights, exams).
Critical alerts are requested exclusively for the user-scheduled alarm
chain and the single post-alarm Wake-Up Check re-fire; no marketing,
social, or engagement notification will ever use the entitlement.

**User consent flow.**
Critical alert permission is requested separately and only when the user
enables their first alarm, with an explanation screen ("Allow HBIT to break
through Silent and Do Not Disturb so your alarm always rings"). Declining
leaves alarms on standard time-sensitive notifications, and the setting can
be revoked anytime in iOS Settings; the app reflects the reduced-reliability
state in its UI.

**Volume:** at most ~31 critical notifications per alarm occurrence (a
30-minute ring chain plus one Wake-Up Check), only at the user-chosen wake
time, only while an alarm the user created is active.
