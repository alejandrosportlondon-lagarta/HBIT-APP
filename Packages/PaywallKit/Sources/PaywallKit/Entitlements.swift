/// Features gated behind the Pro entitlement, per the product guardrails in
/// CLAUDE.md. RevenueCat integration is Milestone 5; the gate definitions
/// are foundation so free-tier limits are enforced from one place.
public enum ProFeature: String, Codable, Sendable, CaseIterable {
    case photoProof
    case barcodeProof
    case missionChaining
    case unlimitedMissions
    case proofAttachedMissions
    case streakFreeze
    case stats
}

/// Hard limits for the free tier. NO paywall during onboarding — the first
/// alarm must be settable end-to-end free within these limits.
public enum FreeTierLimits {
    public static let maxAlarms = 1
    public static let maxMissions = 3
}
