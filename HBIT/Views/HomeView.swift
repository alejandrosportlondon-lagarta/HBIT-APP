import MorningKit
import SwiftData
import SwiftUI

/// The home screen (Milestone 4): streak, 30-day history strip, today's
/// state, the mission list, and the alarm setup card — all goal-lock aware.
struct HomeView: View {
    @Environment(AlarmCoordinator.self) private var coordinator
    @Environment(MorningLedger.self) private var ledger
    @Query(filter: #Predicate<Mission> { $0.isActive }, sort: \Mission.position)
    private var activeMissions: [Mission]

    @State private var showingMissionEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                // Establishes an Observable dependency so derived values
                // (streak, history) refresh on every ledger mutation.
                let _ = ledger.revision // swiftlint:disable:this redundant_discardable_let
                VStack(spacing: DesignSystem.Spacing.lg) {
                    header
                    HistoryStripView(entries: ledger.history())

                    if coordinator.wakeUpCheck?.pending != nil {
                        wakeUpCheckCard
                    }
                    if let morning = ledger.todayMorning() {
                        TodayCard(morning: morning)
                    }

                    missionsSection
                    AlarmSetupCard()

                    #if DEBUG
                    NavigationLink("Reliability Harness") {
                        DebugHarnessView()
                    }
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    #endif
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.background)
            .sheet(isPresented: $showingMissionEditor) {
                MissionEditorView()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("The Verified Morning")
                .font(DesignSystem.Typography.title)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Spacer()
            Text("🔥 \(ledger.currentStreak())")
                .font(DesignSystem.Typography.numeric)
                .foregroundStyle(DesignSystem.Colors.accent)
        }
    }

    private var missionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("Missions")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer()
                Button("Edit") { showingMissionEditor = true }
                    .buttonStyle(.bordered)
                    .tint(DesignSystem.Colors.primary)
            }
            if activeMissions.count < MissionRules.morningListRange.lowerBound {
                Text("Add at least \(MissionRules.morningListRange.lowerBound) missions — they're 60% of your score.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.accent)
            } else {
                Text(activeMissions.map(\.title).joined(separator: " · "))
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
    }

    private var wakeUpCheckCard: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("Wake-Up Check pending")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Button {
                let controller = coordinator.wakeUpCheck
                Task { await controller?.acknowledge() }
            } label: {
                Text("I'm up ✓")
                    .font(DesignSystem.Typography.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.Colors.success)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
    }
}
