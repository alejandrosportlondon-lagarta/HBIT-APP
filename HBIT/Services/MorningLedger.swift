import Foundation
import MorningKit
import Observation
import SwiftData

/// Owns morning records after the alarm side hands over: mission snapshot,
/// check-offs, live score, the close deadline (score lock), and streak
/// recomputation. Everything is local-first; SyncKit reconciles later.
@MainActor
@Observable
final class MorningLedger {
    private var modelContext: ModelContext?
    /// Bumped on every mutation so SwiftUI re-reads derived values.
    private(set) var revision = 0

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Recording (called by AlarmCoordinator)

    /// Creates or updates today's morning when the alarm resolves. The
    /// mission list is snapshotted here — it has been locked since T-4h,
    /// so fire-time and lock-time snapshots are equivalent.
    func record(
        result: MorningResult,
        wakeActual: Date?,
        wakeTarget: Date,
        alarmID: UUID,
        clockTampered: Bool
    ) {
        guard let modelContext else { return }
        let config = fetchConfig(alarmID)
        let timeZone = TimeZone(identifier: config?.timeZoneID ?? "") ?? .current
        let dateKey = MorningDateKey.key(for: wakeTarget, in: timeZone)
        let closeHours = config?.effectiveMorningCloseHours ?? AlarmConfig.defaultMorningCloseHours
        let closeAt = wakeTarget.addingTimeInterval(TimeInterval(closeHours) * 3600)

        let morning: Morning
        if let existing = fetchMorning(dateKey: dateKey) {
            morning = existing
        } else {
            morning = Morning(dateKey: dateKey, wakeTarget: wakeTarget)
            morning.missionsSnapshot = snapshotActiveMissions()
            modelContext.insert(morning)
        }
        morning.result = result
        morning.wakeActual = wakeActual
        morning.closeAt = closeAt
        morning.clockTampered = morning.clockTampered || clockTampered
        morning.updatedAt = .now
        morning.syncStatus = .pending
        if morning.missionsSnapshot == Data("[]".utf8) {
            morning.missionsSnapshot = snapshotActiveMissions()
        }
        recomputeScore(for: morning)
        refreshStreak()
        revision += 1
    }

    // MARK: - Today

    func todayMorning(now: Date = .now) -> Morning? {
        let key = MorningDateKey.key(for: now, in: .current)
        // The morning may have started "yesterday" for late closers; prefer
        // an open morning, else today's record.
        if let open = openMorning(now: now) { return open }
        return fetchMorning(dateKey: key)
    }

    func missionItems(for morning: Morning) -> [MissionSnapshotItem] {
        MissionSnapshotItem.decode(morning.missionsSnapshot)
    }

    var isMorningOpen: Bool { openMorning(now: .now) != nil }

    private func openMorning(now: Date) -> Morning? {
        // Small table; filter in memory to keep predicates simple.
        let all = (try? modelContext?.fetch(FetchDescriptor<Morning>())) ?? []
        return all.first { $0.scoreLockedAt == nil && ($0.closeAt.map { now < $0 } ?? false) }
    }

    /// The active close deadline for the goal lock, if a morning is open.
    func morningCloseAt(now: Date = .now) -> Date? {
        openMorning(now: now)?.closeAt
    }

    // MARK: - Mission check-off

    func completeMission(id: UUID, in morning: Morning, now: Date = .now) {
        guard morning.scoreLockedAt == nil else { return }
        var items = missionItems(for: morning)
        guard let index = items.firstIndex(where: { $0.id == id }), !items[index].isCompleted else { return }
        items[index].completedAt = now
        morning.missionsSnapshot = (try? MissionSnapshotItem.encode(items)) ?? morning.missionsSnapshot
        morning.updatedAt = now
        morning.syncStatus = .pending
        recomputeScore(for: morning)
        Telemetry.track(.missionCompleted, properties: [
            "template": items[index].template,
            "has_proof": String(items[index].requiresProof)
        ])
        revision += 1
    }

    // MARK: - Close / score lock

