/// The proof mechanisms that can gate alarm dismissal (and, for Pro,
/// individual missions). Verification implementations land in Milestones
/// 2–3; the type and its free/Pro tiering are product guardrails fixed in
/// CLAUDE.md.
public enum ProofType: String, Codable, Sendable, CaseIterable {
    case math
    case steps
    case barcode
    case photoMatch

    /// Photo and barcode proofs are Pro-gated; math and steps are free.
    public var requiresPro: Bool {
        switch self {
        case .math, .steps: false
        case .barcode, .photoMatch: true
        }
    }
}
