/// The lifecycle states of an alarm. The transition rules (the state
/// machine itself) are Milestone 1 work; the cases and their persisted raw
/// values are foundation, because SwiftData records and crash reports will
/// reference them from day one.
public enum AlarmState: String, Codable, Sendable, CaseIterable {
    case scheduled
    case ringing
    case proofInProgress
    case dismissed
    case emergencyExited
    case expired

    /// A morning is decided once the alarm reaches one of these states.
    public var isTerminal: Bool {
        switch self {
        case .dismissed, .emergencyExited, .expired: true
        case .scheduled, .ringing, .proofInProgress: false
        }
    }
}
