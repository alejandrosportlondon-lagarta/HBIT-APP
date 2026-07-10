import Foundation
import Testing
@testable import AlarmEngine

@Suite("AlarmOccurrenceCalculator")
struct AlarmOccurrenceCalculatorTests {
    private let london = TimeZone(identifier: "Europe/London")!
    private let newYork = TimeZone(identifier: "America/New_York")!
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func utc(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: iso)!
    }

    private func components(of date: Date, in timeZone: TimeZone) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    }

    @Test("normal summer day in London: 07:00 local is 06:00 UTC")
    func londonSummer() {
        let fire = AlarmOccurrenceCalculator.nextFireDate(
            hour: 7, minute: 0, timeZone: london, after: utc("2026-07-01T20:00:00Z")
        )
        #expect(fire == utc("2026-07-02T06:00:00Z"))
    }

    @Test("normal winter day in London: 07:00 local is 07:00 UTC")
    func londonWinter() {
        let fire = AlarmOccurrenceCalculator.nextFireDate(
            hour: 7, minute: 0, timeZone: london, after: utc("2026-01-15T20:00:00Z")
        )
        #expect(fire == utc("2026-01-16T07:00:00Z"))
    }

    @Test("spring forward, London 2026-03-29: 01:30 does not exist — fires right after the gap")
    func londonSpringForwardGap() {
        // Clocks jump 01:00 → 02:00 local at 01:00 UTC.
        let fire = AlarmOccurrenceCalculator.nextFireDate(
            hour: 1, minute: 30, timeZone: london, after: utc("2026-03-28T22:00:00Z")
        )
        let comps = components(of: fire!, in: london)
        #expect(comps.day == 29)
        #expect(comps.hour == 2)
        #expect(comps.minute == 0)
        #expect(fire == utc("2026-03-29T01:00:00Z"))
    }

    @Test("fall back, London 2026-10-25: 01:30 happens twice — fires at the first occurrence")
    func londonFallBackAmbiguity() {
        // Clocks fall 02:00 BST → 01:00 GMT at 01:00 UTC. The first 01:30
        // local is BST (00:30 UTC); the second is GMT (01:30 UTC).
        let fire = AlarmOccurrenceCalculator.nextFireDate(
            hour: 1, minute: 30, timeZone: london, after: utc("2026-10-24T22:00:00Z")
        )
        #expect(fire == utc("2026-10-25T00:30:00Z"))
    }

    @Test("spring forward, New York 2026-03-08: 02:30 does not exist — fires at 03:00 EDT")
    func newYorkSpringForwardGap() {
        let fire = AlarmOccurrenceCalculator.nextFireDate(
            hour: 2, minute: 30, timeZone: newYork, after: utc("2026-03-08T01:00:00Z")
        )
        let comps = components(of: fire!, in: newYork)
        #expect(comps.day == 8)
        #expect(comps.hour == 3)
        #expect(comps.minute == 0)
        #expect(fire == utc("2026-03-08T07:00:00Z"))
    }

    @Test("crossing a DST boundary shifts the UTC instant, not the wall clock")
    func wallClockStableAcrossTransition() {
        // 07:00 New York the day before vs the day after spring-forward:
        // 12:00 UTC (EST) then 11:00 UTC (EDT) — one hour apart in UTC,
        // identical on the user's clock.
        let before = AlarmOccurrenceCalculator.nextFireDate(
            hour: 7, minute: 0, timeZone: newYork, after: utc("2026-03-07T00:00:00Z")
        )
        let after = AlarmOccurrenceCalculator.nextFireDate(
            hour: 7, minute: 0, timeZone: newYork, after: utc("2026-03-09T00:00:00Z")
        )
        #expect(before == utc("2026-03-07T12:00:00Z"))
        #expect(after == utc("2026-03-09T11:00:00Z"))
    }

    @Test("timezone without DST is trivial")
    func tokyoNoDST() {
        let fire = AlarmOccurrenceCalculator.nextFireDate(
            hour: 6, minute: 45, timeZone: tokyo, after: utc("2026-03-29T00:00:00Z")
        )
        #expect(fire == utc("2026-03-29T21:45:00Z"))
    }

    @Test("result is always strictly after the reference")
    func strictlyAfterReference() {
        // Reference is exactly 07:00 London — next fire must be tomorrow.
        let reference = utc("2026-07-02T06:00:00Z")
        let fire = AlarmOccurrenceCalculator.nextFireDate(
            hour: 7, minute: 0, timeZone: london, after: reference
        )
        #expect(fire == utc("2026-07-03T06:00:00Z"))
    }

    @Test("nonsense components are rejected")
    func invalidComponents() {
        #expect(AlarmOccurrenceCalculator.nextFireDate(hour: 24, minute: 0, timeZone: london, after: .now) == nil)
        #expect(AlarmOccurrenceCalculator.nextFireDate(hour: -1, minute: 0, timeZone: london, after: .now) == nil)
        #expect(AlarmOccurrenceCalculator.nextFireDate(hour: 7, minute: 60, timeZone: london, after: .now) == nil)
    }
}
