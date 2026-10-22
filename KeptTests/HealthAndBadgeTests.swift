import Foundation
import Testing
@testable import Kept

struct HealthAndBadgeTests {
    private func day(_ offset: Int, steps: Int, km: Double = 1, kcal: Int = 300) -> HealthService.DayMetrics {
        // Monday 19 October 2026 is offset 0.
        let monday = Calendar.app.date(from: DateComponents(year: 2026, month: 10, day: 19))!
        return HealthService.DayMetrics(day: monday.addingDays(offset), steps: steps, km: km, kcal: kcal)
    }

    private func summary(steps: [Int], workouts: [(Date, String, Int)] = []) -> HealthService.Summary {
        HealthService.Summary(days: steps.enumerated().map { day($0.offset, steps: $0.element) },
                              workouts: workouts.map { (date: $0.0, name: $0.1, minutes: $0.2) }, weights: [])
    }

    @Test func statsFindTheBestDayAndTheLongestRuns() {
        let stats = HealthStats.from(summary(steps: [10_000, 10_000, 5_000, 20_000, 21_000, 22_000, 3_000]))
        #expect(stats.maxSteps == 22_000)
        #expect(stats.run10k == 3)
        #expect(stats.run20k == 3)
        #expect(stats.bestWeekKm == 7)
    }

    @Test func aWorkoutLoggedInBothPlacesCountsOnce() {
        let monday = Calendar.app.date(from: DateComponents(year: 2026, month: 10, day: 19))!
        let health: Set<Date> = [monday]
        let kept: Set<Date> = [monday.addingTimeInterval(18 * 3600)]
        #expect(HealthStats.bestWeekOfTraining(healthDays: health, keptDays: kept) == 1)
        #expect(HealthStats.bestWeekOfTraining(healthDays: health, keptDays: kept.union([monday.addingDays(1)])) == 2)
    }

    @Test func shortWorkoutsDoNotCount() {
        let monday = Calendar.app.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 18))!
        let stats = HealthStats.from(summary(steps: [1_000], workouts: [
            (monday, "Chůze", 10), (monday.addingDays(1), "Běh", 30),
        ]))
        #expect(stats.bestWeekWorkouts == 1)
    }

    @Test func bestResultsOnlyEverGrow() {
        let earlier = HealthStats(maxSteps: 25_000, run10k: 8)
        let now = HealthStats(maxSteps: 9_000, run10k: 2, bestWeekKm: 12)
        let merged = earlier.merged(with: now)
        #expect(merged.maxSteps == 25_000 && merged.run10k == 8 && merged.bestWeekKm == 12)
    }

    @Test func stepBadgesUnlockAtTheirThresholds() {
        let badges = BadgeService.healthBadges(HealthStats(maxSteps: 20_000))
        let earned = Set(badges.filter(\.isEarned).map(\.id))
        #expect(earned == ["steps10k", "steps20k"])
    }

    @Test func threeTwentyThousandDaysInARowAreNeededForThatBadge() {
        #expect(!BadgeService.healthBadges(HealthStats(run20k: 2)).first { $0.id == "run20k" }!.isEarned)
        #expect(BadgeService.healthBadges(HealthStats(run20k: 3)).first { $0.id == "run20k" }!.isEarned)
    }

    @Test func everyBadgeHasItsOwnIdAndNothingIsEarnedFromNothing() {
        let badges = BadgeService.evaluate(tasks: [], plans: [], failures: [], diary: [],
                                           targets: { $0.defaultWeeklyTarget }, health: HealthStats(), now: Fixture.now)
        #expect(Set(badges.map(\.id)).count == badges.count)
        #expect(badges.filter(\.isEarned).isEmpty)
    }
}
