import CoreMotion
import Foundation
import Observation

/// CMPedometer wrapper feeding cumulative step counts (since `start()`)
/// into the UI, which forwards them to `StepsProofSession`. Requires a
/// physical device; on simulators `statusMessage` explains and Debug
/// builds offer an injection button instead.
@MainActor
@Observable
final class StepCounter {
    private let pedometer = CMPedometer()
    private(set) var cumulativeSteps = 0
    private(set) var statusMessage: String?
    private var isRunning = false

    static var isAvailable: Bool { CMPedometer.isStepCountingAvailable() }

    func start() {
        guard !isRunning else { return }
        guard Self.isAvailable else {
            statusMessage = "Step counting isn't available here (simulator or unsupported device)."
            return
        }
        isRunning = true
        pedometer.startUpdates(from: .now) { [weak self] data, error in
            let steps = data?.numberOfSteps.intValue
            let failure = error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let steps { self.cumulativeSteps = max(self.cumulativeSteps, steps) }
                if let failure { self.statusMessage = failure }
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        pedometer.stopUpdates()
        isRunning = false
    }

    #if DEBUG
    /// Simulator support: inject steps by hand.
    func debugAdd(_ steps: Int) {
        cumulativeSteps += steps
    }
    #endif
}
