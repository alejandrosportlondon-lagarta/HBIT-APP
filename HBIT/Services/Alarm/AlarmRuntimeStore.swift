import AlarmEngine
import Foundation

/// The persisted state of the active alarm occurrence — the backbone of
/// restart resilience (ADR 002). Written on every state change so that a
/// killed app or rebooted phone can resume exactly where the alarm was.
struct AlarmRuntimeSnapshot: Codable, Equatable {
    var alarmID: UUID
    var baseIdentifier: String
    var fireDate: Date
    var stateRaw: String
    /// This occurrence is the one-time re-fire of a missed Wake-Up Check
    /// (optional so snapshots persisted before this field decode fine).
    var isWakeUpCheckRefire: Bool?

    var state: AlarmState {
        get { AlarmState(rawValue: stateRaw) ?? .scheduled }
        set { stateRaw = newValue.rawValue }
    }

    var isRefire: Bool { isWakeUpCheckRefire ?? false }
}

/// Pending Wake-Up Check bookkeeping, persisted alongside the snapshot.
struct WakeUpCheckState: Codable, Equatable {
    /// Notification base identifier of the check reminder itself.
    var checkBaseIdentifier: String
    var checkFireDate: Date
    /// Chain that re-fires the alarm if the check goes unacknowledged.
    var refireBaseIdentifier: String
    var refireDate: Date
}

@MainActor
final class AlarmRuntimeStore {
    private static let key = "hbit.alarm.runtime.v1"
    private static let wakeCheckKey = "hbit.alarm.wakeupcheck.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var snapshot: AlarmRuntimeSnapshot? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(AlarmRuntimeSnapshot.self, from: data)
    }

    func save(_ snapshot: AlarmRuntimeSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.key)
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }

    var wakeUpCheck: WakeUpCheckState? {
        guard let data = defaults.data(forKey: Self.wakeCheckKey) else { return nil }
        return try? JSONDecoder().decode(WakeUpCheckState.self, from: data)
    }

    func save(wakeUpCheck: WakeUpCheckState) {
        guard let data = try? JSONEncoder().encode(wakeUpCheck) else { return }
        defaults.set(data, forKey: Self.wakeCheckKey)
    }

    func clearWakeUpCheck() {
        defaults.removeObject(forKey: Self.wakeCheckKey)
    }
}
