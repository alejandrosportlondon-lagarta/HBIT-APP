import AVFoundation
import SwiftUI
import UIKit

/// Live camera barcode/QR scanner. Fully offline — frames never leave the
/// device; only the decoded payload string is handed to `onCode`.
struct BarcodeScannerView: UIViewControllerRepresentable {
    /// (payload, symbology raw value). Called on the main actor, debounced
    /// so a code held in frame doesn't fire repeatedly.
    let onCode: (String, String) -> Void

    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let controller = BarcodeScannerViewController()
        controller.onCode = onCode
        return controller
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {}
}

final class BarcodeScannerViewController: UIViewController {
    var onCode: ((String, String) -> Void)?

    // AVCaptureSession is used from the session queue for start/stop;
    // configuration happens before it runs.
    private nonisolated(unsafe) let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.hbit.barcode-scanner")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let statusLabel = UILabel()
    private var lastPayload: String?
    private var lastEmission = Date.distantPast

    private static let symbologies: [AVMetadataObject.ObjectType] = [
        .qr, .ean13, .ean8, .upce, .code128, .code39, .code93,
        .pdf417, .aztec, .dataMatrix, .interleaved2of5, .itf14
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        statusLabel.textColor = .white
        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])

        Task { await configureCamera() }
    }

    private func configureCamera() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard granted else {
            statusLabel.text = "Camera access denied. Enable it in Settings → HBIT to scan codes."
            return
        }
        guard let device = AVCaptureDevice.default(for: .video) else {
            statusLabel.text = "Camera unavailable on this device."
            return
        }

        let session = captureSession
        let output = AVCaptureMetadataOutput()
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input), session.canAddOutput(output) else {
                statusLabel.text = "Camera setup failed."
                return
            }
            session.addInput(input)
            session.addOutput(output)
        } catch {
            statusLabel.text = "Camera setup failed: \(error.localizedDescription)"
            return
        }

        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = Self.symbologies.filter(output.availableMetadataObjectTypes.contains)

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.insertSublayer(preview, at: 0)
        previewLayer = preview
        statusLabel.isHidden = true

        sessionQueue.async { session.startRunning() }
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

extension BarcodeScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        // Extract Sendable values before crossing into the main actor —
        // AVMetadataObject itself must not leave this isolation region.
        guard
            let object = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first,
            let payload = object.stringValue
        else { return }
        let symbology = object.type.rawValue
        // The delegate queue is .main (set in configureCamera).
        MainActor.assumeIsolated {
            emit(payload: payload, symbology: symbology)
        }
    }

    private func emit(payload: String, symbology: String) {
        let now = Date()
        if payload == lastPayload, now.timeIntervalSince(lastEmission) < 2 { return }
        lastPayload = payload
        lastEmission = now
        onCode?(payload, symbology)
    }
}
