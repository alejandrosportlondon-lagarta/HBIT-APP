import AlarmEngine
import ProofKit
import SwiftData
import SwiftUI

/// Milestone 1 home: set the (single, free-tier) alarm and see the next
/// fire time. The full home screen with streak and history is Milestone 4.
struct HomeView: View {
    @Environment(AuthService.self) private var auth
    @Environment(AlarmCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext
    @Query private var configs: [AlarmConfig]
    @Query(sort: \Morning.createdAt, order: .reverse) private var mornings: [Morning]

    @State private var selectedTime = Calendar.current.date(
        bySettingHour: 7, minute: 0, second: 0, of: .now
    ) ?? .now
    @State private var proofType: ProofType = .math
    @State private var mathDifficulty: MathDifficulty = .easy
    @State private var stepsTarget = 20
    @State private var registeredBarcode: (id: UUID, summary: String)?
    @State private var showingBarcodeRegistration = false
    @State private var saveWarning: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Text("The Verified Morning")
                    .font(DesignSystem.Typography.title)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                alarmCard

                if let warning = coordinator.userWarning {
                    Text(warning)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .multilineTextAlignment(.center)
                }

                recentMornings

                Spacer()

                #if DEBUG
                NavigationLink("Reliability Harness") {
                    DebugHarnessView()
                }
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                #endif
            }
            .padding(DesignSystem.Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignSystem.Colors.background)
            .onAppear(perform: loadConfiguredTime)
        }
    }

    private var alarmCard: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            DatePicker("Alarm time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)

            ProofSettingsSection(
                proofType: $proofType,
                mathDifficulty: $mathDifficulty,
                stepsTarget: $stepsTarget,
                barcodeSummary: registeredBarcode?.summary
            ) {
                showingBarcodeRegistration = true
            }
            .sheet(isPresented: $showingBarcodeRegistration) {
                BarcodeRegistrationView { payload, symbology in
                    registerBarcode(payload: payload, symbology: symbology)
                }
            }

            if let saveWarning {
                Text(saveWarning)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.accent)
            }

            Button {
                Task { await saveAndSchedule() }
            } label: {
                Text(coordinator.nextFireDate == nil ? "Set alarm" : "Update alarm")
                    .font(DesignSystem.Typography.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.Colors.primary)

            if let next = coordinator.nextFireDate {
                Text("Next alarm: \(next.formatted(date: .abbreviated, time: .shortened))")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
    }

    private var recentMornings: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            ForEach(mornings.prefix(5)) { morning in
                HStack {
                    Text(morning.dateKey)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Spacer()
                    Text(morning.result?.rawValue.uppercased() ?? "—")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(
                            morning.result == .win
                                ? DesignSystem.Colors.success
                                : DesignSystem.Colors.accent
                        )
                }
            }
        }
    }

    private func loadConfiguredTime() {
        guard let config = configs.first else { return }
        selectedTime = Calendar.current.date(
            bySettingHour: config.hour, minute: config.minute, second: 0, of: .now
        ) ?? selectedTime
        loadProofSettings(from: config)
    }

    private func loadProofSettings(from config: AlarmConfig) {
        proofType = config.proofType == .photoMatch ? .math : config.proofType
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
            break
        }
    }

    private func saveAndSchedule() async {
        saveWarning = nil
        if proofType == .barcode && registeredBarcode == nil {
            saveWarning = "Register a barcode first — it's what you'll scan to dismiss the alarm."
            return
        }
        let components = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        let hour = components.hour ?? 7
        let minute = components.minute ?? 0

        let config: AlarmConfig
        if let existing = configs.first {
            existing.hour = hour
            existing.minute = minute
            existing.timeZoneID = TimeZone.current.identifier
            existing.updatedAt = .now
            config = existing
        } else {
            // Free tier: exactly one alarm (PaywallKit.FreeTierLimits).
            config = AlarmConfig(hour: hour, minute: minute)
            modelContext.insert(config)
        }
        config.proofType = proofType
        attachProofReference(to: config)
        await coordinator.scheduleAlarm(config: config)
    }

    /// Persists the proof configuration as the alarm's ProofReference:
    /// math/steps payloads are (re)generated from the pickers; barcode uses
    /// the reference created at registration time.
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
            break
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

    private func fetchReference(_ id: UUID?) -> ProofReference? {
        guard let id else { return nil }
        var descriptor = FetchDescriptor<ProofReference>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private static func summary(forBarcode payload: String) -> String {
        let normalized = BarcodeMatcher.normalize(payload)
        let tail = String(normalized.suffix(4))
        return "Registered code ••\(tail)"
    }
}
