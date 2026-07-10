import Foundation
import UserNotifications

/// Routes alarm-chain notifications into the coordinator. Registered as the
/// notification center's delegate before the app finishes launching so a
/// tap that cold-starts the app is not lost.
final class AlarmNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private let onAlarmEvent: @MainActor @Sendable () -> Void

    init(onAlarmEvent: @escaping @MainActor @Sendable () -> Void) {
        self.onAlarmEvent = onAlarmEvent
    }

    private static func isAlarmNotification(_ notification: UNNotification) -> Bool {
        notification.request.content.userInfo["hbit_alarm_base"] is String
    }

    /// Chain entry fired while the app is frontmost: suppress the banner —
    /// the full-screen ringing UI + audio take over.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        guard Self.isAlarmNotification(notification) else { return [.banner, .sound] }
        let handler = onAlarmEvent
        await MainActor.run { handler() }
        return []
    }

    /// The user tapped a chain notification (background or cold start).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard Self.isAlarmNotification(response.notification) else { return }
        let handler = onAlarmEvent
        await MainActor.run { handler() }
    }
}
