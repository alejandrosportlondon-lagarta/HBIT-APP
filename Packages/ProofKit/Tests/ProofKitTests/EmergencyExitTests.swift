import Foundation
import Testing
@testable import ProofKit

@Suite("EmergencyExitPolicy")
struct EmergencyExitPolicyTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("cost escalates by 100 per effective use from a 100 base")
    func costEscalation() {
        #expect(EmergencyExitPolicy.tapCost(effectiveUses: 0) == 100)
        #expect(EmergencyExitPolicy.tapCost(effectiveUses: 1) == 200)
        #expect(EmergencyExitPolicy.tapCost(effectiveUses: 4) == 500)
        #expect(EmergencyExitPolicy.tapCost(effectiveUses: -3) == 100)
    }

    @Test("uses reset 30 days after the last use")
    func thirtyDayReset() {
        let justUnder = now.addingTimeInterval(-EmergencyExitPolicy.resetInterval + 60)
        #expect(EmergencyExitPolicy.effectiveUses(storedUses: 3, lastUsedAt: justUnder, now: now) == 3)

        let justOver = now.addingTimeInterval(-EmergencyExitPolicy.resetInterval - 60)
        #expect(EmergencyExitPolicy.effectiveUses(storedUses: 3, lastUsedAt: justOver, now: now) == 0)

        #expect(EmergencyExitPolicy.effectiveUses(storedUses: 3, lastUsedAt: nil, now: now) == 0)
        #expect(EmergencyExitPolicy.effectiveUses(storedUses: -2, lastUsedAt: now, now: now) == 0)
    }
}

@Suite("EmergencyExitChallengeSession")
struct EmergencyExitChallengeSessionTests {
    @Test("completes after exactly the required number of hits")
    func completion() {
        var session = EmergencyExitChallengeSession(requiredTaps: 5, seed: 3)
        for remaining in stride(from: 5, to: 0, by: -1) {
            #expect(session.remainingTaps == remaining)
            #expect(!session.isComplete)
            session.registerHit()
        }
        #expect(session.isComplete)
        #expect(session.remainingTaps == 0)
        // Extra hits are ignored.
        session.registerHit()
        #expect(session.tapsCompleted == 5)
    }

    @Test("the target moves after every hit")
    func targetMoves() {
        var session = EmergencyExitChallengeSession(requiredTaps: 50, seed: 11)
        var previous = session.targetPosition
        for _ in 0..<49 {
            session.registerHit()
            #expect(session.targetPosition != previous)
            previous = session.targetPosition
        }
    }

    @Test("positions stay inside the reachable inset of the unit square")
    func positionsInBounds() {
        var session = EmergencyExitChallengeSession(requiredTaps: 100, seed: 7)
        for _ in 0..<99 {
            let position = session.targetPosition
            #expect((0.10...0.90).contains(position.x))
            #expect((0.15...0.85).contains(position.y))
            session.registerHit()
        }
    }

    @Test("at least one tap is always required")
    func minimumOneTap() {
        let session = EmergencyExitChallengeSession(requiredTaps: 0, seed: 1)
        #expect(session.requiredTaps == 1)
    }
}
