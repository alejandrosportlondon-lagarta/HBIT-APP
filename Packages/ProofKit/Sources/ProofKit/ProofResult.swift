import Foundation

/// Outcome of a proof verification attempt.
public enum ProofResult: Equatable, Sendable {
    case success
    case failure(reason: String)
}

/// A proof type's persisted configuration — the payload stored inside the
/// app's `ProofReference` record (and the `proof_references.payload` jsonb
/// column). TASKS.md sketches `configure() → ProofReference`; the package
/// cannot see the app's SwiftData model, so it owns the payload instead:
/// `configure` = build a config and call `payloadData()`.
///
/// Verification is deterministic and fully offline by design (product
/// guardrail: a false negative is the #1 trust killer) — everything needed
/// to verify lives in this payload.
public protocol ProofConfig: Codable, Equatable, Sendable {
    static var kind: ProofType { get }
}

public extension ProofConfig {
    func payloadData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    static func from(payload: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: payload)
    }
}

/// Deterministic seedable RNG (SplitMix64) so proof generation is
/// reproducible in tests and never a source of flakiness.
public struct SplitMix64: RandomNumberGenerator, Equatable, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}
