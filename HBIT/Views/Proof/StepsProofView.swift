import ProofKit
import SwiftUI

/// Steps proof: walk the configured number of steps with a live count.
struct StepsProofView: View {
    let config: StepsProofConfig
    let onComplete: () -> Void

    @State private var session: StepsProofSession
    @State private var counter = StepCounter()

    init(config: StepsProofConfig, onComplete: @escaping () -> Void) {
        self.config = config
        self.onComplete = onComplete
        _session = State(initialValue: StepsProofSession(config: config))
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("\(session.remainingSteps)")
                .font(DesignSystem.Typography.display)
                .foregroundStyle(DesignSystem.Colors.primary)
                .contentTransition(.numericText())

            Text("steps to go — get moving")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            ProgressView(value: Double(session.stepsTaken), total: Double(config.targetSteps))
                .tint(DesignSystem.Colors.primary)

            if let message = counter.statusMessage {
                Text(message)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .multilineTextAlignment(.center)
            }

            #if DEBUG
            Button("+10 steps (debug)") {
                counter.debugAdd(10)
            }
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            #endif
        }
        .onAppear { counter.start() }
        .onDisappear { counter.stop() }
        .onChange(of: counter.cumulativeSteps) { _, newValue in
            session.update(cumulativeSteps: newValue)
            if session.isComplete {
                counter.stop()
                onComplete()
            }
        }
    }
}
