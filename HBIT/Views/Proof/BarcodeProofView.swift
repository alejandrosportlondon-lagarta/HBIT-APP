import ProofKit
import SwiftUI

/// Barcode proof: scan the registered code to dismiss. Matching is local
/// and deterministic (`BarcodeMatcher`) — no network involved.
struct BarcodeProofView: View {
    let config: BarcodeProofConfig
    let onComplete: () -> Void

    @Environment(AlarmCoordinator.self) private var coordinator
    @State private var mismatch = false
    #if DEBUG
    @State private var manualEntry = ""
    #endif

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("Scan your registered code")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            BarcodeScannerView { payload, _ in
                verify(payload)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 360)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))

            if mismatch {
                Text("That's not the registered code.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.accent)
            }

            #if DEBUG
            HStack {
                TextField("Manual code (simulator)", text: $manualEntry)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Submit") { verify(manualEntry) }
                    .buttonStyle(.bordered)
            }
            #endif
        }
    }

    private func verify(_ payload: String) {
        if BarcodeMatcher.matches(scanned: payload, registered: config.payload) {
            onComplete()
        } else {
            coordinator.reportProofFailure()
            mismatch = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                mismatch = false
            }
        }
    }
}
