/// Events that drive an alarm through its lifecycle.
public enum AlarmEvent: String, Codable, Sendable, CaseIterable {
    /// The fire time arrived (notification fired or app observed the time).
    case fire
    /// The user tapped "start proof" on the dismiss screen.
    case beginProof
    /// The proof verified successfully.
    case proofSucceeded
    /// The proof attempt failed; back to ringing.
    case proofFailed
    /// The user completed the emergency exit (morning becomes a LOSS).
    case emergencyExit
    /// The ring window elapsed without dismissal (morning becomes a LOSS).
    case expire
}

/// Deterministic alarm state machine. The full transition table is explicit
/// and total: any (state, event) pair not listed is rejected, and terminal
/// states absorb nothing. This is a value type so callers can dry-run
/// transitions without committing them.
public struct AlarmStateMachine: Equatable, Sendable {
    public private(set) var state: AlarmState

    public init(state: AlarmState = .scheduled) {
        self.state = state
    }

    /// The complete transition table.
    public static func nextState(from state: AlarmState, on event: AlarmEvent) -> AlarmState? {
        switch (state, event) {
        case (.scheduled, .fire): .ringing
        case (.ringing, .beginProof): .proofInProgress
        case (.ringing, .emergencyExit): .emergencyExited
        case (.ringing, .expire): .expired
        case (.proofInProgress, .proofSucceeded): .dismissed
        case (.proofInProgress, .proofFailed): .ringing
        case (.proofInProgress, .emergencyExit): .emergencyExited
        case (.proofInProgress, .expire): .expired
        default: nil
        }
    }

    /// Applies `event` if legal. Returns the new state, or nil (leaving the
    /// machine untouched) if the transition is invalid.
    @discardableResult
    public mutating func handle(_ event: AlarmEvent) -> AlarmState? {
        guard let next = Self.nextState(from: state, on: event) else { return nil }
        state = next
        return next
    }
}
