import Testing
@testable import MorningKit

@Suite("MorningResult")
struct MorningResultTests {
    @Test("raw values match the Supabase mornings.result check constraint")
    func rawValuesMatchSchema() {
        #expect(MorningResult.win.rawValue == "win")
        #expect(MorningResult.loss.rawValue == "loss")
        #expect(MorningResult.allCases.count == 2)
    }
}
