import AlarmEngine
import Foundation
import UserNotifications

/// Routes HBIT notifications into the coordinator by category: alarm-chain
/// entries drive the ringing flow; Wake-Up Check interactions acknowledge
/// the check. Registered as the center's delegate before the app finishes
/// launching so a tap that cold-starts the app is not lost.
final class AlarmNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private let onAlarmEvent: @MainActor @Sendable () -> Void
    private let onWakeUpCheckAcknowledged: @MainActor @Sendable () -> Void

    init(
        onAlarmEvent: @escaping @MainActor @Sendable () -> Void,
        onWakeUpCheckAcknowledged: @escaping @MainActor @Sendable () -> Void
    ) {
        self.onAlarmEvent = onAlarmEvent
        self.onWakeUpCheckAcknowledged = onWakeUpCheckAcknowledged
    }

    private static func category(of notification: UNNotification) -> String {
        notification.request.content.categoryIdentifier
    }

    /// Foreground presentation: alarm entries suppress the banner (the
    /// full-screen ringing UI + audio take over); Wake-Up Checks show
    /// normally so the user can confirm from wherever they are.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        switch Self.category(of: notification) {
        case UserNotificationScheduler.alarmCategoryIdentifier:
            let handler = onAlarmEvent
            await MainActor.run { handler() }
            return []
        case UserNotificationScheduler.wakeUpCheckCategoryIdentifier:
            return [.banner, .sound]
        default:
            return [.banner, .sound]
        }
    }

    /// The user tapped a notification (or an action on one).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        switch Self.category(of: response.notification) {
        case UserNotificationScheduler.alarmCategoryIdentifier:
            let handler = onAlarmEvent
            await MainActor.run { handler() }
        case UserNotificationScheduler.wakeUpCheckCategoryIdentifier:
            // Default tap and the "I'm up" action both count as confirmation.
            let handler = onWakeUpCheckAcknowledged
            await MainActor.run { handler() }
        default:
            break
        }
    }
}
