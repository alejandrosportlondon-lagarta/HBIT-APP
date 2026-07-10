import Foundation
import Testing
@testable import MorningKit

@Suite("GoalLock")
struct GoalLockTests {
    private let fireDate = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("open before the T-4h window")
    func openBeforeWindow() {
        let now = fireDate.addingTimeInterval(-GoalLock.leadTime - 1)
        #expect(GoalLock.phase(now: now, nextFireDate: fireDate, morningCloseAt: nil) == .open)
    }

    @Test("locked from exactly T-4h until the alarm fires")
    func lockedInLeadWindow() {
        let atBoundary = fireDate.addingTimeInterval(-GoalLock.leadTime)
        #expect(GoalLock.phase(now: atBoundary, nextFireDate: fireDate, morningCloseAt: nil)
            == .lockedUntilFire(fireDate))
        let justBeforeFire = fireDate.addingTimeInterval(-1)
        #expect(GoalLock.phase(now: justBeforeFire, nextFireDate: fireDate, morningCloseAt: nil)
            == .lockedUntilFire(fireDate))
    }

    @Test("an open morning locks until its close, and takes precedence")
    func lockedUntilClose() {
        let closeAt = fireDate.addingTimeInterval(3 * 3600)
        let during = fireDate.addingTimeInterval(600)
        #expect(GoalLock.phase(now: during, nextFireDate: nil, morningCloseAt: closeAt)
            == .lockedUntilClose(closeAt))
        // Even if tomorrow's occurrence is already inside its own lead
        // window, the open morning is the reported reason.
        let tomorrow = fireDate.addingTimeInterval(86_400)
        #expect(GoalLock.phase(now: tomorrow.addingTimeInterval(-3600), nextFireDate: tomorrow,
                               morningCloseAt: tomorrow.addingTimeInterval(-3000))
            == .lockedUntilClose(tomorrow.addingTimeInterval(-3000)))
    }

    @Test("open again after the morning closes")
    func openAfterClose() {
        let closeAt = fireDate.addingTimeInterval(3 * 3600)
        let after = closeAt.addingTimeInterval(1)
        #expect(GoalLock.phase(now: after, nextFireDate: nil, morningCloseAt: closeAt) == .open)
    }

    @Test("no alarm and no open morning means open")
    func openWithNothingPending() {
        #expect(GoalLock.phase(now: fireDate, nextFireDate: nil, morningCloseAt: nil) == .open)
    }
}
