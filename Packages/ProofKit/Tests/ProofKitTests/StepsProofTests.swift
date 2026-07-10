import Testing
@testable import ProofKit

@Suite("StepsProof")
struct StepsProofTests {
    @Test("target is clamped to 10–100")
    func targetClamped() {
        #expect(StepsProofConfig(targetSteps: 1).targetSteps == 10)
        #expect(StepsProofConfig(targetSteps: 50).targetSteps == 50)
        #expect(StepsProofConfig(targetSteps: 5000).targetSteps == 100)
    }

    @Test("the first reading is the baseline — pre-existing steps don't count")
    func baselineExcluded() {
        var session = StepsProofSession(config: StepsProofConfig(targetSteps: 20))
        session.update(cumulativeSteps: 500)
        #expect(session.stepsTaken == 0)
        session.update(cumulativeSteps: 510)
        #expect(session.stepsTaken == 10)
        #expect(session.remainingSteps == 10)
        #expect(!session.isComplete)
        session.update(cumulativeSteps: 520)
        #expect(session.isComplete)
    }

    @Test("progress is monotonic — a lower reading never removes steps")
    func monotonicProgress() {
        var session = StepsProofSession(config: StepsProofConfig(targetSteps: 20))
        session.update(cumulativeSteps: 0)
        session.update(cumulativeSteps: 15)
        session.update(cumulativeSteps: 3)
        #expect(session.stepsTaken == 15)
    }

    @Test("negative readings are treated as zero")
    func negativeReadings() {
        var session = StepsProofSession(config: StepsProofConfig(targetSteps: 20))
        session.update(cumulativeSteps: -10)
        session.update(cumulativeSteps: 12)
        #expect(session.stepsTaken == 12)
    }

    @Test("completion at exactly the target")
    func exactCompletion() {
        var session = StepsProofSession(config: StepsProofConfig(targetSteps: 10))
        session.update(cumulativeSteps: 0)
        session.update(cumulativeSteps: 9)
        #expect(!session.isComplete)
        session.update(cumulativeSteps: 10)
        #expect(session.isComplete)
        #expect(session.remainingSteps == 0)
    }

    @Test("config round-trips through its payload encoding")
    func payloadRoundTrip() throws {
        let config = StepsProofConfig(targetSteps: 40)
        let decoded = try StepsProofConfig.from(payload: config.payloadData())
        #expect(decoded == config)
    }
}
