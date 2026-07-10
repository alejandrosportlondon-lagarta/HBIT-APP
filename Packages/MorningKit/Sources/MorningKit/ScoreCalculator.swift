import Foundation

/// Today's Score (0–100). Weighted per TASKS.md: waking on time is worth
/// ≈ 40%, the remainder is split evenly across the morning's missions.
/// With no missions the wake component is the whole score (renormalized) —
/// a mission-less WIN is still a 100, not a 40.
public enum ScoreCalculator {
    public static let wakeWeight = 0.4

    public static func score(wokeOnTime: Bool, completedMissions: Int, totalMissions: Int) -> Int {
        let wake = wokeOnTime ? 1.0 : 0.0
        guard totalMissions > 0 else {
            return Int((wake * 100).rounded())
        }
        let completed = min(max(0, completedMissions), totalMissions)
        let missions = Double(completed) / Double(totalMissions)
        let value = wakeWeight * wake + (1 - wakeWeight) * missions
        return Int((value * 100).rounded())
    }
}
