import AlarmEngine
import Foundation

/// Persists the maximum wall-clock time the app has observed and flags
/// rollbacks (anti-cheat). Checked at launch, on foreground, and when an
/// alarm fires; a detected rollback is remembered until it has been
/// stamped onto a morning record.
@MainActor
final class ClockIntegrityMonitor {
    private static let key = "hbit.clock.maxObservedWallClock"
    private let defaults: UserDefaults
    private(set) var tamperDetected = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private var lastObserved: Date? {
        let stored = defaults.double(forKey: Self.key)
        return stored > 0 ? Date(timeIntervalSince1970: stored) : nil
    }

    /// Observes `now`, updates the persisted maximum, and latches the
    /// tamper flag if a rollback is detected.
    func observe(now: Date = .now) {
        if ClockRollbackDetector.isRollback(now: now, lastObserved: lastObserved) {
            tamperDetected = true
        }
        let maximum = ClockRollbackDetector.nextObservedMaximum(now: now, lastObserved: lastObserved)
        defaults.set(maximum.timeIntervalSince1970, forKey: Self.key)
    }

    /// Reads and clears the latched flag (called when stamping a morning).
    func consumeTamperFlag() -> Bool {
        let flagged = tamperDetected
        tamperDetected = false
        return flagged
    }
}
