/// The complete event taxonomy. Cases mirror `docs/analytics-events.md` —
/// additions are proposed there first, then added here. Ad-hoc string
/// events are impossible by design.
enum AnalyticsEvent: String {
    // Onboarding funnel
    case onboardingStarted = "onboarding_started"
    case accountCreated = "account_created"
    case firstAlarmSet = "first_alarm_set"
    case firstProofRegistered = "first_proof_registered"
    case onboardingCompleted = "onboarding_completed"

    // Core loop
    case alarmScheduled = "alarm_scheduled"
    case alarmRang = "alarm_rang"
    case proofStarted = "proof_started"
    case proofCompleted = "proof_completed"
    case proofFailed = "proof_failed"
    case alarmDismissed = "alarm_dismissed"
    case emergencyExitUsed = "emergency_exit_used"
    case wakeUpCheckPassed = "wake_up_check_passed"
    case wakeUpCheckMissed = "wake_up_check_missed"
    case missionCompleted = "mission_completed"
    case morningClosed = "morning_closed"

    // Monetization (no paywall during onboarding — guardrail)
    case paywallShown = "paywall_shown"
    case trialStarted = "trial_started"
    case subscriptionStarted = "subscription_started"
}
