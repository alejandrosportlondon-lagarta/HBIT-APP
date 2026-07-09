import Foundation
import SwiftData

/// Singleton record tracking the consecutive-WIN streak. Derived from
/// Morning records but persisted so the widget and home screen read it
/// without recomputing history. Streak rules (timezone travel, DST,
/// freezes) are Milestone 4 and land fully unit-tested in MorningKit.
@Model
final class StreakState {
    @Attribute(.unique) var id: UUID
    var currentStreak: Int
    var longestStreak: Int
    /// dateKey ("yyyy-MM-dd") of the most recent WIN morning.
    var lastWinDateKey: String?
    /// Pro: streak freezes available (unused in free tier).
    var freezesAvailable: Int
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastWinDateKey: String? = nil,
        freezesAvailable: Int = 0,
        now: Date = .now
    ) {
        self.id = id
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastWinDateKey = lastWinDateKey
        self.freezesAvailable = freezesAvailable
        self.updatedAt = now
    }
}
