import Foundation

public struct BarcodeProofConfig: ProofConfig {
    public static let kind = ProofType.barcode

    /// The registered code's payload, stored raw and only on-device /
    /// in the user's own row — matching must work fully offline.
    public let payload: String
    /// Symbology as reported at registration (e.g. "org.iso.QRCode"),
    /// informational only — matching is payload-based because scanners
    /// report UPC-A/EAN-13 inconsistently.
    public let symbology: String?

    public init(payload: String, symbology: String? = nil) {
        self.payload = payload
        self.symbology = symbology
    }
}

/// Payload matching for the dismissal scan. Deterministic and strict:
/// the same physical code must always match (no false negatives), and a
/// different code must never match.
public enum BarcodeMatcher {
    public static func normalize(_ payload: String) -> String {
        payload.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func matches(scanned: String, registered: String) -> Bool {
        let scannedNorm = normalize(scanned)
        let registeredNorm = normalize(registered)
        // An empty registration can never be satisfied — the registration
        // flow must prevent it, and the matcher refuses it defensively.
        guard !registeredNorm.isEmpty, !scannedNorm.isEmpty else { return false }
        if scannedNorm == registeredNorm { return true }
        // The classic edge case: the same physical UPC-A code is reported
        // as 12 digits by some scanners and as 13-digit EAN-13 with a
        // leading zero by others. Treat them as the same code, in both
        // directions.
        return upcaEan13Equivalent(twelve: scannedNorm, thirteen: registeredNorm)
            || upcaEan13Equivalent(twelve: registeredNorm, thirteen: scannedNorm)
    }

    private static func upcaEan13Equivalent(twelve: String, thirteen: String) -> Bool {
        twelve.count == 12
            && thirteen.count == 13
            && thirteen.first == "0"
            && twelve.allSatisfy(\.isNumber)
            && thirteen.dropFirst() == twelve[...]
    }
}
