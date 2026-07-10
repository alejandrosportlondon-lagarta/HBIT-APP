import Foundation

/// The interval during which an alarm occurrence is "live". Restart
/// resilience is built on this: on every app launch the persisted
/// occurrence is checked against its ring window to decide whether to
/// resume ringing, keep waiting, or record the morning as expired.
public struct RingWindow: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        /// Before the fire date.
        case pending
        /// Between fire date and window end — the alarm should be ringing.
        case ringing
        /// The window elapsed without dismissal.
        case expired
    }

    public let fireDate: Date
    public let duration: TimeInterval

    public init(fireDate: Date, duration: TimeInterval = NotificationChainPlan.maxRingWindow) {
        self.fireDate = fireDate
        self.duration = max(0, duration)
    }

    public var endDate: Date { fireDate.addingTimeInterval(duration) }

    public func phase(at date: Date) -> Phase {
        if date < fireDate { return .pending }
        if date < endDate { return .ringing }
        return .expired
    }
}
