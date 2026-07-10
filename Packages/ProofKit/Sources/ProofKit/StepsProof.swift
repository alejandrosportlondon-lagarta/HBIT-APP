import Foundation

public struct StepsProofConfig: ProofConfig {
    public static let kind = ProofType.steps

    public static let allowedRange = 10...100

    /// Steps to walk, clamped to 10–100 (TASKS.md).
    public let targetSteps: Int

    public init(targetSteps: Int) {
        self.targetSteps = min(Self.allowedRange.upperBound, max(Self.allowedRange.lowerBound, targetSteps))
    }
}

/// The steps proof's state machine. Fed cumulative step counts from the
/// pedometer (which reports steps since the session started); the first
/// update establishes a baseline so any pre-existing count is excluded.
/// Progress is monotonic — a glitchy lower reading can never take steps
/// away from a half-asleep user (deterministic verification guardrail).
public struct StepsProofSession: Equatable, Sendable {
    public let config: StepsProofConfig
    public private(set) var stepsTaken = 0
    private var baseline: Int?

    public init(config: StepsProofConfig) {
        self.config = config
    }

    public var remainingSteps: Int { max(0, config.targetSteps - stepsTaken) }
    public var isComplete: Bool { stepsTaken >= config.targetSteps }

    public mutating func update(cumulativeSteps: Int) {
        let reading = max(0, cumulativeSteps)
        let base = baseline ?? reading
        baseline = base
        stepsTaken = max(stepsTaken, reading - base)
    }
}
