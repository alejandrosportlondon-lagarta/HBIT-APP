import Foundation

/// One day in the home-screen history strip.
public struct DayEntry: Equatable, Sendable, Identifiable {
    public enum Outcome: Equatable, Sendable {
        case win
        case loss
        case none
    }

    public let key: String
    public let outcome: Outcome

    public var id: String { key }

    public init(key: String, outcome: Outcome) {
        self.key = key
        self.outcome = outcome
    }
}

/// Streaks over WIN day-keys. Pure set arithmetic on calendar-day strings:
/// no wall-clock math at query time, so DST transitions and timezone travel
/// can't corrupt a streak (the timezone was already baked into each key
/// when the morning happened).
public enum StreakEngine {
    /// Consecutive WIN days ending today — or ending yesterday when today
    /// isn't decided yet (an undecided today never breaks a streak).
    public static func currentStreak(winKeys: Set<String>, today: String) -> Int {
        var cursor: String? = winKeys.contains(today) ? today : MorningDateKey.previous(today)
        var streak = 0
        while let key = cursor, winKeys.contains(key) {
            streak += 1
            cursor = MorningDateKey.previous(key)
        }
        return streak
    }

    public static func longestStreak(winKeys: Set<String>) -> Int {
        var longest = 0
        for key in winKeys {
            // Only measure from the start of each run.
            if let previous = MorningDateKey.previous(key), winKeys.contains(previous) { continue }
            var length = 0
            var cursor: String? = key
            while let current = cursor, winKeys.contains(current) {
                length += 1
                cursor = MorningDateKey.next(current)
            }
            longest = max(longest, length)
        }
        return longest
    }

    /// The last `days` days ending at `today`, oldest first.
    public static func history(
        endingAt today: String,
        days: Int,
        winKeys: Set<String>,
        lossKeys: Set<String>
    ) -> [DayEntry] {
        guard days > 0, let start = MorningDateKey.offset(today, by: -(days - 1)) else { return [] }
        var entries: [DayEntry] = []
        var cursor: String? = start
        for _ in 0..<days {
            guard let key = cursor else { break }
            let outcome: DayEntry.Outcome = winKeys.contains(key) ? .win
                : lossKeys.contains(key) ? .loss
                : .none
            entries.append(DayEntry(key: key, outcome: outcome))
            cursor = MorningDateKey.next(key)
        }
        return entries
    }
}
