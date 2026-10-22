import Foundation
import Testing
@testable import Kept

struct ScoringTests {
    @Test func productivityIsNilWithoutTasks() {
        #expect(ScoreEngine.productivity([], now: Fixture.now) == nil)
    }

    @Test func productivityIsOneWhenEverythingIsDone() {
        let tasks = [Fixture.task(done: true), Fixture.task(done: true, weight: 3)]
        #expect(ScoreEngine.productivity(tasks, now: Fixture.now) == 1)
    }

    @Test func productivityFollowsTheWeights() {
        let tasks = [Fixture.task(done: true, weight: 3), Fixture.task(weight: 1)]
        #expect(ScoreEngine.productivity(tasks, now: Fixture.now) == 0.75)
    }

    @Test func excusedTasksAreLeftOutOfTheScore() {
        let excused = Fixture.task(weight: 5)
        excused.status = .excused
        let tasks = [Fixture.task(done: true), excused]
        #expect(ScoreEngine.productivity(tasks, now: Fixture.now) == 1)
    }

    @Test func lostCriticalTaskLowersTheScore() {
        let lost = Fixture.task(day: -1, weight: 3, priority: .critical)
        let kept = Fixture.task(day: -1, done: true, weight: 3)
        let score = ScoreEngine.productivity([lost, kept], now: Fixture.now)
        // Half of the points are earned and the only critical task is lost: 0.5 × (1 − 0.10).
        #expect(score != nil && abs(score! - 0.45) < 0.0001)
    }

    @Test func streakCountsConsecutiveKeptDaysIncludingToday() {
        let tasks = Fixture.days(-3...0)
        #expect(ScoreEngine.dayStreak(tasks, now: Fixture.now) == 4)
    }

    @Test func streakStopsAtADayUnderEightyPercent() {
        var tasks = Fixture.days(-4...(-2))
        tasks.append(Fixture.task(day: -1, done: false))
        tasks.append(Fixture.task(day: 0, done: true))
        #expect(ScoreEngine.dayStreak(tasks, now: Fixture.now) == 1)
    }

    @Test func daysWithoutTasksNeitherExtendNorBreakTheStreak() {
        let tasks = [Fixture.task(day: -3, done: true), Fixture.task(day: 0, done: true)]
        #expect(ScoreEngine.dayStreak(tasks, now: Fixture.now) == 2)
    }

    @Test func aRepairedDayDoesNotBreakTheStreak() {
        let broken = Fixture.task(day: -1, done: false)
        broken.streakRepairDay = broken.scheduledDate
        let tasks = [Fixture.task(day: -2, done: true), broken, Fixture.task(day: 0, done: true)]
        #expect(ScoreEngine.dayStreak(tasks, now: Fixture.now) == 2)
    }

    @Test func streakContinuesAcrossTheEndOfDaylightSavingTime() {
        // The clocks go back on 25 October 2026: that Sunday has 25 hours and must still be one day.
        let sunday = Calendar.app.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 12))!
        let tasks = (-2...0).map { offset -> TaskItem in
            let task = TaskItem(title: "Úkol", category: .work, priority: .medium, weight: 2, scheduledDate: sunday.addingDays(offset))
            task.markDone(at: sunday.addingDays(offset).startOfDay.addingTimeInterval(10 * 3600))
            return task
        }
        #expect(ScoreEngine.dayStreak(tasks, now: sunday) == 3)
    }

    @Test func milestonesAreReachedOnTheDayTheStreakGetsThatLong() {
        let milestones = StreakService.milestones(Fixture.days(-2...0), now: Fixture.now)
        #expect(milestones.first { $0.days == 3 }?.reachedOn != nil)
        #expect(milestones.first { $0.days == 7 }?.reachedOn == nil)
    }
}
