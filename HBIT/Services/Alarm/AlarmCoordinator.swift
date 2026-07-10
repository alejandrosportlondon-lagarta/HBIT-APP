import AlarmEngine
import Foundation
import MorningKit
import Observation
import ProofKit
import SwiftData

/// The proof resolved for the active alarm occurrence.
enum ActiveProof {
    case math(MathProofConfig)
    case steps(StepsProofConfig)
    case barcode(BarcodeProofConfig)
    case photo(PhotoProofConfig)
    /// Test alarms / nothing configured.
    case placeholder

    var kindLabel: String {
        switch self {
        case .math: "math"
        case .steps: "steps"
        case .barcode: "barcode"
        case .photo: "photoMatch"
        case .placeholder: "placeholder"
        }
    }
}

/// Orchestrates the alarm lifecycle: schedules the notification chain,
/// drives the state machine from notification/launch events, owns the
/// ringing UI presentation and audio, records the morning's WIN/LOSS, and
/// implements restart resilience (ADR 002).
@MainActor
@Observable
final class AlarmCoordinator {
    private let scheduler: any NotificationScheduling
    private let store: AlarmRuntimeStore
    private let audio = AlarmAudioPlayer()
    private let clockMonitor = ClockIntegrityMonitor()
    private var modelContext: ModelContext?
    private var expiryWatchdog: Task<Void, Never>?
    private(set) var wakeUpCheck: WakeUpCheckController?

    private(set) var machine = AlarmStateMachine()
    private(set) var activeSnapshot: AlarmRuntimeSnapshot?
    /// Drives the full-screen ringing cover. Only the coordinator sets it.
    var isPresentingAlarm = false
    /// Surface for non-fatal problems (authorization denied, etc.).
    private(set) var userWarning: String?

    init(scheduler: any NotificationScheduling = UserNotificationScheduler(),
         store: AlarmRuntimeStore = AlarmRuntimeStore()) {
        self.scheduler = scheduler
        self.store = store
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        if wakeUpCheck == nil {
            wakeUpCheck = WakeUpCheckController(scheduler: scheduler, store: store) { [weak self] in
                await self?.rescheduleFromConfig()
            }
        }
    }

    var nextFireDate: Date? {
        guard let snapshot = activeSnapshot, snapshot.state == .scheduled else { return nil }
        return snapshot.fireDate
    }

    // MARK: - Scheduling

    func scheduleAlarm(config: AlarmConfig, after now: Date = .now) async {
        let timeZone = TimeZone(identifier: config.timeZoneID) ?? .current
        guard let fireDate = AlarmOccurrenceCalculator.nextFireDate(
            hour: config.hour, minute: config.minute, timeZone: timeZone, after: now
        ) else {
            userWarning = "Could not compute the next alarm time."
            return
        }
        await schedule(fireDate: fireDate, alarmID: config.id, proofType: config.proofType.rawValue)
    }

    /// Reliability-harness entry point: ring N seconds from now.
    func scheduleTestAlarm(inSeconds seconds: TimeInterval, now: Date = .now) async {
        await schedule(fireDate: now.addingTimeInterval(seconds), alarmID: UUID(), proofType: "test")
    }

    private func schedule(fireDate: Date, alarmID: UUID, proofType: String) async {
        do {
            let granted = try await scheduler.requestAuthorization()
            userWarning = granted ? nil :
                "Notifications are disabled — the alarm cannot ring. Enable them in Settings."

            if let previous = store.snapshot {
                await scheduler.cancelChain(baseIdentifier: previous.baseIdentifier)
            }
            let base = "hbit-alarm-\(alarmID.uuidString)-\(Int(fireDate.timeIntervalSince1970))"
            let plan = NotificationChainPlan(baseIdentifier: base, fireDate: fireDate)
            try await scheduler.schedule(
                plan,
                title: "Wake up — HBIT",
                body: "Your alarm is ringing. Open HBIT and complete your proof to dismiss it.",
                category: UserNotificationScheduler.alarmCategoryIdentifier
            )
            let snapshot = AlarmRuntimeSnapshot(
                alarmID: alarmID, baseIdentifier: base, fireDate: fireDate,
                stateRaw: AlarmState.scheduled.rawValue
            )
            store.save(snapshot)
            activeSnapshot = snapshot
            machine = AlarmStateMachine()
            Telemetry.track(.alarmScheduled, properties: ["proof_type": proofType])
        } catch {
            userWarning = "Failed to schedule the alarm: \(error.localizedDescription)"
            Telemetry.capture(error: error, context: ["phase": "alarm_schedule"])
        }
    }

