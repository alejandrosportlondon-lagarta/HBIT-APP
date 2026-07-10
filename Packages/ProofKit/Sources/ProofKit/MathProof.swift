import Foundation

public enum MathDifficulty: String, Codable, Sendable, CaseIterable {
    case easy
    case medium
    case hard
}

/// One generated problem. Questions use only +, × and − with operand ranges
/// tuned to be solvable half-asleep at `easy` and genuinely wake-you-up at
/// `hard` — but always with a single integer answer (deterministic
/// verification, no ambiguity).
public struct MathProblem: Equatable, Sendable {
    public let question: String
    public let answer: Int

    public static func generate(
        difficulty: MathDifficulty,
        using rng: inout some RandomNumberGenerator
    ) -> MathProblem {
        switch difficulty {
        case .easy:
            let lhs = Int.random(in: 10...99, using: &rng)
            let rhs = Int.random(in: 10...99, using: &rng)
            return MathProblem(question: "\(lhs) + \(rhs)", answer: lhs + rhs)
        case .medium:
            let factor = Int.random(in: 3...9, using: &rng)
            let base = Int.random(in: 12...29, using: &rng)
            let addend = Int.random(in: 10...99, using: &rng)
            return MathProblem(question: "\(factor) × \(base) + \(addend)", answer: factor * base + addend)
        case .hard:
            let lhs = Int.random(in: 11...19, using: &rng)
            let rhs = Int.random(in: 11...19, using: &rng)
            let subtrahend = Int.random(in: 21...99, using: &rng)
            return MathProblem(question: "\(lhs) × \(rhs) − \(subtrahend)", answer: lhs * rhs - subtrahend)
        }
    }
}

public struct MathProofConfig: ProofConfig {
    public static let kind = ProofType.math

    public let difficulty: MathDifficulty
    /// Problems that must be solved to pass, clamped to 1–10.
    public let problemCount: Int

    public init(difficulty: MathDifficulty, problemCount: Int = 3) {
        self.difficulty = difficulty
        self.problemCount = min(10, max(1, problemCount))
    }
}

/// The math proof's interactive state machine: solve `problemCount`
/// problems. A wrong answer never advances or resets progress — the user
/// retries the same problem (a false "start over" would be rage-inducing at
/// 6am; failed attempts are only counted for telemetry).
public struct MathProofSession: Equatable, Sendable {
    public let config: MathProofConfig
    public private(set) var solvedCount = 0
    public private(set) var failedAttempts = 0
    public private(set) var currentProblem: MathProblem
    private var rng: SplitMix64

    public init(config: MathProofConfig, seed: UInt64) {
        self.config = config
        var generator = SplitMix64(seed: seed)
        self.currentProblem = MathProblem.generate(difficulty: config.difficulty, using: &generator)
        self.rng = generator
    }

    public init(config: MathProofConfig) {
        self.init(config: config, seed: UInt64.random(in: .min ... .max))
    }

    public var isComplete: Bool { solvedCount >= config.problemCount }

    /// Returns whether the answer was correct. On the final correct answer
    /// the session becomes complete; after that, further submissions are
    /// rejected.
    @discardableResult
    public mutating func submit(_ answer: Int) -> Bool {
        guard !isComplete else { return false }
        guard answer == currentProblem.answer else {
            failedAttempts += 1
            return false
        }
        solvedCount += 1
        if !isComplete {
            currentProblem = MathProblem.generate(difficulty: config.difficulty, using: &rng)
        }
        return true
    }
}
