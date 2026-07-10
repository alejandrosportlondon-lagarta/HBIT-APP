#if DEBUG
import ProofKit
import SwiftUI

/// Reliability harness (Debug builds only): fire test alarms on demand and
/// track the manual scenario matrix from
/// `docs/testing/alarm-reliability-test-plan.md`. Checklist state persists
/// in UserDefaults so a dogfood week accumulates results.
struct DebugHarnessView: View {
    static let scenarios: [(id: String, title: String)] = [
        ("s01", "Foreground ring"),
        ("s02", "Background ring"),
        ("s03", "App killed"),
        ("s04", "Reboot mid-ring"),
        ("s05", "Silent switch on"),
        ("s06", "Focus / DND on"),
        ("s07", "Low Power Mode"),
        ("s08", "Storage nearly full"),
        ("s09", "DST spring-forward"),
        ("s10", "DST fall-back"),
        ("s11", "Notifications denied"),
        ("s12", "Ring-window expiry")
    ]

    @Environment(AlarmCoordinator.self) private var coordinator
    @State private var pendingCount = 0
    @State private var thresholdOverrideEnabled = PhotoProofService.thresholdOverride != nil
    @State private var thresholdValue = PhotoProofService.thresholdOverride ?? PhotoMatchRule.defaultThreshold

    var body: some View {
        List {
            Section("Test alarms") {
                Button("Ring in 10 seconds") {
                    Task { await coordinator.scheduleTestAlarm(inSeconds: 10) }
                }
                Button("Ring in 2 minutes") {
                    Task { await coordinator.scheduleTestAlarm(inSeconds: 120) }
                }
                Button("Cancel active alarm", role: .destructive) {
                    Task { await coordinator.cancelActiveAlarm() }
                }
                LabeledContent("Pending chain notifications", value: "\(pendingCount)")
                if let next = coordinator.activeSnapshot?.fireDate {
                    LabeledContent("Active fire date", value: next.formatted(date: .omitted, time: .standard))
                }
                LabeledContent("Machine state", value: coordinator.machine.state.rawValue)
            }

            Section("Photo proof threshold (final value set in beta)") {
                Toggle("Override registered threshold", isOn: $thresholdOverrideEnabled)
                    .onChange(of: thresholdOverrideEnabled) { _, enabled in
                        PhotoProofService.setThresholdOverride(enabled ? thresholdValue : nil)
                    }
                if thresholdOverrideEnabled {
                    HStack {
                        Slider(value: $thresholdValue, in: PhotoMatchRule.thresholdRange)
                            .onChange(of: thresholdValue) { _, value in
                                PhotoProofService.setThresholdOverride(value)
                            }
                        Text(String(format: "%.2f", thresholdValue))
                            .monospacedDigit()
                    }
                }
            }

            Section("Scenario matrix (see docs/testing/alarm-reliability-test-plan.md)") {
                ForEach(Self.scenarios, id: \.id) { scenario in
                    ScenarioRow(id: scenario.id, title: scenario.title)
                }
            }
        }
        .navigationTitle("Reliability Harness")
        .task { await refreshPendingCount() }
        .refreshable { await refreshPendingCount() }
    }

    private func refreshPendingCount() async {
        pendingCount = await coordinator.pendingChainCount()
    }
}

private struct ScenarioRow: View {
    let id: String
    let title: String
    @AppStorage private var status: Int // 0 untested, 1 pass, 2 fail

    init(id: String, title: String) {
        self.id = id
        self.title = title
        _status = AppStorage(wrappedValue: 0, "hbit.harness.\(id)")
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Picker("", selection: $status) {
                Text("—").tag(0)
                Text("Pass").tag(1)
                Text("Fail").tag(2)
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
        }
    }
}
#endif
