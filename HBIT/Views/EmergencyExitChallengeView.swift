import ProofKit
import SwiftUI

/// The escalating emergency exit: tap the moving target N times. Always
/// completable (we never trap users) but deliberately tedious, and the
/// morning is recorded as a LOSS.
struct EmergencyExitChallengeView: View {
    let requiredTaps: Int
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var session: EmergencyExitChallengeSession

    init(requiredTaps: Int, onComplete: @escaping () -> Void) {
        self.requiredTaps = requiredTaps
        self.onComplete = onComplete
        _session = State(initialValue: EmergencyExitChallengeSession(requiredTaps: requiredTaps))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()

                VStack {
                    Text("\(session.remainingTaps)")
                        .font(DesignSystem.Typography.display)
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .contentTransition(.numericText())
                    Text("taps on the target to exit — this morning becomes a LOSS")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                    Spacer()
                    Button("Never mind — back to the proof") { dismiss() }
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .padding(.bottom, DesignSystem.Spacing.lg)
                }
                .padding(.top, DesignSystem.Spacing.xl)

                Button {
                    registerHit()
                } label: {
                    Circle()
                        .fill(DesignSystem.Colors.accent)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Circle().strokeBorder(DesignSystem.Colors.textPrimary, lineWidth: 3)
                        )
                }
                .position(
                    x: geometry.size.width * session.targetPosition.x,
                    y: geometry.size.height * session.targetPosition.y
                )
                .animation(.snappy(duration: 0.15), value: session.targetPosition)
            }
        }
        .interactiveDismissDisabled()
    }

    private func registerHit() {
        session.registerHit()
        if session.isComplete {
            onComplete()
            dismiss()
        }
    }
}