    /// Locks the score of every morning whose deadline has passed. Called
    /// on launch, foreground, and after alarm events.
    func finalizeDueMornings(now: Date = .now) {
        guard let modelContext else { return }
        let all = (try? modelContext.fetch(FetchDescriptor<Morning>())) ?? []
        var changed = false
        for morning in all where morning.scoreLockedAt == nil {
            guard let closeAt = morning.closeAt, closeAt <= now else { continue }
            recomputeScore(for: morning)
            morning.scoreLockedAt = closeAt
            morning.updatedAt = now
            morning.syncStatus = .pending
            changed = true
            Telemetry.track(.morningClosed, properties: [
                "result": morning.result?.rawValue ?? "none",
                "score": String(morning.score ?? 0),
                "streak": String(currentStreak()),
                "clock_tampered": String(morning.clockTampered)
            ])
        }
        if changed {
            refreshStreak()
            revision += 1
        }
    }

    private func recomputeScore(for morning: Morning) {
        let items = missionItems(for: morning)
        morning.score = ScoreCalculator.score(
            wokeOnTime: morning.result == .win,
            completedMissions: items.filter(\.isCompleted).count,
            totalMissions: items.count
        )
    }

    // MARK: - Streak + history

    func currentStreak(now: Date = .now) -> Int {
        StreakEngine.currentStreak(winKeys: winKeys(), today: MorningDateKey.key(for: now, in: .current))
    }

    func history(days: Int = 30, now: Date = .now) -> [DayEntry] {
        let all = (try? modelContext?.fetch(FetchDescriptor<Morning>())) ?? []
        let wins = Set(all.filter { $0.result == .win }.map(\.dateKey))
        let losses = Set(all.filter { $0.result == .loss }.map(\.dateKey))
        return StreakEngine.history(
            endingAt: MorningDateKey.key(for: now, in: .current),
            days: days,
            winKeys: wins,
            lossKeys: losses
        )
    }

    /// Keeps the persisted StreakState (read by the future widget) current.
    private func refreshStreak(now: Date = .now) {
        guard let modelContext else { return }
        let wins = winKeys()
        let current = StreakEngine.currentStreak(winKeys: wins, today: MorningDateKey.key(for: now, in: .current))
        let longest = StreakEngine.longestStreak(winKeys: wins)
        let state: StreakState
        if let existing = try? modelContext.fetch(FetchDescriptor<StreakState>()).first {
            state = existing
        } else {
            state = StreakState()
            modelContext.insert(state)
        }
        state.currentStreak = current
        state.longestStreak = max(longest, state.longestStreak)
        state.lastWinDateKey = wins.max()
        state.updatedAt = now
    }

    private func winKeys() -> Set<String> {
        let all = (try? modelContext?.fetch(FetchDescriptor<Morning>())) ?? []
        return Set(all.filter { $0.result == .win }.map(\.dateKey))
    }

    // MARK: - Fetch helpers

    private func snapshotActiveMissions() -> Data {
        guard let modelContext else { return Data("[]".utf8) }
        var descriptor = FetchDescriptor<Mission>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.position)]
        )
        descriptor.fetchLimit = MissionRules.morningListRange.upperBound
        let missions = (try? modelContext.fetch(descriptor)) ?? []
        let items = missions.map { mission in
            MissionSnapshotItem(
                id: mission.id,
                title: mission.title,
                template: mission.template,
                proofKind: mission.proofType?.rawValue,
                proofReferenceID: mission.proofReferenceID
            )
        }
        return (try? MissionSnapshotItem.encode(items)) ?? Data("[]".utf8)
    }

    private func fetchMorning(dateKey: String) -> Morning? {
        guard let modelContext else { return nil }
        var descriptor = FetchDescriptor<Morning>(predicate: #Predicate { $0.dateKey == dateKey })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchConfig(_ alarmID: UUID) -> AlarmConfig? {
        guard let modelContext else { return nil }
        var descriptor = FetchDescriptor<AlarmConfig>(predicate: #Predicate { $0.id == alarmID })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}
