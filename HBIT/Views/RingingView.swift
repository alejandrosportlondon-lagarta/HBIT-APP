import SwiftUI

/// Full-screen dismiss flow: ringing → proof → dismissed/exited. Presented
/// as an undismissable cover; the only ways out are the state machine's
/// terminal transitions. The emergency exit is reachable from BOTH the
/// ringing screen and the proof screen (product guardrail).
struct RingingView: View {
    @Environment(AlarmCoordinator.self) private var coordinator
    @State private var confirmingEmergencyExit = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()
            switch coordinator.machine.state {
            case .proofInProgress:
                proofPlaceholder
            default:
                ringing
            }
            Spacer()
            emergencyExitButton
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
        .interactiveDismissDisabled()
        .confirmationDialog(
            "Use the emergency exit?",
            isPresented: $confirmingEmergencyExit,
            titleVisibility: .visible
        ) {
            Button("Exit — record a LOSS", role: .destructive) {
                coordinator.performEmergencyExit()
            }
            Button("Keep trying", role: .cancel) {}
        } message: {
            Text("This morning will be recorded as a LOSS. From Milestone 3 each use also gets more expensive.")
        }
    }

    private var ringing: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(context.date, format: .dateTime.hour().minute())
                    .font(DesignSystem.Typography.display)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            Text("Wake up. Prove it.")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            Button {
                coordinator.beginProof()
            } label: {
                Text("Start proof")
                    .font(DesignSystem.Typography.headline)
                    .frame(maxWidth: .infinity, minHeight: 64)
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.Colors.primary)
        }
    }

    private var proofPlaceholder: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("Proof")
                .font(DesignSystem.Typography.title)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Text("Real proofs (math, steps, barcode, photo) arrive in Milestone 2. For now, confirm you're up.")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                coordinator.completeProof()
            } label: {
                Text("I'm awake — dismiss alarm")
                    .font(DesignSystem.Typography.headline)
                    .frame(maxWidth: .infinity, minHeight: 64)
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.Colors.success)
            Button("Back to alarm") {
                coordinator.abandonProof()
            }
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }

    private var emergencyExitButton: some View {
        Button {
            confirmingEmergencyExit = true
        } label: {
            Text("Emergency exit")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.accent)
        }
    }
}