    func cancelActiveAlarm() async {
        expiryWatchdog?.cancel()
        if let snapshot = activeSnapshot ?? store.snapshot {
            await scheduler.cancelChain(baseIdentifier: snapshot.baseIdentifier)
        }
        await wakeUpCheck?.cancelAll()
        store.clear()
        activeSnapshot = nil
        machine = AlarmStateMachine()
        stopRinging()
    }

    // MARK: - Restart resilience

    /// Called at every launch and foreground: reconciles persisted state
    /// with the ring window (ADR 002).
    func resume(now: Date = .now) {
        clockMonitor.observe(now: now)
        guard let snapshot = store.snapshot else { return }
        activeSnapshot = snapshot
        machine = AlarmStateMachine(state: snapshot.state)
        guard !snapshot.state.isTerminal else {
            store.clear()
            activeSnapshot = nil
            return
        }
        switch RingWindow(fireDate: snapshot.fireDate).phase(at: now) {
        case .pending:
            break
        case .ringing:
            if machine.state == .scheduled {
                alarmDidFire()
            } else {
                presentRinging()
            }
        case .expired:
            if machine.state == .scheduled { machine.handle(.fire) }
            machine.handle(.expire)
            finish(result: .loss, wakeActual: nil)
        }
    }

    // MARK: - Events

    /// A chain notification fired while the app was frontmost, or the user
    /// tapped one.
    func alarmDidFire() {
        clockMonitor.observe()
        // A Wake-Up Check refire arrives after the previous occurrence
        // finished; reload it from the store.
        if activeSnapshot == nil, let stored = store.snapshot {
            activeSnapshot = stored
            machine = AlarmStateMachine(state: stored.state)
        }
        if let base = activeSnapshot?.baseIdentifier {
            wakeUpCheck?.markMissedIfNeeded(firedBaseIdentifier: base)
        }
        if machine.handle(.fire) != nil {
            persistState()
            Telemetry.track(.alarmRang)
        }
        // Whether this was the first entry of the chain or the fifteenth,
        // a live alarm means the ringing UI must be up.
        if machine.state == .ringing || machine.state == .proofInProgress {
            presentRinging()
        }
    }

    func beginProof() {
        if machine.handle(.beginProof) != nil {
            persistState()
            Telemetry.track(.proofStarted, properties: ["proof_type": resolveActiveProof().kindLabel])
        }
    }

    func abandonProof() {
        if machine.handle(.proofFailed) != nil { persistState() }
    }

    /// Called by the proof views when their session completes.
    func completeProof() {
        let kind = resolveActiveProof().kindLabel
        if machine.handle(.proofSucceeded) != nil {
            Telemetry.track(.proofCompleted, properties: ["proof_type": kind])
            Telemetry.track(.alarmDismissed)
            finish(result: .win, wakeActual: .now)
        }
    }

    /// Called by proof views on a failed attempt (wrong answer/wrong code).
    func reportProofFailure() {
        Telemetry.track(.proofFailed, properties: ["proof_type": resolveActiveProof().kindLabel])
    }

