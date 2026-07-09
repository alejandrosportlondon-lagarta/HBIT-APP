/// Sync state of a locally stored record. The core loop (alarm, proofs,
/// scoring, streaks) is offline-first and never blocks on sync; SyncKit
/// reconciles local SwiftData records to Supabase in the background.
public enum SyncStatus: String, Codable, Sendable, CaseIterable {
    /// Created or modified locally; not yet pushed.
    case pending
    /// Acknowledged by Supabase.
    case synced
    /// Local and remote diverged; needs reconciliation.
    case conflict
}
