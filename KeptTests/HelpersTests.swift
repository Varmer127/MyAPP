import Foundation
import Testing
@testable import Kept

struct HelpersTests {
    @Test func czechPluralsOfDays() {
        #expect(String.days(1) == "1 den")
        #expect(String.days(3) == "3 dny")
        #expect(String.days(5) == "5 dní")
    }

    @Test func activityNamesCompareLikeAPersonWould() {
        #expect("Čtení ".activityKey == "cteni")
        #expect("GYM".activityKey == "gym")
    }

    @Test func theWeekStartsOnMonday() {
        let sunday = Calendar.app.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 23))!
        let monday = Calendar.app.date(from: DateComponents(year: 2026, month: 10, day: 19))!
        #expect(sunday.weekStart == monday)
    }

    @Test func theStoryIsAlwaysAboutTheWeekThatJustEnded() {
        #expect(WeekStory.offeredWeek(now: Fixture.now) == Fixture.now.weekStart.addingDays(-7))
    }

    @Test func aWeekWithNothingInItHasNoStory() {
        #expect(WeekStory.make(tasks: [], diary: [], weekStart: Fixture.now.weekStart.addingDays(-7), now: Fixture.now) == nil)
    }

    @Test func gymAndSportAreWorkoutsAndCustomActivitiesOnlyWhenMarked() {
        let settings = UserSettings()
        settings.customActivities = ["Lezení", "Kytara"]
        settings.setCountsAsWorkout(true, custom: "lezeni")
        #expect(settings.isWorkout(Fixture.task(category: .gym)))
        #expect(settings.isWorkout(Fixture.task(category: .sport)))
        #expect(settings.isWorkout(Fixture.task("Lezení", category: .other)))
        #expect(!settings.isWorkout(Fixture.task("Kytara", category: .other)))
        #expect(!settings.isWorkout(Fixture.task(category: .work)))
    }

    @Test func addressFormsFollowTheChosenGrammar() {
        #expect(GrammarGender.feminine.pick("splnil", "splnila") == "splnila")
        #expect(GrammarGender.neutral.pick("splnil", "splnila") == "splnil(a)")
        #expect(GrammarGender.neutral.pick("splnil", "splnila", neutral: "splněno") == "splněno")
    }
}

@MainActor
struct DayRecapTests {
    @Test func yesterdayIsSummedUp() {
        let tasks = [Fixture.task("A", day: -1, done: true), Fixture.task("B", day: -1), Fixture.task("Dnes", day: 0, done: true)]
        let recap = DayRecap.make(tasks: tasks, now: Fixture.now)
        #expect(recap?.total == 2)
        #expect(recap?.done == 1)
        #expect(recap?.day == Fixture.now.startOfDay.addingDays(-1))
    }

    @Test func aDayWithoutTasksHasNoRecap() {
        #expect(DayRecap.make(tasks: [Fixture.task(day: -3)], now: Fixture.now) == nil)
    }
}

@MainActor
struct WeekSnapshotTests {
    @Test func countsTheWeekAndSharesThePlanOnlyWhenAsked() {
        let week = Fixture.now.weekStart
        let tasks = [Fixture.task("Gym", day: -1, done: true), Fixture.task("Čtení", day: 0), Fixture.task("Minulý týden", day: -9, done: true)]
        let summary = WeekSnapshot.make(week: week, tasks: tasks, plans: [], streak: 2, badges: 5, includePlan: false, now: Fixture.now)
        #expect(summary.total == 2)
        #expect(summary.done == 1)
        #expect(summary.tasks.isEmpty)
        #expect(summary.badges == 5)
        let plan = WeekSnapshot.make(week: week, tasks: tasks, plans: [], streak: 2, badges: 5, includePlan: true, now: Fixture.now)
        #expect(plan.tasks.map(\.title) == ["Gym", "Čtení"])
        #expect(plan.tasks.map(\.status) == ["done", "open"])
    }

    @Test func dayStringsAreLocalDates() {
        let day = Calendar.app.date(from: DateComponents(year: 2026, month: 11, day: 2))!
        #expect(DayString.string(day) == "2026-11-02")
        #expect(DayString.date("2026-11-02") == day)
    }
}

@MainActor
struct ChallengeProgressTests {
    private func challenge(category: String?) -> Challenge {
        Challenge(id: UUID(), title: "Výzva", category: category, target: 5,
                  startsOn: Fixture.now.startOfDay.addingDays(-3), endsOn: Fixture.now.startOfDay.addingDays(3),
                  isCreator: true, myStatus: "accepted", members: [])
    }

    @Test func countsFinishedTasksOfTheKindWithinTheDays() {
        let tasks = [Fixture.task("Gym", day: -1, done: true, category: .gym),
                     Fixture.task("Gym", day: 0, category: .gym),
                     Fixture.task("Práce", day: 0, done: true, category: .work),
                     Fixture.task("Starý gym", day: -10, done: true, category: .gym)]
        #expect(ChallengeProgress.count(tasks: tasks, challenge: challenge(category: "gym")) == 1)
        #expect(ChallengeProgress.count(tasks: tasks, challenge: challenge(category: nil)) == 2)
    }
}
