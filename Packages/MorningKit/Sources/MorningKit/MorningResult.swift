/// The binary outcome of a morning. Every morning is a timestamped WIN or
/// LOSS — there is no third state once a morning closes. Scoring and the
/// close rules are Milestone 4; the outcome vocabulary is foundation.
public enum MorningResult: String, Codable, Sendable, CaseIterable {
    case win
    case loss
}
