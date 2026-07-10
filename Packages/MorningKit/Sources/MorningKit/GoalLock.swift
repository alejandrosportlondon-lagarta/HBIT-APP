import Foundation

/// The goal lock: wake time + mission list are immutable from 4 hours
/// before the alarm until the morning closes. No last-minute bargaining
/// with tomorrow-you.
public enum GoalLock {
    public static let leadTime: TimeInterval = 4 * 60 * 60

    public enum Phase: Equatable, Sendable {
        /// Everything editable.
        case open
        /// Inside the T-4h window before the alarm fires.
        case lockedUntilFire(Date)
        /// The morning is running (fired, not yet closed).
        case lockedUntilClose(Date)
    }

    /// - Parameters:
    ///   - nextFireDate: the pending alarm occurrence, if any.
    ///   - morningCloseAt: today's morning close deadline, if a morning is
    ///     currently open.
    public static func phase(now: Date, nextFireDate: Date?, morningCloseAt: Date?) -> Phase {
        if let closeAt = morningCloseAt, now < closeAt {
            return .lockedUntilClose(closeAt)
        }
        if let fireDate = nextFireDate,
           now >= fireDate.addingTimeInterval(-leadTime),
           now < fireDate {
            return .lockedUntilFire(fireDate)
        }
        return .open
    }
}
