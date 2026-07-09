import Foundation
import Sentry

/// Error monitoring via Sentry. Only `Telemetry` talks to this type.
@MainActor
final class SentryBackend: TelemetryBackend {
    private let dsn: String

    init(dsn: String) {
        self.dsn = dsn
    }

    func start() {
        SentrySDK.start { options in
            options.dsn = self.dsn
            options.tracesSampleRate = 0.2
        }
    }

    func track(_ event: String, properties: [String: String]) {
        // Product analytics belong to PostHog; Sentry only gets breadcrumbs
        // so crashes carry recent user actions.
        let crumb = Breadcrumb(level: .info, category: "event")
        crumb.message = event
        crumb.data = properties
        SentrySDK.addBreadcrumb(crumb)
    }

    func identify(userID: String) {
        let user = User()
        user.userId = userID
        SentrySDK.setUser(user)
    }

    func capture(error: any Error, context: [String: String]) {
        SentrySDK.capture(error: error) { scope in
            scope.setContext(value: context, key: "hbit")
        }
    }

    func reset() {
        SentrySDK.setUser(nil)
    }
}
