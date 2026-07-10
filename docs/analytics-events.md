# HBIT Analytics Event Taxonomy

The single source of truth for analytics events. **No ad-hoc events**: every
event is defined here first, then added to the `AnalyticsEvent` enum
(`HBIT/Services/Telemetry/AnalyticsEvent.swift`), and only fired through the
`Telemetry` facade. Propose additions by PR against this file.

Conventions:

- Event names: `snake_case`, past tense where the event marks a completed fact.
- Properties: `snake_case`, string values, no PII (no emails, no photo
  contents, no barcode payloads — proof payloads never leave the device
  except via SyncKit's own tables).
- Every event carries automatic context from the SDK (app version, OS,
  device class). Do not duplicate those as properties.

## Onboarding funnel (activation)

Target: install → verified wake next morning. NO paywall in this flow.

| Event | Fired when | Properties |
| --- | --- | --- |
| `onboarding_started` | First screen of onboarding appears | — |
| `account_created` | Supabase session established | `method`: `apple` \| `magic_link` |
| `first_alarm_set` | The user's first alarm is saved | `proof_type` |
| `first_proof_registered` | First proof target registered (photo/barcode) or configured (math/steps) | `proof_type` |
| `onboarding_completed` | Starter missions confirmed, onboarding dismissed | `duration_seconds` |

## Core loop (retention)

| Event | Fired when | Properties |
| --- | --- | --- |
| `alarm_scheduled` | An alarm (re)schedules its notification chain | `proof_type` |
| `alarm_rang` | Ring state entered | — |
| `proof_started` | Dismiss screen begins a proof attempt | `proof_type` |
| `proof_completed` | Proof verified successfully | `proof_type`, `attempts`, `duration_seconds` |
| `proof_failed` | A proof attempt failed verification | `proof_type` |
| `alarm_dismissed` | Alarm fully dismissed via proof | `seconds_after_target` |
| `emergency_exit_used` | Emergency exit completed (morning = LOSS) | `tap_cost`, `use_count_30d` |
| `wake_up_check_passed` | Wake-Up Check acknowledged in time | — |
| `wake_up_check_missed` | Wake-Up Check missed, alarm re-fired | — |
| `mission_completed` | A mission checked off (or proof-verified) | `template`, `has_proof` |
| `morning_closed` | Morning deadline reached, score locked | `result`, `score`, `streak`, `clock_tampered` |

## Anti-cheat signals

| Event | Fired when | Properties |
| --- | --- | --- |
| `screenshot_on_proof` | The user screenshots a proof screen (the reference image is blanked by the secure canvas; this records the attempt) | `proof_type` |

## Monetization

Paywall is only ever shown contextually when a Pro feature is tapped —
`trigger_feature` records which one.

| Event | Fired when | Properties |
| --- | --- | --- |
| `paywall_shown` | Paywall presented | `trigger_feature` |
| `trial_started` | 7-day trial begins | `plan`: `annual` \| `monthly` |
| `subscription_started` | Paid subscription active | `plan` |
