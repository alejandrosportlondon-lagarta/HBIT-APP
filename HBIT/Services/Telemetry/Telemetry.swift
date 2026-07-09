import Foundation
import os

/// The only entry point features may use for analytics and error reporting.
/// No direct Sentry/PostHog calls outside this folder — backends are
/// swappable and the app runs fine with none configured.
///
/// Event names are not free-form: use `AnalyticsEvent`, whose cases mirror
/// `docs/analytics-events.md`. Propose new events there first.
@MainActor
enum Telemetry {
    private static var backends: [any TelemetryBackend] = []
    private static let logger = Logger(subsystem: "com.hbit.app", category: "telemetry")

    /// Called once at launch. Backends whose keys are missing are skipped.
    static func configure(with config: AppConfig) {
        var active: [any TelemetryBackend] = []
        if let dsn = config.sentryDSN {
            active.append(SentryBackend(dsn: dsn))
        }
        if let key = config.postHogAPIKey {
            active.append(PostHogBackend(apiKey: key, host: config.postHogHost))
        }
        backends = active
        backends.forEach { $0.start() }
        logger.info("Telemetry configured with \(active.count) backend(s)")
    }

    static func track(_ event: AnalyticsEvent, properties: [String: String] = [:]) {
        logger.debug("track: \(event.rawValue)")
        backends.forEach { $0.track(event.rawValue, properties: properties) }
    }

    static func identify(userID: String) {
        backends.forEach { $0.identify(userID: userID) }
    }

    static func capture(error: any Error, context: [String: String] = [:]) {
        logger.error("capture: \(error)")
        backends.forEach { $0.capture(error: error, context: context) }
    }

    static func reset() {
        backends.forEach { $0.reset() }
    }
}

/// One analytics/monitoring SDK, hidden behind the facade.
@MainActor
protocol TelemetryBackend {
    func start()
    func track(_ event: String, properties: [String: String])
    func identify(userID: String)
    func capture(error: any Error, context: [String: String])
    func reset()
}
