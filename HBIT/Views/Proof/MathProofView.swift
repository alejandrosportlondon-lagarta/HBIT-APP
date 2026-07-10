import ProofKit
import SwiftUI

/// Math proof: solve N problems on a keypad built for half-asleep thumbs —
/// huge targets, no system keyboard, no autocorrect surprises.
struct MathProofView: View {
    let config: MathProofConfig
    let onComplete: () -> Void

    @Environment(AlarmCoordinator.self) private var coordinator
    @State private var session: MathProofSession
    @State private var entry = ""
    @State private var flashWrong = false

    init(config: MathProofConfig, onComplete: @escaping () -> Void) {
        self.config = config
        self.onComplete = onComplete
        _session = State(initialValue: MathProofSession(config: config))
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("Problem \(min(session.solvedCount + 1, config.problemCount)) of \(config.problemCount)")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Text(session.currentProblem.question)
                .font(DesignSystem.Typography.title)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text(entry.isEmpty ? "?" : entry)
                .font(DesignSystem.Typography.numeric)
                .foregroundStyle(flashWrong ? DesignSystem.Colors.accent : DesignSystem.Colors.primary)
                .frame(minHeight: 44)

            keypad
        }
    }

    private var keypad: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.sm), count: 3),
                  spacing: DesignSystem.Spacing.sm) {
            ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "✓"], id: \.self) { key in
                Button {
                    handle(key)
                } label: {
                    Text(key)
                        .font(DesignSystem.Typography.headline)
                        .frame(maxWidth: .infinity, minHeight: 64)
                }
                .buttonStyle(.bordered)
                .tint(key == "✓" ? DesignSystem.Colors.success : DesignSystem.Colors.primary)
            }
        }
    }

    private func handle(_ key: String) {
        switch key {
        case "⌫":
            if !entry.isEmpty { entry.removeLast() }
        case "✓":
            submit()
        default:
            if entry.count < 6 { entry.append(key) }
        }
    }

    private func submit() {
        guard let value = Int(entry) else { return }
        if session.submit(value) {
            entry = ""
            if session.isComplete { onComplete() }
        } else {
            coordinator.reportProofFailure()
            entry = ""
            flashWrong = true
            Task {
                try? await Task.sleep(for: .seconds(0.5))
                flashWrong = false
            }
        }
    }
}
