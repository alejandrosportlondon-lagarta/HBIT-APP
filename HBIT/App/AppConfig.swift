import Foundation

/// Runtime configuration injected via xcconfig → Info.plist. Secrets never
/// live in the repo: `Config/Config.example.xcconfig` is committed, the real
/// `Config/Config.xcconfig` is gitignored. Every value is optional — the app
/// must run end-to-end offline/unconfigured, so missing keys simply disable
/// the corresponding backend.
struct AppConfig: Sendable {
    var supabaseURL: URL?
    var supabaseAnonKey: String?
    var sentryDSN: String?
    var postHogAPIKey: String?
    var postHogHost: String?

    static func fromInfoPlist(bundle: Bundle = .main) -> AppConfig {
        func value(_ key: String) -> String? {
            guard let raw = bundle.object(forInfoDictionaryKey: key) as? String,
                  !raw.trimmingCharacters(in: .whitespaces).isEmpty
            else { return nil }
            return raw
        }
        return AppConfig(
            supabaseURL: value("SUPABASE_URL").flatMap(URL.init(string:)),
            supabaseAnonKey: value("SUPABASE_ANON_KEY"),
            sentryDSN: value("SENTRY_DSN"),
            postHogAPIKey: value("POSTHOG_API_KEY"),
            postHogHost: value("POSTHOG_HOST")
        )
    }
}
