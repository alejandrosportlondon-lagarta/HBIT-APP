import AlarmEngine
import MorningKit
import ProofKit
import SwiftData
import SwiftUI

/// The alarm configuration card: time, proof, wake-up check, morning close
/// — disabled with an explanation while the goal lock is engaged.
struct AlarmSetupCard: View {
    @Environment(AlarmCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext
    @Query private var configs: [AlarmConfig]

    @State private var selectedTime = Calendar.current.date(
        bySettingHour: 7, minute: 0, second: 0, of: .now
    ) ?? .now
    @State private var proofType: ProofType = .math
    @State private var mathDifficulty: MathDifficulty = .easy
    @State private var stepsTarget = 20
    @State private var registeredBarcode: (id: UUID, summary: String)?
    @State private var registeredPhoto: (id: UUID, summary: String)?
    @State private var showingBarcodeRegistration = false
    @State private var showingPhotoRegistration = false
    @State private var wakeUpCheckMinutes = 0
    @State private var morningCloseHours = AlarmConfig.defaultMorningCloseHours
    @State private var saveWarning: String?

    private var isLocked: Bool {
        if case .open = coordinator.goalLockPhase() { return false }
        return true
    }

    private var lockLabel: String? {
        switch coordinator.goalLockPhase() {
        case .open:
            return nil
        case .lockedUntilFire(let fireDate):
            return "Goal locked until the alarm (\(fireDate.formatted(date: .omitted, time: .shortened)))"
        case .lockedUntilClose(let closeAt):
            return "Goal locked until the morning closes (\(closeAt.formatted(date: .omitted, time: .shortened)))"
        }
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            if let lockLabel {
                Label(lockLabel, systemImage: "lock.fill")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.accent)
            }

            Group {
                DatePicker("Alarm time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)

                ProofSettingsSection(
                    proofType: $proofType,
                    mathDifficulty: $mathDifficulty,
                    stepsTarget: $stepsTarget,
                    barcodeSummary: registeredBarcode?.summary,
                    photoSummary: registeredPhoto?.summary,
                    onRegisterBarcode: { showingBarcodeRegistration = true },
                    onRegisterPhoto: { showingPhotoRegistration = true }
                )

                Picker("Wake-Up Check", selection: $wakeUpCheckMinutes) {
                    Text("Check: off").tag(0)
                    ForEach([3, 5, 10], id: \.self) { minutes in
                        Text("Check: \(minutes) min").tag(minutes)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Morning closes", selection: $morningCloseHours) {
                    ForEach([2, 3, 4], id: \.self) { hours in
                        Text("Closes +\(hours)h").tag(hours)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    Task { await saveAndSchedule() }
                } label: {
                    Text(coordinator.nextFireDate == nil ? "Set alarm" : "Update alarm")
                        .font(DesignSystem.Typography.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.Colors.primary)
            }
            .disabled(isLocked)
            .opacity(isLocked ? 0.6 : 1)

            if let saveWarning {
                Text(saveWarning)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.accent)
            }
            if let next = coordinator.nextFireDate {
                Text("Next alarm: \(next.formatted(date: .abbreviated, time: .shortened))")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            if let warning = coordinator.userWarning {
                Text(warning)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .onAppear(perform: loadConfigured)
        .sheet(isPresented: $showingBarcodeRegistration) {
            BarcodeRegistrationView { payload, symbology in
                registerBarcode(payload: payload, symbology: symbology)
            }
        }
        .sheet(isPresented: $showingPhotoRegistration) {
            PhotoRegistrationView { photoConfig in
                registerPhoto(photoConfig)
            }
        }
    }

    // MARK: - Load

    private func loadConfigured() {
        guard let config = configs.first else { return }
        selectedTime = Calendar.current.date(
            bySettingHour: config.hour, minute: config.minute, second: 0, of: .now
        ) ?? selectedTime
        wakeUpCheckMinutes = config.wakeUpCheckMinutes ?? 0
        morningCloseHours = config.effectiveMorningCloseHours
        loadProofSettings(from: config)
    }

    private func loadProofSettings(from config: AlarmConfig) {
        proofType = config.proofType
        guard let reference = fetchReference(config.proofReferenceID) else { return }
        switch reference.kind {
        case .math:
            if let decoded = try? MathProofConfig.from(payload: reference.payload) {
                mathDifficulty = decoded.difficulty
            }
        case .steps:
            if let decoded = try? StepsProofConfig.from(payload: reference.payload) {
                stepsTarget = decoded.targetSteps
            }
        case .barcode:
            if let decoded = try? BarcodeProofConfig.from(payload: reference.payload) {
                registeredBarcode = (reference.id, Self.summary(forBarcode: decoded.payload))
            }
        case .photoMatch:
            if (try? PhotoProofConfig.from(payload: reference.payload)) != nil {
                registeredPhoto = (reference.id, "Reference photo registered")
            }
        }
    }

    // MARK: - Save

    private func saveAndSchedule() async {
        saveWarning = nil
        if proofType == .barcode && registeredBarcode == nil {
            saveWarning = "Register a barcode first — it's what you'll scan to dismiss the alarm."
            return
        }
        if proofType == .photoMatch && registeredPhoto == nil {
            saveWarning = "Register a reference photo first — it's what you'll re-take to dismiss the alarm."
            return
        }
        let components = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        let config: AlarmConfig
        if let existing = configs.first {
            existing.hour = components.hour ?? 7
            existing.minute = components.minute ?? 0
            existing.timeZoneID = TimeZone.current.identifier
            existing.updatedAt = .now
            config = existing
        } else {
            config = AlarmConfig(hour: components.hour ?? 7, minute: components.minute ?? 0)
            modelContext.insert(config)
        }
        config.proofType = proofType
        config.wakeUpCheckMinutes = wakeUpCheckMinutes == 0 ? nil : wakeUpCheckMinutes
        config.morningCloseHoursAfterWake = morningCloseHours
        attachProofReference(to: config)
        await coordinator.userUpdateAlarm(config: config)
    }

    private func attachProofReference(to config: AlarmConfig) {
        switch proofType {
        case .math:
            upsertGeneratedReference(
                kind: .math,
                payload: try? MathProofConfig(difficulty: mathDifficulty).payloadData(),
                on: config
            )
        case .steps:
            upsertGeneratedReference(
                kind: .steps,
                payload: try? StepsProofConfig(targetSteps: stepsTarget).payloadData(),
                on: config
            )
        case .barcode:
            config.proofReferenceID = registeredBarcode?.id
        case .photoMatch:
            config.proofReferenceID = registeredPhoto?.id
        }
    }

    private func upsertGeneratedReference(kind: ProofType, payload: Data?, on config: AlarmConfig) {
        guard let payload else { return }
        if let existing = fetchReference(config.proofReferenceID), existing.kind == kind {
            existing.payload = payload
            existing.updatedAt = .now
            existing.syncStatus = .pending
        } else {
            let reference = ProofReference(kind: kind, payload: payload)
            modelContext.insert(reference)
            config.proofReferenceID = reference.id
        }
    }

    private func registerBarcode(payload: String, symbology: String) {
        let barcodeConfig = BarcodeProofConfig(payload: payload, symbology: symbology)
        guard let data = try? barcodeConfig.payloadData() else { return }
        let reference = ProofReference(kind: .barcode, payload: data)
        modelContext.insert(reference)
        registeredBarcode = (reference.id, Self.summary(forBarcode: payload))
        saveWarning = nil
    }

    private func registerPhoto(_ photoConfig: PhotoProofConfig) {
        guard let data = try? photoConfig.payloadData() else { return }
        let reference = ProofReference(kind: .photoMatch, payload: data)
        modelContext.insert(reference)
        registeredPhoto = (reference.id, "Reference photo registered")
        saveWarning = nil
    }

    private func fetchReference(_ id: UUID?) -> ProofReference? {
        guard let id else { return nil }
        var descriptor = FetchDescriptor<ProofReference>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private static func summary(forBarcode payload: String) -> String {
        let normalized = BarcodeMatcher.normalize(payload)
        return "Registered code ••\(String(normalized.suffix(4)))"
    }
}
