import SwiftUI

/// Resolves the active alarm's configured proof and shows the matching
/// proof UI. Test alarms and unconfigured states get the placeholder
/// confirm button so the alarm always remains dismissable.
struct ProofContainerView: View {
    @Environment(AlarmCoordinator.self) private var coordinator
    @State private var proof: ActiveProof?

    var body: some View {
        Group {
            switch proof {
            case .math(let config):
                MathProofView(config: config) { coordinator.completeProof() }
            case .steps(let config):
                StepsProofView(config: config) { coordinator.completeProof() }
            case .barcode(let config):
                BarcodeProofView(config: config) { coordinator.completeProof() }
            case .photo(let config):
                PhotoProofView(config: config) { coordinator.completeProof() }
            case .placeholder, nil:
                placeholder
            }
        }
        .onAppear {
            if proof == nil { proof = coordinator.resolveActiveProof() }
        }
    }

    private var placeholder: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("No proof configured for this alarm (test alarm).")
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
        }
    }
}
