import ProofKit
import SwiftUI

/// Proof selection + per-type configuration inside the alarm card.
/// Free tier is math + steps; barcode is a Pro feature (labelled here, the
/// paywall enforcement itself lands in Milestone 5).
struct ProofSettingsSection: View {
    @Binding var proofType: ProofType
    @Binding var mathDifficulty: MathDifficulty
    @Binding var stepsTarget: Int
    let barcodeSummary: String?
    let onRegisterBarcode: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Picker("Proof", selection: $proofType) {
                Text("Math").tag(ProofType.math)
                Text("Steps").tag(ProofType.steps)
                Text("Barcode ⭐").tag(ProofType.barcode)
            }
            .pickerStyle(.segmented)

            switch proofType {
            case .math:
                Picker("Difficulty", selection: $mathDifficulty) {
                    ForEach(MathDifficulty.allCases, id: \.self) { difficulty in
                        Text(difficulty.rawValue.capitalized).tag(difficulty)
                    }
                }
                .pickerStyle(.segmented)
            case .steps:
                Stepper(value: $stepsTarget, in: 10...100, step: 10) {
                    Text("Walk \(stepsTarget) steps")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }
            case .barcode:
                HStack {
                    Text(barcodeSummary ?? "No code registered yet")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(
                            barcodeSummary == nil
                                ? DesignSystem.Colors.accent
                                : DesignSystem.Colors.textSecondary
                        )
                    Spacer()
                    Button("Register…", action: onRegisterBarcode)
                        .buttonStyle(.bordered)
                        .tint(DesignSystem.Colors.primary)
                }
            case .photoMatch:
                Text("Photo proof arrives in Milestone 3.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
    }
}
