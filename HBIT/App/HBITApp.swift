import SwiftData
import SwiftUI

@main
struct HBITApp: App {
    @State private var auth: AuthService

    /// Local store first — the alarm/proof/scoring core reads and writes
    /// here with zero connectivity; SyncKit reconciles to Supabase later.
    let modelContainer: ModelContainer = {
        let schema = Schema([
            Morning.self,
            Mission.self,
            AlarmConfig.self,
            ProofReference.self,
            StreakState.self
        ])
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    init() {
        let config = AppConfig.fromInfoPlist()
        Telemetry.configure(with: config)
        _auth = State(initialValue: AuthService(config: config))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .preferredColorScheme(.dark)
                .task { await auth.restoreSession() }
                .onOpenURL { url in
                    Task { await auth.handle(url: url) }
                }
        }
        .modelContainer(modelContainer)
    }
}
