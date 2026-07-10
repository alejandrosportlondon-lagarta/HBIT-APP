import Foundation

/// Anti-cheat: detects manual clock rollback (set the clock back, "dismiss"
/// yesterday's alarm again / dodge the lock). The app persists the maximum
/// wall-clock time it has ever observed; seeing a time meaningfully before
/// that means the clock was rolled back. The tolerance absorbs NTP
/// adjustments and timezone-display confusion — only deliberate rollbacks
/// should flag.
public enum ClockRollbackDetector {
    public static let defaultTolerance: TimeInterval = 120

    public static func isRollback(
        now: Date,
        lastObserved: Date?,
        tolerance: TimeInterval = defaultTolerance
    ) -> Bool {
        guard let lastObserved else { return false }
        return now < lastObserved.addingTimeInterval(-max(0, tolerance))
    }

    /// The value to persist after observing `now`.
    public static func nextObservedMaximum(now: Date, lastObserved: Date?) -> Date {
        guard let lastObserved else { return now }
        return max(now, lastObserved)
    }
}
