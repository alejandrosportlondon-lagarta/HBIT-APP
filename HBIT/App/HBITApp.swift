import AlarmEngine
import SwiftData
import SwiftUI
import UserNotifications

@main
struct HBITApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var auth: AuthService
    @State private var alarmCoordinator: AlarmCoordinator
    @State private var emergencyExitCounter = EmergencyExitCounter()
    /// Retained for the app's lifetime; registered in init so a
    /// notification tap that cold-starts the app is not missed.
    private let notificationDelegate: AlarmNotificationDelegate

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

        let coordinator = AlarmCoordinator()
        _alarmCoordinator = State(initialValue: coordinator)
        let delegate = AlarmNotificationDelegate(
            onAlarmEvent: { coordinator.alarmDidFire() },
            onWakeUpCheckAcknowledged: {
                let controller = coordinator.wakeUpCheck
                Task { await controller?.acknowledge() }
            }
        )
        notificationDelegate = delegate
        let center = UNUserNotificationCenter.current()
        center.delegate = delegate
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: UserNotificationScheduler.alarmCategoryIdentifier,
                actions: [],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: UserNotificationScheduler.wakeUpCheckCategoryIdentifier,
                actions: [
                    UNNotificationAction(identifier: "HBIT_IM_UP", title: "I'm up ✓")
                ],
                intentIdentifiers: []
            )
        ])
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(alarmCoordinator)
                .environment(emergencyExitCounter)
                .preferredColorScheme(.dark)
                .task {
                    alarmCoordinator.configure(modelContext: modelContainer.mainContext)
                    alarmCoordinator.resume()
                    await auth.restoreSession()
                    // Reinstall-proof escalation: pull the server-side
                    // counter and keep the stricter state.
                    if let remote = await auth.fetchEmergencyExitProfile() {
                        emergencyExitCounter.reconcile(
                            remoteUses: remote.uses,
                            remoteLastUsedAt: remote.lastUsedAt
                        )
                    }
                }
                .onOpenURL { url in
                    Task { await auth.handle(url: url) }
                }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            // Restart resilience: re-check the ring window whenever the app
            // returns to the foreground (ADR 002).
            if newPhase == .active {
                alarmCoordinator.resume()
            }
        }
    }
}
