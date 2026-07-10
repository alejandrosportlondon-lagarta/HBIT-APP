import PhotosUI
import ProofKit
import SwiftUI

/// Registration: photograph a fixed spot (bathroom sink, coffee machine).
/// Only the Vision feature print goes into the proof payload; the photo
/// itself stays in local storage for the ghost overlay.
struct PhotoRegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    let onRegistered: (PhotoProofConfig) -> Void

    @State private var errorMessage: String?
    #if DEBUG
    @State private var pickerItem: PhotosPickerItem?
    #endif

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.md) {
                Text(
                    "Photograph a fixed spot away from your bed. Every morning you'll re-take "
                        + "this exact shot to dismiss the alarm — the walk is the point."
                )
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                PhotoCaptureView { data in
                    register(data)
                }
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
                .padding(.horizontal, DesignSystem.Spacing.lg)

                if let errorMessage {
                    Text(errorMessage)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.accent)
                }

                #if DEBUG
                PhotosPicker("Choose from library (simulator)", selection: $pickerItem)
                    .font(DesignSystem.Typography.caption)
                    .onChange(of: pickerItem) { _, item in
                        guard let item else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                register(data)
                            }
                        }
                    }
                #endif
            }
            .padding(.vertical, DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.background)
            .navigationTitle("Register photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func register(_ data: Data) {
        do {
            let config = try PhotoProofService.makeReference(fromImageData: data)
            onRegistered(config)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
