import SwiftUI

/// Full-screen dismiss flow: ringing → proof → dismissed/exited. Presented
/// as an undismissable cover; the only ways out are the state machine's
/// terminal transitions. The emergency exit is reachable from BOTH the
/// ringing screen and the proof screen (product guardrail).
struct RingingView: View {
    @Environment(AlarmCoordinator.self) private var coordinator
    @Environment(EmergencyExitCounter.self) private var exitCounter
    @Environment(AuthService.self) private var auth
    @State private var confirmingEmergencyExit = false
    @State private var showingChallenge = false

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
            Button("Start the \(exitCounter.currentTapCost())-tap challenge", role: .destructive) {
                showingChallenge = true
            }
            Button("Keep trying", role: .cancel) {}
        } message: {
            Text(
                "The exit costs \(exitCounter.currentTapCost()) taps on a moving target, records this "
                    + "morning as a LOSS, and gets 100 taps more expensive each use (resets after 30 days)."
            )
        }
        .sheet(isPresented: $showingChallenge) {
            EmergencyExitChallengeView(requiredTaps: exitCounter.currentTapCost()) {
                completeEmergencyExit()
            }
        }
    }

    private func completeEmergencyExit() {
        let cost = exitCounter.currentTapCost()
        exitCounter.recordUse()
        let uses = exitCounter.uses
        let lastUsedAt = exitCounter.lastUsedAt
        Task { await auth.pushEmergencyExitProfile(uses: uses, lastUsedAt: lastUsedAt) }
        coordinator.performEmergencyExit(tapCost: cost, effectiveUses: exitCounter.effectiveUses())
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
            ProofContainerView()
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
