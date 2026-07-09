import AuthenticationServices
import CryptoKit
import SwiftUI

/// Minimal sign-in screen: Sign in with Apple + email magic link. Lives in
/// Services/Auth because it is plumbing, not product UI — the real
/// onboarding flow (Milestone 5) will restyle this.
struct SignInView: View {
    @Environment(AuthService.self) private var auth
    @State private var email = ""
    @State private var infoMessage: String?
    @State private var currentNonce = ""

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("HBIT")
                .font(DesignSystem.Typography.display)
                .foregroundStyle(DesignSystem.Colors.primary)

            Text("Sign in to sync your mornings across devices.")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)

            SignInWithAppleButton(.signIn) { request in
                currentNonce = Self.randomNonce()
                request.requestedScopes = [.email]
                request.nonce = Self.sha256(currentNonce)
            } onCompletion: { result in
                handleAppleCompletion(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)

            VStack(spacing: DesignSystem.Spacing.sm) {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Send magic link") {
                    Task { await sendMagicLink() }
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.Colors.primary)
                .disabled(email.isEmpty)
            }

            if let infoMessage {
                Text(infoMessage)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }

    private func handleAppleCompletion(_ result: Result<ASAuthorization, any Error>) {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                infoMessage = "Apple did not return an identity token."
                return
            }
            let nonce = currentNonce
            Task {
                do {
                    try await auth.signInWithApple(idToken: idToken, nonce: nonce)
                } catch {
                    infoMessage = error.localizedDescription
                    Telemetry.capture(error: error, context: ["phase": "apple_sign_in"])
                }
            }
        case .failure(let error):
            // User cancellation is not an error worth surfacing.
            if (error as? ASAuthorizationError)?.code != .canceled {
                infoMessage = error.localizedDescription
            }
        }
    }

    private func sendMagicLink() async {
        do {
            try await auth.sendMagicLink(to: email)
            infoMessage = "Check \(email) for your sign-in link."
        } catch {
            infoMessage = error.localizedDescription
            Telemetry.capture(error: error, context: ["phase": "magic_link_send"])
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        return String((0..<length).map { _ in charset.randomElement()! })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
