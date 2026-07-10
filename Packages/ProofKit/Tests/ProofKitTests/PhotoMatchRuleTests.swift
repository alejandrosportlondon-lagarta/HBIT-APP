import Foundation
import Testing
@testable import ProofKit

@Suite("PhotoMatchRule")
struct PhotoMatchRuleTests {
    @Test("distance at or below the threshold matches; above does not")
    func thresholdBoundary() {
        #expect(PhotoMatchRule.isMatch(distance: 0.0, threshold: 0.8))
        #expect(PhotoMatchRule.isMatch(distance: 0.79, threshold: 0.8))
        #expect(PhotoMatchRule.isMatch(distance: 0.8, threshold: 0.8))
        #expect(!PhotoMatchRule.isMatch(distance: 0.81, threshold: 0.8))
        #expect(!PhotoMatchRule.isMatch(distance: 2.0, threshold: 0.8))
    }

    @Test("garbage distances never match")
    func garbageDistances() {
        #expect(!PhotoMatchRule.isMatch(distance: .nan, threshold: 0.8))
        #expect(!PhotoMatchRule.isMatch(distance: .infinity, threshold: 0.8))
        #expect(!PhotoMatchRule.isMatch(distance: -0.1, threshold: 0.8))
    }

    @Test("thresholds are clamped into the debug-slider range")
    func thresholdClamping() {
        #expect(PhotoMatchRule.clampedThreshold(0.0) == PhotoMatchRule.thresholdRange.lowerBound)
        #expect(PhotoMatchRule.clampedThreshold(9.9) == PhotoMatchRule.thresholdRange.upperBound)
        #expect(PhotoMatchRule.clampedThreshold(0.8) == 0.8)
        #expect(PhotoMatchRule.clampedThreshold(.nan) == PhotoMatchRule.defaultThreshold)
    }

    @Test("config clamps its threshold and round-trips through payload encoding")
    func configRoundTrip() throws {
        let config = PhotoProofConfig(
            featurePrint: Data([1, 2, 3]),
            referenceFileName: "ref.jpg",
            threshold: 99
        )
        #expect(config.threshold == PhotoMatchRule.thresholdRange.upperBound)
        let decoded = try PhotoProofConfig.from(payload: config.payloadData())
        #expect(decoded == config)
    }
}
