import Foundation
import ProofKit
import UIKit
import Vision

/// On-device photo similarity via Vision feature prints — never object
/// recognition (stack rule), never leaves the device. Blocking Vision work
/// runs off the main actor via these nonisolated statics.
enum PhotoProofService {
    enum PhotoProofError: LocalizedError {
        case notAnImage
        case noFeaturePrint

        var errorDescription: String? {
            switch self {
            case .notAnImage: "The captured data isn't a usable image."
            case .noFeaturePrint: "Could not analyze the image. Try again with more light."
            }
        }
    }

    private static let thresholdOverrideKey = "hbit.photo.thresholdOverride"

    // MARK: - Registration

    /// Computes the reference feature print, stores the image locally for
    /// the ghost overlay, and returns the proof payload.
    static func makeReference(fromImageData data: Data) throws -> PhotoProofConfig {
        guard let image = UIImage(data: data) else { throw PhotoProofError.notAnImage }
        let print = try featurePrint(for: image)
        let printData = try NSKeyedArchiver.archivedData(withRootObject: print, requiringSecureCoding: true)
        let fileName = "\(UUID().uuidString).jpg"
        try saveReferenceImage(image, fileName: fileName)
        return PhotoProofConfig(featurePrint: printData, referenceFileName: fileName)
    }

    // MARK: - Verification

    /// Vision feature-print distance between the candidate image and the
    /// registered reference (smaller = more similar).
    static func distance(fromImageData data: Data, to config: PhotoProofConfig) throws -> Double {
        guard let image = UIImage(data: data) else { throw PhotoProofError.notAnImage }
        guard let reference = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: VNFeaturePrintObservation.self, from: config.featurePrint
        ) else { throw PhotoProofError.noFeaturePrint }
        let candidate = try featurePrint(for: image)
        var result: Float = 0
        try candidate.computeDistance(&result, to: reference)
        return Double(result)
    }

    /// The debug-slider override (Reliability Harness) beats the persisted
    /// per-reference threshold; the final default is set in beta.
    static func effectiveThreshold(for config: PhotoProofConfig) -> Double {
        if let override = UserDefaults.standard.object(forKey: thresholdOverrideKey) as? Double {
            return PhotoMatchRule.clampedThreshold(override)
        }
        return config.threshold
    }

    static func setThresholdOverride(_ value: Double?) {
        if let value {
            UserDefaults.standard.set(value, forKey: thresholdOverrideKey)
        } else {
            UserDefaults.standard.removeObject(forKey: thresholdOverrideKey)
        }
    }

    static var thresholdOverride: Double? {
        UserDefaults.standard.object(forKey: thresholdOverrideKey) as? Double
    }

    // MARK: - Reference image storage (local only, for the ghost overlay)

    static func referenceImage(named fileName: String) -> UIImage? {
        guard let url = try? referenceDirectory().appendingPathComponent(fileName),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return UIImage(data: data)
    }

    private static func saveReferenceImage(_ image: UIImage, fileName: String) throws {
        let directory = try referenceDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else { throw PhotoProofError.notAnImage }
        try jpeg.write(to: directory.appendingPathComponent(fileName), options: .atomic)
    }

    private static func referenceDirectory() throws -> URL {
        try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ).appendingPathComponent("ProofReferences", isDirectory: true)
    }

    // MARK: - Vision

    private static func featurePrint(for image: UIImage) throws -> VNFeaturePrintObservation {
        guard let cgImage = image.cgImage else { throw PhotoProofError.notAnImage }
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: CGImagePropertyOrientation(image.imageOrientation),
            options: [:]
        )
        try handler.perform([request])
        guard let observation = request.results?.first else { throw PhotoProofError.noFeaturePrint }
        return observation
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
