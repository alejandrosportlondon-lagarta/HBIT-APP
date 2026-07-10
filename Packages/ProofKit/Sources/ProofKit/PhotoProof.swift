import Foundation

public struct PhotoProofConfig: ProofConfig {
    public static let kind = ProofType.photoMatch

    /// NSKeyedArchiver-encoded `VNFeaturePrintObservation` of the reference
    /// photo. Only the print is persisted/synced — the photo itself stays
    /// in a local file (`referenceFileName`) used for the ghost overlay and
    /// never leaves the device.
    public let featurePrint: Data
    /// File name of the locally stored reference image.
    public let referenceFileName: String
    /// Maximum Vision feature-print distance that counts as a match.
    public let threshold: Double

    public init(featurePrint: Data, referenceFileName: String, threshold: Double = PhotoMatchRule.defaultThreshold) {
        self.featurePrint = featurePrint
        self.referenceFileName = referenceFileName
        self.threshold = PhotoMatchRule.clampedThreshold(threshold)
    }
}

/// The pure decision half of the photo proof: Vision computes a distance
/// (smaller = more similar); this rule turns it into a deterministic
/// verdict. Guardrail note: the threshold is deliberately forgiving by
/// default and tunable via the debug slider — a false negative (user is in
/// the right place, app says no) is worse than a marginal false positive.
public enum PhotoMatchRule {
    /// Starting point; the final value is set from beta data (TASKS.md).
    public static let defaultThreshold = 0.8
    /// Debug-slider range.
    public static let thresholdRange = 0.2...1.6

    public static func clampedThreshold(_ value: Double) -> Double {
        guard value.isFinite else { return defaultThreshold }
        return min(max(value, thresholdRange.lowerBound), thresholdRange.upperBound)
    }

    public static func isMatch(distance: Double, threshold: Double) -> Bool {
        guard distance.isFinite, distance >= 0 else { return false }
        return distance <= clampedThreshold(threshold)
    }
}
