import Foundation
import Testing
@testable import AlarmEngine

@Suite("ClockRollbackDetector")
struct ClockRollbackDetectorTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("no history means no rollback")
    func noHistory() {
        #expect(!ClockRollbackDetector.isRollback(now: now, lastObserved: nil))
    }

    @Test("time moving forward is never a rollback")
    func forwardTime() {
        #expect(!ClockRollbackDetector.isRollback(now: now, lastObserved: now.addingTimeInterval(-3600)))
    }

    @Test("small backwards drift within tolerance is not flagged (NTP adjustments)")
    func toleranceAbsorbsDrift() {
        #expect(!ClockRollbackDetector.isRollback(now: now.addingTimeInterval(-60), lastObserved: now))
        #expect(!ClockRollbackDetector.isRollback(now: now.addingTimeInterval(-120), lastObserved: now))
    }

    @Test("a deliberate rollback beyond tolerance is flagged")
    func rollbackFlagged() {
        #expect(ClockRollbackDetector.isRollback(now: now.addingTimeInterval(-121), lastObserved: now))
        #expect(ClockRollbackDetector.isRollback(now: now.addingTimeInterval(-86_400), lastObserved: now))
    }

    @Test("the persisted maximum only moves forward")
    func observedMaximumMonotonic() {
        #expect(ClockRollbackDetector.nextObservedMaximum(now: now, lastObserved: nil) == now)
        let past = now.addingTimeInterval(-1000)
        #expect(ClockRollbackDetector.nextObservedMaximum(now: past, lastObserved: now) == now)
        let future = now.addingTimeInterval(1000)
        #expect(ClockRollbackDetector.nextObservedMaximum(now: future, lastObserved: now) == future)
    }
}
