import Foundation
import PostHog

/// Product analytics via PostHog. Only `Telemetry` talks to this type.
@MainActor
final class PostHogBackend: TelemetryBackend {
    private let apiKey: String
    private let host: String

    init(apiKey: String, host: String?) {
        self.apiKey = apiKey
        self.host = host ?? "https://eu.i.posthog.com"
    }

    func start() {
        let config = PostHogConfig(apiKey: apiKey, host: host)
        PostHogSDK.shared.setup(config)
    }

    func track(_ event: String, properties: [String: String]) {
        PostHogSDK.shared.capture(event, properties: properties)
    }

    func identify(userID: String) {
        PostHogSDK.shared.identify(userID)
    }

    func capture(error: any Error, context: [String: String]) {
        // Errors go to Sentry; PostHog only needs the fact one happened for
        // funnel analysis.
        PostHogSDK.shared.capture("app_error", properties: context)
    }

    func reset() {
        PostHogSDK.shared.reset()
    }
}
