import Testing
@testable import MorningKit

@Suite("ScoreCalculator")
struct ScoreCalculatorTests {
    @Test("wake-on-time is worth 40%, missions split the remaining 60%")
    func weighting() {
        #expect(ScoreCalculator.score(wokeOnTime: true, completedMissions: 0, totalMissions: 3) == 40)
        #expect(ScoreCalculator.score(wokeOnTime: true, completedMissions: 3, totalMissions: 3) == 100)
        #expect(ScoreCalculator.score(wokeOnTime: false, completedMissions: 3, totalMissions: 3) == 60)
        #expect(ScoreCalculator.score(wokeOnTime: false, completedMissions: 0, totalMissions: 3) == 0)
    }

    @Test("partial missions are proportional")
    func partialMissions() {
        // 40 + 60 * (1/3) = 60
        #expect(ScoreCalculator.score(wokeOnTime: true, completedMissions: 1, totalMissions: 3) == 60)
        // 40 + 60 * (2/3) = 80
        #expect(ScoreCalculator.score(wokeOnTime: true, completedMissions: 2, totalMissions: 3) == 80)
        // 40 + 60 * (2/5) = 64
        #expect(ScoreCalculator.score(wokeOnTime: true, completedMissions: 2, totalMissions: 5) == 64)
    }

    @Test("no missions renormalizes: the wake result is the whole score")
    func noMissions() {
        #expect(ScoreCalculator.score(wokeOnTime: true, completedMissions: 0, totalMissions: 0) == 100)
        #expect(ScoreCalculator.score(wokeOnTime: false, completedMissions: 0, totalMissions: 0) == 0)
    }

    @Test("inputs are clamped defensively")
    func clamping() {
        #expect(ScoreCalculator.score(wokeOnTime: true, completedMissions: 99, totalMissions: 3) == 100)
        #expect(ScoreCalculator.score(wokeOnTime: true, completedMissions: -5, totalMissions: 3) == 40)
    }
}
