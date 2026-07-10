import Foundation
import Observation
import ProofKit

/// Tracks emergency-exit usage. Local persistence keeps the escalation
/// working offline; the authoritative copy lives in the Supabase `profiles`
/// row (so it survives reinstalls) and is reconciled when signed in —
/// always in the stricter direction.
@MainActor
@Observable
final class EmergencyExitCounter {
    private static let usesKey = "hbit.emergencyExit.uses"
    private static let lastUsedKey = "hbit.emergencyExit.lastUsedAt"
    private let defaults: UserDefaults

    private(set) var uses: Int
    private(set) var lastUsedAt: Date?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.uses = defaults.integer(forKey: Self.usesKey)
        let stored = defaults.double(forKey: Self.lastUsedKey)
        self.lastUsedAt = stored > 0 ? Date(timeIntervalSince1970: stored) : nil
    }

    func effectiveUses(now: Date = .now) -> Int {
        EmergencyExitPolicy.effectiveUses(storedUses: uses, lastUsedAt: lastUsedAt, now: now)
    }

    func currentTapCost(now: Date = .now) -> Int {
        EmergencyExitPolicy.tapCost(effectiveUses: effectiveUses(now: now))
    }

    func recordUse(now: Date = .now) {
        uses = effectiveUses(now: now) + 1
        lastUsedAt = now
        persist()
    }

    /// Merge with the server-side counter, keeping the stricter state.
    func reconcile(remoteUses: Int, remoteLastUsedAt: Date?) {
        if remoteUses > uses { uses = remoteUses }
        if let remote = remoteLastUsedAt, remote > (lastUsedAt ?? .distantPast) {
            lastUsedAt = remote
        }
        persist()
    }

    private func persist() {
        defaults.set(uses, forKey: Self.usesKey)
        if let lastUsedAt {
            defaults.set(lastUsedAt.timeIntervalSince1970, forKey: Self.lastUsedKey)
        }
    }
}
