import SwiftUI

/// Registration flow: scan any code (toothpaste tube, bathroom QR print,
/// cereal box) and it becomes the alarm's dismissal target.
struct BarcodeRegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    /// (payload, symbology raw value)
    let onRegistered: (String, String) -> Void

    #if DEBUG
    @State private var manualEntry = ""
    #endif

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.md) {
                Text("Scan the code you'll have to find every morning. Put it away from your bed — the walk is the point.")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                BarcodeScannerView { payload, symbology in
                    onRegistered(payload, symbology)
                    dismiss()
                }
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
                .padding(.horizontal, DesignSystem.Spacing.lg)

                #if DEBUG
                HStack {
                    TextField("Manual code (simulator)", text: $manualEntry)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Button("Register") {
                        guard !manualEntry.isEmpty else { return }
                        onRegistered(manualEntry, "manual")
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                #endif
            }
            .padding(.vertical, DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.background)
            .navigationTitle("Register barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
