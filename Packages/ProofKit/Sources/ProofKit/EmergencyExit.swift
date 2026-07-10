import Foundation

/// Emergency-exit escalation rules (product guardrails): 100 taps base,
/// +100 per use, the use count resets 30 days after the last use. The
/// authoritative use counter lives server-side (`profiles`) so it survives
/// reinstalls; this policy is pure math over that state.
public enum EmergencyExitPolicy {
    public static let baseTaps = 100
    public static let escalationPerUse = 100
    public static let resetInterval: TimeInterval = 30 * 24 * 60 * 60

    /// Uses that still count against the user: 0 if the last use is more
    /// than 30 days ago (or there never was one).
    public static func effectiveUses(storedUses: Int, lastUsedAt: Date?, now: Date) -> Int {
        guard let lastUsedAt, now.timeIntervalSince(lastUsedAt) < resetInterval else { return 0 }
        return max(0, storedUses)
    }

    public static func tapCost(effectiveUses: Int) -> Int {
        baseTaps + escalationPerUse * max(0, effectiveUses)
    }
}

/// The moving-target tap challenge. The target jumps to a new position
/// after every hit; positions are in the unit square (mapped to screen
/// space by the UI) and seeded for testability, inset from the edges so
/// the target is always fully reachable.
public struct EmergencyExitChallengeSession: Equatable, Sendable {
    public struct TargetPosition: Equatable, Sendable {
        public let x: Double
        public let y: Double
    }

    public let requiredTaps: Int
    public private(set) var tapsCompleted = 0
    public private(set) var targetPosition: TargetPosition
    private var rng: SplitMix64

    public init(requiredTaps: Int, seed: UInt64) {
        self.requiredTaps = max(1, requiredTaps)
        var generator = SplitMix64(seed: seed)
        self.targetPosition = Self.nextPosition(using: &generator)
        self.rng = generator
    }

    public init(requiredTaps: Int) {
        self.init(requiredTaps: requiredTaps, seed: UInt64.random(in: .min ... .max))
    }

    public var isComplete: Bool { tapsCompleted >= requiredTaps }
    public var remainingTaps: Int { max(0, requiredTaps - tapsCompleted) }

    /// Registers a successful hit on the target and moves it.
    public mutating func registerHit() {
        guard !isComplete else { return }
        tapsCompleted += 1
        if !isComplete {
            targetPosition = Self.nextPosition(using: &rng)
        }
    }

    private static func nextPosition(using rng: inout SplitMix64) -> TargetPosition {
        TargetPosition(
            x: Double.random(in: 0.10...0.90, using: &rng),
            y: Double.random(in: 0.15...0.85, using: &rng)
        )
    }
}
