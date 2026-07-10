import PhotosUI
import ProofKit
import SwiftUI

/// Photo proof: re-take the registered shot. A ghost of the reference is
/// overlaid for framing — rendered through `SecureImageView` so it is
/// blanked in screenshots (anti-cheat), and screenshot attempts during the
/// proof are tracked.
struct PhotoProofView: View {
    let config: PhotoProofConfig
    let onComplete: () -> Void

    @Environment(AlarmCoordinator.self) private var coordinator
    @State private var statusMessage: String?
    @State private var verifying = false
    #if DEBUG
    @State private var pickerItem: PhotosPickerItem?
    #endif

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("Re-take your registered photo")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            ZStack {
                PhotoCaptureView { data in
                    verify(data)
                }
                if let reference = PhotoProofService.referenceImage(named: config.referenceFileName) {
                    SecureImageView(image: reference)
                        .opacity(0.35)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 380)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))

            if verifying {
                ProgressView("Comparing…")
                    .tint(DesignSystem.Colors.primary)
            } else if let statusMessage {
                Text(statusMessage)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .multilineTextAlignment(.center)
            }

            #if DEBUG
            PhotosPicker("Choose from library (simulator)", selection: $pickerItem)
                .font(DesignSystem.Typography.caption)
                .onChange(of: pickerItem) { _, item in
                    guard let item else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            verify(data)
                        }
                    }
                }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.userDidTakeScreenshotNotification
        )) { _ in
            Telemetry.track(.screenshotOnProof, properties: ["proof_type": "photoMatch"])
        }
    }

    private func verify(_ data: Data) {
        guard !verifying else { return }
        verifying = true
        statusMessage = nil
        let config = config
        Task.detached(priority: .userInitiated) {
            let outcome: Result<Double, any Error>
            do {
                outcome = .success(try PhotoProofService.distance(fromImageData: data, to: config))
            } catch {
                outcome = .failure(error)
            }
            await MainActor.run {
                handle(outcome)
            }
        }
    }

    private func handle(_ outcome: Result<Double, any Error>) {
        verifying = false
        switch outcome {
        case .success(let distance):
            if PhotoMatchRule.isMatch(distance: distance, threshold: PhotoProofService.effectiveThreshold(for: config)) {
                onComplete()
            } else {
                coordinator.reportProofFailure()
                statusMessage = "Not a match. Line up the ghost image and try again."
            }
        case .failure(let error):
            statusMessage = error.localizedDescription
        }
    }
}
