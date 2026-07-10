import Foundation

/// Abstraction over the system notification center so scheduling logic is
/// testable and the app can inject fakes in the reliability harness.
public protocol NotificationScheduling: Sendable {
    /// Requests alert/sound/badge authorization. Returns whether granted.
    func requestAuthorization() async throws -> Bool
    /// Schedules every entry of the chain under the given notification
    /// category (alarms and Wake-Up Checks are routed differently).
    func schedule(_ plan: NotificationChainPlan, title: String, body: String, category: String) async throws
    /// Cancels all pending entries belonging to `baseIdentifier`.
    func cancelChain(baseIdentifier: String) async
    /// Pending entries still scheduled for `baseIdentifier` (harness/debug).
    func pendingCount(baseIdentifier: String) async -> Int
}
