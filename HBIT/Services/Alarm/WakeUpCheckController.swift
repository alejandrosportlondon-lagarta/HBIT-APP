import AlarmEngine
import Foundation
import Observation

/// The Wake-Up Check (ADR 002 / TASKS M3): N minutes after a successful
/// dismissal, a check notification fires. Acknowledging it (notification
/// tap, action button, or the in-app card) cancels everything; missing it
/// re-fires the alarm once via a normal chain whose snapshot is marked as
/// a refire so it can't loop.
@MainActor
@Observable
final class WakeUpCheckController {
    static let allowedMinutes = 3...10
    /// How long after the check fires before the alarm re-fires.
    static let grace: TimeInterval = 180

    private let scheduler: any NotificationScheduling
    private let store: AlarmRuntimeStore
    /// Called when the check resolves (acknowledged or cancelled) so the
    /// owner can schedule the next regular occurrence.
    private let onResolved: @MainActor () async -> Void

    private(set) var pending: WakeUpCheckState?

    init(
        scheduler: any NotificationScheduling,
        store: AlarmRuntimeStore,
        onResolved: @escaping @MainActor () async -> Void
    ) {
        self.scheduler = scheduler
        self.store = store
        self.onResolved = onResolved
        self.pending = store.wakeUpCheck
    }

    func schedule(minutes: Int, alarmID: UUID, now: Date = .now) async {
        let clamped = min(Self.allowedMinutes.upperBound, max(Self.allowedMinutes.lowerBound, minutes))
        let checkDate = now.addingTimeInterval(Double(clamped) * 60)
        let refireDate = checkDate.addingTimeInterval(Self.grace)
        let checkBase = "hbit-wakecheck-\(UUID().uuidString)"
        let refireBase = "hbit-alarm-refire-\(UUID().uuidString)"
        do {
            try await scheduler.schedule(
                NotificationChainPlan(baseIdentifier: checkBase, fireDate: checkDate, ringWindow: 0),
                title: "Wake-Up Check",
                body: "Still up? Tap to confirm — or your alarm re-fires.",
                category: UserNotificationScheduler.wakeUpCheckCategoryIdentifier
            )
            try await scheduler.schedule(
                NotificationChainPlan(baseIdentifier: refireBase, fireDate: refireDate),
                title: "Wake up — HBIT",
                body: "You missed your Wake-Up Check. The alarm is back — prove you're up.",
                category: UserNotificationScheduler.alarmCategoryIdentifier
            )
            let state = WakeUpCheckState(
                checkBaseIdentifier: checkBase,
                checkFireDate: checkDate,
                refireBaseIdentifier: refireBase,
                refireDate: refireDate
            )
            store.save(wakeUpCheck: state)
            pending = state
            store.save(AlarmRuntimeSnapshot(
                alarmID: alarmID,
                baseIdentifier: refireBase,
                fireDate: refireDate,
                stateRaw: AlarmState.scheduled.rawValue,
                isWakeUpCheckRefire: true
            ))
        } catch {
            Telemetry.capture(error: error, context: ["phase": "wake_check_schedule"])
            await onResolved()
        }
    }

    /// The user confirmed they're up (notification tap/action or home card).
    func acknowledge() async {
        guard let state = store.wakeUpCheck else { return }
        Telemetry.track(.wakeUpCheckPassed)
        await scheduler.cancelChain(baseIdentifier: state.checkBaseIdentifier)
        await scheduler.cancelChain(baseIdentifier: state.refireBaseIdentifier)
        store.clearWakeUpCheck()
        pending = nil
        // The armed refire occurrence is obsolete.
        if let snapshot = store.snapshot, snapshot.isRefire {
            store.clear()
        }
        await onResolved()
    }

    /// Called when an alarm chain starts ringing: if it is this check's
    /// refire, the check was missed.
    func markMissedIfNeeded(firedBaseIdentifier: String) {
        guard let state = store.wakeUpCheck, state.refireBaseIdentifier == firedBaseIdentifier else { return }
        Telemetry.track(.wakeUpCheckMissed)
        let checkBase = state.checkBaseIdentifier
        Task { await scheduler.cancelChain(baseIdentifier: checkBase) }
        store.clearWakeUpCheck()
        pending = nil
    }

    func cancelAll() async {
        guard let state = store.wakeUpCheck else { return }
        await scheduler.cancelChain(baseIdentifier: state.checkBaseIdentifier)
        await scheduler.cancelChain(baseIdentifier: state.refireBaseIdentifier)
        store.clearWakeUpCheck()
        pending = nil
    }
}
