import Foundation
import SwiftData
import MorningKit
import SyncKit

/// The single source of truth for one morning: `(user_id, date, wake_target,
/// wake_actual, result, score, missions jsonb)`. Local-first — a Morning is
/// written locally the moment it happens and reconciled to the Supabase
/// `mornings` table in the background by SyncKit.
@Model
final class Morning {
    @Attribute(.unique) var id: UUID
    /// Supabase auth user id. Nil until the user has signed in; SyncKit
    /// backfills it on first reconciliation.
    var userID: UUID?
    /// The calendar day this morning belongs to, as "yyyy-MM-dd" in the
    /// user's timezone at the time the alarm fired. One morning per day.
    var dateKey: String
    /// Times are stored in UTC; scheduling happens in the user's timezone.
    var wakeTarget: Date
    var wakeActual: Date?
    private var resultRaw: String?
    var score: Int?
    /// JSON snapshot of the mission list as it was locked for this morning
    /// (mirrors the `missions jsonb` column).
    var missionsSnapshot: Data
    /// Anti-cheat: a manual clock rollback was detected around this morning.
    var clockTampered: Bool = false
    private var syncStatusRaw: String
    var createdAt: Date
    var updatedAt: Date

    var result: MorningResult? {
        get { resultRaw.flatMap(MorningResult.init(rawValue:)) }
        set { resultRaw = newValue?.rawValue }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pending }
        set { syncStatusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        userID: UUID? = nil,
        dateKey: String,
        wakeTarget: Date,
        wakeActual: Date? = nil,
        result: MorningResult? = nil,
        score: Int? = nil,
        missionsSnapshot: Data = Data("[]".utf8),
        syncStatus: SyncStatus = .pending,
        now: Date = .now
    ) {
        self.id = id
        self.userID = userID
        self.dateKey = dateKey
        self.wakeTarget = wakeTarget
        self.wakeActual = wakeActual
        self.resultRaw = result?.rawValue
        self.score = score
        self.missionsSnapshot = missionsSnapshot
        self.syncStatusRaw = syncStatus.rawValue
        self.createdAt = now
        self.updatedAt = now
    }
}
