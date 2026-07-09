import SwiftData
import SwiftUI

/// Milestone 0 shell. Signed out → sign-in; signed in (or unconfigured) →
/// a placeholder home that exercises the exit criteria: write a dummy
/// Morning locally and show it. The real home screen is Milestone 4.
struct RootView: View {
    @Environment(AuthService.self) private var auth

    var body: some View {
        switch auth.state {
        case .signedOut:
            SignInView()
        case .signedIn, .unconfigured:
            HomePlaceholderView()
        }
    }
}

private struct HomePlaceholderView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Morning.createdAt, order: .reverse) private var mornings: [Morning]

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("The Verified Morning")
                .font(DesignSystem.Typography.title)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text("Milestone 0 shell — alarm engine lands in Milestone 1.")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Write dummy Morning") {
                writeDummyMorning()
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.Colors.primary)

            Text("\(mornings.count) morning(s) in local store")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            if case .unconfigured = auth.state {
                Text("Supabase not configured — running local-only.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.accent)
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }

    /// Exit-criteria helper: proves the local write path end to end.
    private func writeDummyMorning() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let morning = Morning(
            userID: currentUserID,
            dateKey: formatter.string(from: .now),
            wakeTarget: .now,
            wakeActual: .now,
            result: .win,
            score: 100
        )
        modelContext.insert(morning)
    }

    private var currentUserID: UUID? {
        if case .signedIn(let userID) = auth.state { return userID }
        return nil
    }
}