    /// Resolves the configured proof for the ringing alarm from the local
    /// store. Fallback rules keep verification deterministic and the alarm
    /// always dismissable: a test alarm gets the placeholder; a missing or
    /// corrupt payload falls back to easy math rather than an unpassable
    /// (false-negative) proof.
    func resolveActiveProof() -> ActiveProof {
        guard let snapshot = activeSnapshot, let modelContext else { return .placeholder }
        let alarmID = snapshot.alarmID
        var configDescriptor = FetchDescriptor<AlarmConfig>(predicate: #Predicate { $0.id == alarmID })
        configDescriptor.fetchLimit = 1
        guard let config = try? modelContext.fetch(configDescriptor).first else { return .placeholder }

        let fallback = ActiveProof.math(MathProofConfig(difficulty: .easy))
        guard let referenceID = config.proofReferenceID else {
            return config.proofType == .steps ? .steps(StepsProofConfig(targetSteps: 20)) : fallback
        }
        var referenceDescriptor = FetchDescriptor<ProofReference>(predicate: #Predicate { $0.id == referenceID })
        referenceDescriptor.fetchLimit = 1
        guard let reference = try? modelContext.fetch(referenceDescriptor).first else { return fallback }

        switch reference.kind {
        case .math:
            return (try? MathProofConfig.from(payload: reference.payload)).map(ActiveProof.math) ?? fallback
        case .steps:
            return (try? StepsProofConfig.from(payload: reference.payload)).map(ActiveProof.steps) ?? fallback
        case .barcode:
            return (try? BarcodeProofConfig.from(payload: reference.payload)).map(ActiveProof.barcode) ?? fallback
        case .photoMatch:
            return (try? PhotoProofConfig.from(payload: reference.payload)).map(ActiveProof.photo) ?? fallback
        }
    }

    /// Called after the tap challenge completes. Records a LOSS morning.
    func performEmergencyExit(tapCost: Int, effectiveUses: Int) {
        if machine.handle(.emergencyExit) != nil {
            Telemetry.track(.emergencyExitUsed, properties: [
                "tap_cost": String(tapCost),
                "use_count_30d": String(effectiveUses)
            ])
            finish(result: .loss, wakeActual: .now)
        }
    }

    // MARK: - Internals

    private func presentRinging() {
        isPresentingAlarm = true
        audio.start()
        armExpiryWatchdog()
    }

    private func stopRinging() {
        audio.stop()
        isPresentingAlarm = false
    }

    private func armExpiryWatchdog() {
        guard expiryWatchdog == nil, let snapshot = activeSnapshot else { return }
        let deadline = RingWindow(fireDate: snapshot.fireDate).endDate
        expiryWatchdog = Task { [weak self] in
            let interval = deadline.timeIntervalSinceNow
            if interval > 0 {
                try? await Task.sleep(for: .seconds(interval))
            }
            guard let self, !Task.isCancelled else { return }
            if self.machine.handle(.expire) != nil {
                self.finish(result: .loss, wakeActual: nil)
            }
        }
    }

    private func finish(result: MorningResult, wakeActual: Date?) {
        expiryWatchdog?.cancel()
        expiryWatchdog = nil
        let snapshot = activeSnapshot
        stopRinging()
        recordMorning(result: result, wakeActual: wakeActual, snapshot: snapshot)
        store.clear()
        activeSnapshot = nil
        if let snapshot {
            Task { await scheduler.cancelChain(baseIdentifier: snapshot.baseIdentifier) }
        }
        // A WIN with a Wake-Up Check configured arms the check instead of
        // scheduling tomorrow immediately (that happens when the check
        // resolves). Refire occurrences never arm another check.
        if result == .win,
           let snapshot,
           !snapshot.isRefire,
           let minutes = wakeUpCheckMinutes(forAlarmID: snapshot.alarmID),
           let wakeUpCheck {
            Task { await wakeUpCheck.schedule(minutes: minutes, alarmID: snapshot.alarmID) }
        } else {
            Task { await rescheduleFromConfig() }
        }
    }

    private func wakeUpCheckMinutes(forAlarmID alarmID: UUID) -> Int? {
        guard let modelContext else { return nil }
        var descriptor = FetchDescriptor<AlarmConfig>(predicate: #Predicate { $0.id == alarmID })
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor).first)?.wakeUpCheckMinutes
    }

    private func persistState() {
        guard var snapshot = activeSnapshot else { return }
        snapshot.state = machine.state
        store.save(snapshot)
        activeSnapshot = snapshot
    }

    /// One row per day: today's morning is created or updated in the local
    /// store; SyncKit reconciles it to Supabase later.
    private func recordMorning(result: MorningResult, wakeActual: Date?, snapshot: AlarmRuntimeSnapshot?) {
        guard let modelContext, let snapshot else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        let dateKey = formatter.string(from: snapshot.fireDate)

        let tampered = clockMonitor.consumeTamperFlag()
        let descriptor = FetchDescriptor<Morning>(predicate: #Predicate { $0.dateKey == dateKey })
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.result = result
            existing.wakeActual = wakeActual
            existing.updatedAt = .now
            existing.syncStatus = .pending
            existing.clockTampered = existing.clockTampered || tampered
        } else {
            let morning = Morning(
                dateKey: dateKey,
                wakeTarget: snapshot.fireDate,
                wakeActual: wakeActual,
                result: result
            )
            morning.clockTampered = tampered
            modelContext.insert(morning)
        }
        Telemetry.track(.morningClosed, properties: [
            "result": result.rawValue,
            "clock_tampered": String(tampered)
        ])
    }

    private func rescheduleFromConfig() async {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<AlarmConfig>(predicate: #Predicate { $0.isEnabled })
        guard let config = try? modelContext.fetch(descriptor).first else { return }
        await scheduleAlarm(config: config)
    }

    // MARK: - Harness support

    func pendingChainCount() async -> Int {
        guard let snapshot = activeSnapshot ?? store.snapshot else { return 0 }
        return await scheduler.pendingCount(baseIdentifier: snapshot.baseIdentifier)
    }
}
