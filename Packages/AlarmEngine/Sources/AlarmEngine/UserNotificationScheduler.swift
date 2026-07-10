import Foundation
import UserNotifications

/// `UNUserNotificationCenter`-backed scheduler (ADR 002). Uses calendar
/// triggers pinned to UTC components so each entry fires at an absolute
/// instant — the fire dates were already computed in the user's timezone by
/// `AlarmOccurrenceCalculator`.
public final class UserNotificationScheduler: NotificationScheduling {
    public static let alarmCategoryIdentifier = "HBIT_ALARM"

    // UNUserNotificationCenter is documented thread-safe.
    private nonisolated(unsafe) let center = UNUserNotificationCenter.current()

    public init() {}

    public func requestAuthorization() async throws -> Bool {
        // Critical alerts are requested separately once the entitlement is
        // granted (ADR 002) — including the option without it fails.
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    public func schedule(_ plan: NotificationChainPlan, title: String, body: String) async throws {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        for entry in plan.entries {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.categoryIdentifier = Self.alarmCategoryIdentifier
            content.threadIdentifier = plan.baseIdentifier
            content.userInfo = ["hbit_alarm_base": plan.baseIdentifier]
            // Demoted silently by iOS until the Time Sensitive capability
            // is enabled on the App ID (ADR 002).
            content.interruptionLevel = .timeSensitive

            var components = utcCalendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: entry.fireDate
            )
            components.timeZone = utcCalendar.timeZone

            let request = UNNotificationRequest(
                identifier: entry.identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try await center.add(request)
        }
    }

    public func cancelChain(baseIdentifier: String) async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier)
            .filter { NotificationChainPlan.identifier($0, belongsTo: baseIdentifier) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    public func pendingCount(baseIdentifier: String) async -> Int {
        await center.pendingNotificationRequests()
            .filter { NotificationChainPlan.identifier($0.identifier, belongsTo: baseIdentifier) }
            .count
    }
}
