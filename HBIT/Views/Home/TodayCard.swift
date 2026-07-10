import MorningKit
import SwiftUI

/// Today's state: after a wake result exists, the mission checklist with a
/// live score until the close deadline, then the locked result.
struct TodayCard: View {
    @Environment(MorningLedger.self) private var ledger
    let morning: Morning

    @State private var provingItem: MissionSnapshotItem?

    private var items: [MissionSnapshotItem] { ledger.missionItems(for: morning) }
    private var isLocked: Bool { morning.scoreLockedAt != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text(isLocked ? "Today — locked" : "Today")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer()
                Text(morning.result?.rawValue.uppercased() ?? "—")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(
                        morning.result == .win ? DesignSystem.Colors.success : DesignSystem.Colors.accent
                    )
            }

            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.sm) {
                Text("\(morning.score ?? 0)")
                    .font(DesignSystem.Typography.numeric)
                    .foregroundStyle(DesignSystem.Colors.primary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: morning.score)
                Text("/ 100")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Spacer()
                if !isLocked, let closeAt = morning.closeAt {
                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        Text("locks \(closeAt, format: .relative(presentation: .named))")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
            }

            ForEach(items) { item in
                missionRow(item)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .sheet(item: $provingItem) { item in
            MissionProofSheet(item: item) {
                ledger.completeMission(id: item.id, in: morning)
                provingItem = nil
            }
        }
    }

    private func missionRow(_ item: MissionSnapshotItem) -> some View {
        Button {
            guard !isLocked, !item.isCompleted else { return }
            if item.requiresProof {
                provingItem = item
            } else {
                withAnimation(.snappy) {
                    ledger.completeMission(id: item.id, in: morning)
                }
            }
        } label: {
            HStack {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(
                        item.isCompleted ? DesignSystem.Colors.success : DesignSystem.Colors.textSecondary
                    )
                Text(item.title)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .strikethrough(item.isCompleted)
                if item.requiresProof {
                    Image(systemName: "camera.viewfinder")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
                Spacer()
            }
        }
        .disabled(isLocked || item.isCompleted)
    }
}
