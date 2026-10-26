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
