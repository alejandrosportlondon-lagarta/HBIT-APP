import Testing
@testable import ProofKit

@Suite("BarcodeMatcher")
struct BarcodeMatcherTests {
    @Test("exact payloads match")
    func exactMatch() {
        #expect(BarcodeMatcher.matches(scanned: "https://example.com/x", registered: "https://example.com/x"))
        #expect(BarcodeMatcher.matches(scanned: "5000112637922", registered: "5000112637922"))
    }

    @Test("different payloads never match")
    func differentPayloads() {
        #expect(!BarcodeMatcher.matches(scanned: "5000112637922", registered: "5000112637939"))
        #expect(!BarcodeMatcher.matches(scanned: "https://a.example", registered: "https://b.example"))
    }

    @Test("surrounding whitespace is ignored")
    func whitespaceNormalized() {
        #expect(BarcodeMatcher.matches(scanned: "  ABC-123 \n", registered: "ABC-123"))
    }

    @Test("QR payloads are case-sensitive")
    func caseSensitive() {
        #expect(!BarcodeMatcher.matches(scanned: "Token-ABC", registered: "token-abc"))
    }

    @Test("UPC-A and zero-prefixed EAN-13 are the same physical code, both directions")
    func upcaEan13Equivalence() {
        // Same code reported as 12-digit UPC-A by one scan and 13-digit
        // EAN-13 (leading 0) by another.
        #expect(BarcodeMatcher.matches(scanned: "036000291452", registered: "0036000291452"))
        #expect(BarcodeMatcher.matches(scanned: "0036000291452", registered: "036000291452"))
    }

    @Test("the leading digit must be zero for UPC-A/EAN-13 equivalence")
    func nonZeroPrefixNotEquivalent() {
        #expect(!BarcodeMatcher.matches(scanned: "036000291452", registered: "5036000291452"))
    }

    @Test("12/13-length equivalence only applies to all-numeric payloads")
    func nonNumericNotEquivalent() {
        #expect(!BarcodeMatcher.matches(scanned: "ABCDEFGHIJKL", registered: "0ABCDEFGHIJKL"))
    }

    @Test("empty payloads never match anything, including each other")
    func emptyNeverMatches() {
        #expect(!BarcodeMatcher.matches(scanned: "", registered: "5000112637922"))
        #expect(!BarcodeMatcher.matches(scanned: "5000112637922", registered: ""))
        #expect(!BarcodeMatcher.matches(scanned: "", registered: ""))
        #expect(!BarcodeMatcher.matches(scanned: "   ", registered: "   "))
    }

    @Test("config round-trips through its payload encoding")
    func payloadRoundTrip() throws {
        let config = BarcodeProofConfig(payload: "5000112637922", symbology: "org.gs1.EAN-13")
        let decoded = try BarcodeProofConfig.from(payload: config.payloadData())
        #expect(decoded == config)
    }
}
