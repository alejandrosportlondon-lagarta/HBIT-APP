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

    var state: AlarmState {
        get { AlarmState(rawValue: stateRaw) ?? .scheduled }
        set { stateRaw = newValue.rawValue }
    }
}

@MainActor
final class AlarmRuntimeStore {
    private static let key = "hbit.alarm.runtime.v1"
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
}
