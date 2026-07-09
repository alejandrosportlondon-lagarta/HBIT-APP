import Testing
@testable import SyncKit

@Suite("SyncStatus")
struct SyncStatusTests {
    @Test("raw values are stable — they are persisted with every record")
    func rawValuesAreStable() {
        #expect(SyncStatus.pending.rawValue == "pending")
        #expect(SyncStatus.synced.rawValue == "synced")
        #expect(SyncStatus.conflict.rawValue == "conflict")
    }
}
