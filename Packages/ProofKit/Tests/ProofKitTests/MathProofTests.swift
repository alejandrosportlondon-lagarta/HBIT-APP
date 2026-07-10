import Foundation
import Testing
@testable import ProofKit

@Suite("MathProof")
struct MathProofTests {
    @Test("generation is deterministic for a given seed")
    func deterministicGeneration() {
        var rngA = SplitMix64(seed: 42)
        var rngB = SplitMix64(seed: 42)
        for _ in 0..<20 {
            let problemA = MathProblem.generate(difficulty: .hard, using: &rngA)
            let problemB = MathProblem.generate(difficulty: .hard, using: &rngB)
            #expect(problemA == problemB)
        }
    }

    @Test("every difficulty produces a self-consistent question/answer pair",
          arguments: MathDifficulty.allCases)
    func answersMatchQuestions(difficulty: MathDifficulty) {
        var rng = SplitMix64(seed: 7)
        for _ in 0..<50 {
            let problem = MathProblem.generate(difficulty: difficulty, using: &rng)
            // Re-evaluate the rendered question and compare to the stored answer.
            let sanitized = problem.question
                .replacingOccurrences(of: "×", with: "*")
                .replacingOccurrences(of: "−", with: "-")
            let expression = NSExpression(format: sanitized)
            let evaluated = expression.expressionValue(with: nil, context: nil) as? Int
            #expect(evaluated == problem.answer, "\(problem.question) should equal \(problem.answer)")
        }
    }

    @Test("easy answers stay small enough for a half-asleep brain")
    func easyBounds() {
        var rng = SplitMix64(seed: 99)
        for _ in 0..<100 {
            let problem = MathProblem.generate(difficulty: .easy, using: &rng)
            #expect((20...198).contains(problem.answer))
            #expect(problem.question.contains("+"))
        }
    }

    @Test("session requires exactly problemCount correct answers")
    func sessionCompletion() {
        var session = MathProofSession(config: MathProofConfig(difficulty: .easy, problemCount: 3), seed: 1)
        #expect(!session.isComplete)
        for solved in 1...3 {
            let accepted = session.submit(session.currentProblem.answer)
            #expect(accepted)
            #expect(session.solvedCount == solved)
        }
        #expect(session.isComplete)
        // Complete sessions reject further submissions.
        let acceptedAfterComplete = session.submit(0)
        #expect(!acceptedAfterComplete)
    }

    @Test("a wrong answer neither advances nor resets progress")
    func wrongAnswerKeepsProgress() {
        var session = MathProofSession(config: MathProofConfig(difficulty: .medium, problemCount: 2), seed: 5)
        let firstAccepted = session.submit(session.currentProblem.answer)
        #expect(firstAccepted)
        let problemBefore = session.currentProblem
        let wrongAccepted = session.submit(session.currentProblem.answer + 1)
        #expect(!wrongAccepted)
        #expect(session.solvedCount == 1)
        #expect(session.currentProblem == problemBefore)
        #expect(session.failedAttempts == 1)
        // Still solvable after a failure.
        let retryAccepted = session.submit(session.currentProblem.answer)
        #expect(retryAccepted)
        #expect(session.isComplete)
    }

    @Test("problem count is clamped to 1–10")
    func problemCountClamped() {
        #expect(MathProofConfig(difficulty: .easy, problemCount: 0).problemCount == 1)
        #expect(MathProofConfig(difficulty: .easy, problemCount: 99).problemCount == 10)
    }

    @Test("config round-trips through its payload encoding")
    func payloadRoundTrip() throws {
        let config = MathProofConfig(difficulty: .hard, problemCount: 5)
        let decoded = try MathProofConfig.from(payload: config.payloadData())
        #expect(decoded == config)
    }
}
