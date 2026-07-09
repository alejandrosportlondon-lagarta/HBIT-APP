import Testing
@testable import ProofKit

@Suite("ProofType")
struct ProofTypeTests {
    @Test("free tier gets exactly math and steps")
    func freeTierProofs() {
        let free = ProofType.allCases.filter { !$0.requiresPro }
        #expect(Set(free) == [.math, .steps])
    }

    @Test("raw values are stable — they are persisted and synced")
    func rawValuesAreStable() {
        #expect(ProofType.math.rawValue == "math")
        #expect(ProofType.steps.rawValue == "steps")
        #expect(ProofType.barcode.rawValue == "barcode")
        #expect(ProofType.photoMatch.rawValue == "photoMatch")
    }
}
