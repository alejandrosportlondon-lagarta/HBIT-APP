import Foundation
import Testing
@testable import MorningKit

@Suite("MorningDateKey")
struct MorningDateKeyTests {
    @Test("keys step across month, year, and leap boundaries")
    func boundaries() {
        #expect(MorningDateKey.previous("2026-03-01") == "2026-02-28")
        #expect(MorningDateKey.previous("2028-03-01") == "2028-02-29") // leap year
        #expect(MorningDateKey.previous("2026-01-01") == "2025-12-31")
        #expect(MorningDateKey.next("2026-12-31") == "2027-01-01")
        #expect(MorningDateKey.offset("2026-07-10", by: -30) == "2026-06-10")
    }

    @Test("the same instant is a different day in different timezones (timezone travel)")
    func timezoneTravel() {
        // 2026-07-10 01:00 UTC: already the 10th in Tokyo, still the 9th in New York.
        let instant = Date(timeIntervalSince1970: 1_783_645_200)
        let tokyo = MorningDateKey.key(for: instant, in: TimeZone(identifier: "Asia/Tokyo")!)
        let newYork = MorningDateKey.key(for: instant, in: TimeZone(identifier: "America/New_York")!)
        #expect(tokyo == "2026-07-10")
        #expect(newYork == "2026-07-09")
    }

    @Test("garbage keys return nil instead of corrupting math")
    func garbageKeys() {
        #expect(MorningDateKey.previous("not-a-key") == nil)
        #expect(MorningDateKey.previous("2026-07") == nil)
    }
}

@Suite("StreakEngine")
struct StreakEngineTests {
    @Test("streak counts consecutive WIN days including today")
    func basicStreak() {
        let wins: Set = ["2026-07-08", "2026-07-09", "2026-07-10"]
        #expect(StreakEngine.currentStreak(winKeys: wins, today: "2026-07-10") == 3)
    }

    @Test("an undecided today keeps yesterday's streak alive")
    func undecidedToday() {
        let wins: Set = ["2026-07-08", "2026-07-09"]
        #expect(StreakEngine.currentStreak(winKeys: wins, today: "2026-07-10") == 2)
    }

    @Test("a gap breaks the streak")
    func gapBreaks() {
        let wins: Set = ["2026-07-06", "2026-07-07", "2026-07-09", "2026-07-10"]
        #expect(StreakEngine.currentStreak(winKeys: wins, today: "2026-07-10") == 2)
        // Two days with nothing → 0.
        #expect(StreakEngine.currentStreak(winKeys: ["2026-07-01"], today: "2026-07-10") == 0)
    }

    @Test("streaks span DST transitions — keys are plain calendar days")
    func dstTransition() {
        // Europe spring-forward night was 2026-03-28 → 2026-03-29.
        let wins: Set = ["2026-03-27", "2026-03-28", "2026-03-29", "2026-03-30"]
        #expect(StreakEngine.currentStreak(winKeys: wins, today: "2026-03-30") == 4)
        // US fall-back: 2026-10-31 → 2026-11-01.
        let fallBack: Set = ["2026-10-31", "2026-11-01"]
        #expect(StreakEngine.currentStreak(winKeys: fallBack, today: "2026-11-01") == 2)
    }

    @Test("streaks survive timezone travel when calendar days stay consecutive")
    func timezoneTravelStreak() {
        // Flying Tokyo → New York: the traveler's local dateKeys stay
        // consecutive even though UTC offsets jumped 13 hours.
        let wins: Set = ["2026-07-08", "2026-07-09", "2026-07-10"]
        #expect(StreakEngine.currentStreak(winKeys: wins, today: "2026-07-10") == 3)
    }

    @Test("longest streak scans all runs")
    func longest() {
        let wins: Set = [
            "2026-06-01", "2026-06-02",
            "2026-06-10", "2026-06-11", "2026-06-12", "2026-06-13",
            "2026-07-01"
        ]
        #expect(StreakEngine.longestStreak(winKeys: wins) == 4)
        #expect(StreakEngine.longestStreak(winKeys: []) == 0)
    }

    @Test("history strip maps wins, losses and empty days, oldest first")
    func historyStrip() {
        let entries = StreakEngine.history(
            endingAt: "2026-07-10",
            days: 4,
            winKeys: ["2026-07-09", "2026-07-10"],
            lossKeys: ["2026-07-07"]
        )
        #expect(entries.map(\.key) == ["2026-07-07", "2026-07-08", "2026-07-09", "2026-07-10"])
        #expect(entries.map(\.outcome) == [.loss, .none, .win, .win])
    }

    @Test("history spans month boundaries")
    func historyAcrossMonths() {
        let entries = StreakEngine.history(endingAt: "2026-07-02", days: 4, winKeys: [], lossKeys: [])
        #expect(entries.map(\.key) == ["2026-06-29", "2026-06-30", "2026-07-01", "2026-07-02"])
    }
}
