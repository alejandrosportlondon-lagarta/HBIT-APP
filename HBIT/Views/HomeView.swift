import AlarmEngine
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
    }

    private func saveAndSchedule() async {
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
        await coordinator.scheduleAlarm(config: config)
    }
}
