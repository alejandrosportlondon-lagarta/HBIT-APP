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
    let photoSummary: String?
    let onRegisterBarcode: () -> Void
    let onRegisterPhoto: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Picker("Proof", selection: $proofType) {
                Text("Math").tag(ProofType.math)
                Text("Steps").tag(ProofType.steps)
                Text("Barcode ⭐").tag(ProofType.barcode)
                Text("Photo ⭐").tag(ProofType.photoMatch)
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
                registrationRow(
                    summary: barcodeSummary,
                    emptyText: "No code registered yet",
                    action: onRegisterBarcode
                )
            case .photoMatch:
                registrationRow(
                    summary: photoSummary,
                    emptyText: "No reference photo yet",
                    action: onRegisterPhoto
                )
            }
        }
    }

    private func registrationRow(
        summary: String?,
        emptyText: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(summary ?? emptyText)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(
                    summary == nil
                        ? DesignSystem.Colors.accent
                        : DesignSystem.Colors.textSecondary
                )
            Spacer()
            Button("Register…", action: action)
                .buttonStyle(.bordered)
                .tint(DesignSystem.Colors.primary)
        }
    }
}
