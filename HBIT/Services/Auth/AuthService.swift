import Foundation
import Observation
import Supabase

/// Supabase Auth wrapper: Sign in with Apple + email magic link. Auth is
/// never required for the core loop — the app works fully signed-out and
/// offline; signing in only enables background sync and cross-device state.
@MainActor
@Observable
final class AuthService {
    enum State: Equatable {
        /// No Supabase keys in Config.xcconfig — auth UI is hidden entirely.
        case unconfigured
        case signedOut
        case signedIn(userID: UUID)
    }

    private(set) var state: State
    private let client: SupabaseClient?
    /// Same-file extensions (profile sync) reach the client through this.
    var supabaseClient: SupabaseClient? { client }

    init(config: AppConfig) {
        if let url = config.supabaseURL, let key = config.supabaseAnonKey {
            client = SupabaseClient(supabaseURL: url, supabaseKey: key)
            state = .signedOut
        } else {
            client = nil
            state = .unconfigured
        }
    }

    /// Restores a persisted session at launch, if any.
    func restoreSession() async {
        guard let client else { return }
        if let session = try? await client.auth.session {
            didSignIn(session: session)
        }
    }

    /// Completes Sign in with Apple: exchanges the Apple identity token
    /// (plus the raw nonce that was hashed into the request) for a Supabase
    /// session.
    func signInWithApple(idToken: String, nonce: String) async throws {
        guard let client else { throw AuthConfigurationError() }
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        didSignIn(session: session)
        Telemetry.track(.accountCreated, properties: ["method": "apple"])
    }

    /// Sends a magic link. The link re-enters the app via the `hbit://`
    /// URL scheme and is completed by `handle(url:)`.
    func sendMagicLink(to email: String) async throws {
        guard let client else { throw AuthConfigurationError() }
        try await client.auth.signInWithOTP(
            email: email,
            redirectTo: URL(string: "hbit://auth-callback")
        )
    }

    /// Handles the magic-link callback deep link.
    func handle(url: URL) async {
        guard let client else { return }
        do {
            let session = try await client.auth.session(from: url)
            didSignIn(session: session)
            Telemetry.track(.accountCreated, properties: ["method": "magic_link"])
        } catch {
            Telemetry.capture(error: error, context: ["phase": "magic_link_callback"])
        }
    }

    func signOut() async {
        guard let client else { return }
        try? await client.auth.signOut()
        state = .signedOut
        Telemetry.reset()
    }

    private func didSignIn(session: Session) {
        state = .signedIn(userID: session.user.id)
        Telemetry.identify(userID: session.user.id.uuidString)
    }
}

// MARK: - Profile sync (emergency-exit escalation counter)

/// The server-side emergency-exit state on `profiles` (survives
/// reinstalls). Best-effort: every call is safe to fail offline.
struct EmergencyExitProfileState: Codable {
    let uses: Int
    let lastUsedAt: Date?

    enum CodingKeys: String, CodingKey {
        case uses = "emergency_exit_uses"
        case lastUsedAt = "emergency_exit_last_used_at"
    }
}

extension AuthService {
    func fetchEmergencyExitProfile() async -> EmergencyExitProfileState? {
        guard let client = supabaseClient, case .signedIn(let userID) = state else { return nil }
        return try? await client
            .from("profiles")
            .select("emergency_exit_uses, emergency_exit_last_used_at")
            .eq("id", value: userID)
            .single()
            .execute()
            .value
    }

    func pushEmergencyExitProfile(uses: Int, lastUsedAt: Date?) async {
        guard let client = supabaseClient, case .signedIn(let userID) = state else { return }
        let update = EmergencyExitProfileState(uses: uses, lastUsedAt: lastUsedAt)
        _ = try? await client
            .from("profiles")
            .update(update)
            .eq("id", value: userID)
            .execute()
    }
}

struct AuthConfigurationError: LocalizedError {
    var errorDescription: String? {
        "Supabase is not configured. Copy Config/Config.example.xcconfig to "
            + "Config/Config.xcconfig and fill in SUPABASE_URL and SUPABASE_ANON_KEY."
    }
}
