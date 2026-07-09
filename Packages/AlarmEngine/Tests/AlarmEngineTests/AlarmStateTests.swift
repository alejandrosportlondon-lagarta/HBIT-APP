import Testing
@testable import AlarmEngine

@Suite("AlarmState")
struct AlarmStateTests {
    @Test("raw values are stable — they are persisted to SwiftData and Supabase")
    func rawValuesAreStable() {
        #expect(AlarmState.scheduled.rawValue == "scheduled")
        #expect(AlarmState.ringing.rawValue == "ringing")
        #expect(AlarmState.proofInProgress.rawValue == "proofInProgress")
        #expect(AlarmState.dismissed.rawValue == "dismissed")
        #expect(AlarmState.emergencyExited.rawValue == "emergencyExited")
        #expect(AlarmState.expired.rawValue == "expired")
    }

    @Test("only dismissed, emergencyExited and expired are terminal")
    func terminalStates() {
        let terminal = AlarmState.allCases.filter(\.isTerminal)
        #expect(Set(terminal) == [.dismissed, .emergencyExited, .expired])
    }
}
