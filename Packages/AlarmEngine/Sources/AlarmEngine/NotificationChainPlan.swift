import Foundation

/// The scheduled-notification chain for one alarm occurrence (ADR 002).
/// Never rely on a single notification: the plan is N entries starting at
/// the fire date, one every `interval` seconds, all sharing an identifier
/// prefix so the whole chain can be cancelled atomically on dismissal.
public struct NotificationChainPlan: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        public let identifier: String
        public let fireDate: Date
    }

    /// Chain entries stay well under iOS's 64 pending-notification budget,
    /// leaving room for the Wake-Up Check and anything else.
    public static let maxEntries = 30
    /// ADR 002 / TASKS.md: repeat every 30–60 s…
    public static let intervalRange: ClosedRange<TimeInterval> = 30...60
    /// …for up to 30 minutes.
    public static let maxRingWindow: TimeInterval = 30 * 60

    public let baseIdentifier: String
    public let entries: [Entry]

    /// - Parameters:
    ///   - baseIdentifier: unique per occurrence; every entry identifier is
    ///     prefixed with it (`<base>#<index>`).
    ///   - fireDate: the first entry's fire instant (the alarm time).
    ///   - interval: seconds between entries, clamped to 30–60.
    ///   - ringWindow: chain span in seconds, clamped to ≤ 30 min.
    public init(
        baseIdentifier: String,
        fireDate: Date,
        interval: TimeInterval = 60,
        ringWindow: TimeInterval = NotificationChainPlan.maxRingWindow
    ) {
        let interval = min(max(interval, Self.intervalRange.lowerBound), Self.intervalRange.upperBound)
        let window = min(max(ringWindow, 0), Self.maxRingWindow)
        let byWindow = Int(window / interval) + 1
        let count = max(1, min(Self.maxEntries, byWindow))
        self.baseIdentifier = baseIdentifier
        self.entries = (0..<count).map { index in
            Entry(
                identifier: "\(baseIdentifier)#\(index)",
                fireDate: fireDate.addingTimeInterval(Double(index) * interval)
            )
        }
    }

    /// True if `identifier` belongs to this chain (or any chain with the
    /// given base) — used to cancel by prefix.
    public static func identifier(_ identifier: String, belongsTo baseIdentifier: String) -> Bool {
        identifier == baseIdentifier || identifier.hasPrefix("\(baseIdentifier)#")
    }
}
