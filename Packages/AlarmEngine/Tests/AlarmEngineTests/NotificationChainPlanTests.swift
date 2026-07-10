import Foundation
import Testing
@testable import AlarmEngine

@Suite("NotificationChainPlan")
struct NotificationChainPlanTests {
    private let fireDate = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("default plan: 60s interval over 30min, capped at 30 entries")
    func defaultPlan() {
        let plan = NotificationChainPlan(baseIdentifier: "alarm-1", fireDate: fireDate)
        #expect(plan.entries.count == 30)
        #expect(plan.entries.first?.fireDate == fireDate)
        #expect(plan.entries[1].fireDate == fireDate.addingTimeInterval(60))
        #expect(plan.entries.last?.fireDate == fireDate.addingTimeInterval(29 * 60))
    }

    @Test("entry identifiers are unique, stable, and prefix-matched to the base")
    func identifiers() {
        let plan = NotificationChainPlan(baseIdentifier: "alarm-xyz", fireDate: fireDate)
        #expect(Set(plan.entries.map(\.identifier)).count == plan.entries.count)
        #expect(plan.entries[0].identifier == "alarm-xyz#0")
        for entry in plan.entries {
            #expect(NotificationChainPlan.identifier(entry.identifier, belongsTo: "alarm-xyz"))
            #expect(!NotificationChainPlan.identifier(entry.identifier, belongsTo: "alarm-abc"))
        }
        // A different alarm whose base merely shares a prefix must not match.
        #expect(!NotificationChainPlan.identifier("alarm-xyz2#0", belongsTo: "alarm-xyz"))
    }

    @Test("interval is clamped to 30–60s")
    func intervalClamped() {
        let tooFast = NotificationChainPlan(baseIdentifier: "a", fireDate: fireDate, interval: 5)
        #expect(tooFast.entries[1].fireDate == fireDate.addingTimeInterval(30))

        let tooSlow = NotificationChainPlan(baseIdentifier: "a", fireDate: fireDate, interval: 300)
        #expect(tooSlow.entries[1].fireDate == fireDate.addingTimeInterval(60))
    }

    @Test("30s interval still respects the 30-entry cap (iOS 64-slot budget)")
    func entryCapRespected() {
        // 30s over 30min would be 61 entries — must clamp to 30.
        let plan = NotificationChainPlan(baseIdentifier: "a", fireDate: fireDate, interval: 30)
        #expect(plan.entries.count == NotificationChainPlan.maxEntries)
    }

    @Test("a short ring window produces a short chain, never zero entries")
    func shortWindow() {
        let plan = NotificationChainPlan(baseIdentifier: "a", fireDate: fireDate, interval: 60, ringWindow: 120)
        #expect(plan.entries.count == 3) // t+0, t+60, t+120

        let zero = NotificationChainPlan(baseIdentifier: "a", fireDate: fireDate, interval: 60, ringWindow: 0)
        #expect(zero.entries.count == 1) // the alarm itself always fires
    }

    @Test("ring window is clamped to 30 minutes")
    func windowClamped() {
        let plan = NotificationChainPlan(
            baseIdentifier: "a", fireDate: fireDate, interval: 60, ringWindow: 3 * 60 * 60
        )
        #expect(plan.entries.last!.fireDate <= fireDate.addingTimeInterval(NotificationChainPlan.maxRingWindow))
    }
}

@Suite("RingWindow")
struct RingWindowTests {
    private let fireDate = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("phases: pending before fire, ringing inside, expired after")
    func phases() {
        let window = RingWindow(fireDate: fireDate, duration: 1800)
        #expect(window.phase(at: fireDate.addingTimeInterval(-1)) == .pending)
        #expect(window.phase(at: fireDate) == .ringing)
        #expect(window.phase(at: fireDate.addingTimeInterval(1799)) == .ringing)
        #expect(window.phase(at: fireDate.addingTimeInterval(1800)) == .expired)
        #expect(window.phase(at: fireDate.addingTimeInterval(86_400)) == .expired)
    }

    @Test("end date matches fire date plus duration")
    func endDate() {
        let window = RingWindow(fireDate: fireDate)
        #expect(window.endDate == fireDate.addingTimeInterval(NotificationChainPlan.maxRingWindow))
    }
}
