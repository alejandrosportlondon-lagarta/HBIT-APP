import MorningKit
import SwiftUI

/// Last-30-days strip: one square per day (WIN green, LOSS orange, empty
/// dim), oldest on the left.
struct HistoryStripView: View {
    let entries: [DayEntry]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(entries) { entry in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color(for: entry.outcome))
                    .frame(height: 18)
            }
        }
    }

    private func color(for outcome: DayEntry.Outcome) -> Color {
        switch outcome {
        case .win: DesignSystem.Colors.success
        case .loss: DesignSystem.Colors.accent
        case .none: DesignSystem.Colors.surface
        }
    }
}
