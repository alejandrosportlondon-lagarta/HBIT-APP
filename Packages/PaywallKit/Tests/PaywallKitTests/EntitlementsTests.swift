import Testing
@testable import PaywallKit

@Suite("Entitlements")
struct EntitlementsTests {
    @Test("free tier limits match the product guardrails")
    func freeTierLimits() {
        #expect(FreeTierLimits.maxAlarms == 1)
        #expect(FreeTierLimits.maxMissions == 3)
    }

    @Test("the Pro gate list matches CLAUDE.md")
    func proGates() {
        #expect(Set(ProFeature.allCases) == [
            .photoProof, .barcodeProof, .missionChaining, .unlimitedMissions,
            .proofAttachedMissions, .streakFreeze, .stats
        ])
    }
}
