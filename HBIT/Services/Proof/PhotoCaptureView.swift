import AVFoundation
import SwiftUI
import UIKit

/// Live camera with a shutter button. Delivers raw JPEG data — the caller
/// decides what to do with it (register a reference or verify a match).
struct PhotoCaptureView: UIViewControllerRepresentable {
    /// Called on the main actor with the captured photo data.
    let onCapture: @MainActor @Sendable (Data) -> Void

    func makeUIViewController(context: Context) -> PhotoCaptureViewController {
        let controller = PhotoCaptureViewController()
        controller.onCapture = onCapture
        return controller
    }

    func updateUIViewController(_ uiViewController: PhotoCaptureViewController, context: Context) {}
}

final class PhotoCaptureViewController: UIViewController {
    /// Read from the nonisolated capture callback; set once before display.
    nonisolated(unsafe) var onCapture: (@MainActor @Sendable (Data) -> Void)?

    private nonisolated(unsafe) let captureSession = AVCaptureSession()
    private nonisolated(unsafe) let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.hbit.photo-capture")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let statusLabel = UILabel()
    private let shutterButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        statusLabel.textColor = .white
        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.backgroundColor = .white
        shutterButton.layer.cornerRadius = 36
        shutterButton.layer.borderWidth = 4
        shutterButton.layer.borderColor = UIColor.lightGray.cgColor
        shutterButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        shutterButton.isEnabled = false
        view.addSubview(shutterButton)

        NSLayoutConstraint.activate([
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            shutterButton.widthAnchor.constraint(equalToConstant: 72),
            shutterButton.heightAnchor.constraint(equalToConstant: 72)
        ])

        Task { await configureCamera() }
    }

    private func configureCamera() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard granted else {
            statusLabel.text = "Camera access denied. Enable it in Settings → HBIT."
            return
        }
        guard let device = AVCaptureDevice.default(for: .video) else {
            statusLabel.text = "Camera unavailable on this device."
            return
        }

        let session = captureSession
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
                statusLabel.text = "Camera setup failed."
                return
            }
            session.addInput(input)
            session.addOutput(photoOutput)
        } catch {
            statusLabel.text = "Camera setup failed: \(error.localizedDescription)"
            return
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.insertSublayer(preview, at: 0)
        previewLayer = preview
        statusLabel.isHidden = true
        shutterButton.isEnabled = true

        sessionQueue.async { session.startRunning() }
    }

    @objc private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let session = captureSession
        sessionQueue.async { session.stopRunning() }
    }
}

extension PhotoCaptureViewController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: (any Error)?
    ) {
        // Extract Sendable data here — the callback arrives on an
        // unspecified queue and AVCapturePhoto must not cross actors.
        guard error == nil, let data = photo.fileDataRepresentation() else { return }
        let handler = onCapture
        Task { @MainActor in handler?(data) }
    }
}
