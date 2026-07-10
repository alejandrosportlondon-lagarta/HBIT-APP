import SwiftUI

/// Shell routing: sign-in vs home, with the alarm cover above everything.
/// The alarm never depends on auth state — it must ring signed-out and
/// offline — so the full-screen cover wraps both branches.
struct RootView: View {
    @Environment(AuthService.self) private var auth
    @Environment(AlarmCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var coordinator = coordinator
        Group {
            switch auth.state {
            case .signedOut:
                SignInView()
            case .signedIn, .unconfigured:
                HomeView()
            }
        }
        .fullScreenCover(isPresented: $coordinator.isPresentingAlarm) {
            RingingView()
        }
    }
}
