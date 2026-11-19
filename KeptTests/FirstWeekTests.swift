import Foundation
import Testing
@testable import Kept

struct FirstWeekTests {
    /// 16 November 2026 is a Monday.
    private func day(_ number: Int, hour: Int = 10) -> Date {
        Calendar.app.date(from: DateComponents(year: 2026, month: 11, day: number, hour: hour))!
    }

    @Test func wednesdayStartMakesAShorterWeekWithASmallerMinimum() {
        let monday = day(16).weekStart
        #expect(FirstWeek.start(onboardedAt: day(18)) == monday)
        #expect(FirstWeek.daysCounted(weekStart: monday, onboardedAt: day(18)) == 5)
        #expect(FirstWeek.minimum(7, weekStart: monday, onboardedAt: day(18)) == 5)
        // Rounded up, never to zero.
        #expect(FirstWeek.minimum(1, weekStart: monday, onboardedAt: day(19)) == 1)
        #expect(FirstWeek.minimum(0, weekStart: monday, onboardedAt: day(18)) == 0)
    }

    @Test func mondayStartAndLaterWeeksKeepTheUsualMinimum() {
        let monday = day(16).weekStart
        #expect(FirstWeek.daysCounted(weekStart: monday, onboardedAt: day(16, hour: 23)) == nil)
        #expect(FirstWeek.minimum(7, weekStart: monday.addingDays(7), onboardedAt: day(18)) == 7)
        #expect(FirstWeek.minimum(7, weekStart: monday, onboardedAt: nil) == 7)
    }

    @Test func fridayToSundayStartPlansTheNextWeek() {
        let nextMonday = day(16).weekStart.addingDays(7)
        #expect(FirstWeek.start(onboardedAt: day(20)) == nextMonday)
        #expect(FirstWeek.start(onboardedAt: day(22)) == nextMonday)
        #expect(FirstWeek.start(onboardedAt: day(19)) == day(16).weekStart)
    }

    @Test func overviewsOpenOneAtATimeInOrder() {
        #expect(AutoOverview.next(eveningDue: true, eveningShownToday: false, hasMonth: true, hasWeek: true, hasYesterday: true, isEvening: true) == .evening)
        #expect(AutoOverview.next(eveningDue: true, eveningShownToday: true, hasMonth: true, hasWeek: true, hasYesterday: true, isEvening: true) == .month)
        #expect(AutoOverview.next(eveningDue: false, eveningShownToday: false, hasMonth: false, hasWeek: true, hasYesterday: true, isEvening: false) == .week)
        #expect(AutoOverview.next(eveningDue: false, eveningShownToday: false, hasMonth: false, hasWeek: false, hasYesterday: true, isEvening: false) == .yesterday)
        // Yesterday's recap does not interrupt the evening.
        #expect(AutoOverview.next(eveningDue: false, eveningShownToday: false, hasMonth: false, hasWeek: false, hasYesterday: true, isEvening: true) == nil)
    }

    @Test func nothingOpensOnTheDayOfTheGuide() {
        #expect(!AutoOverview.isAllowed(onboardedAt: day(18, hour: 8), now: day(18, hour: 20)))
        #expect(AutoOverview.isAllowed(onboardedAt: day(17), now: day(18)))
        #expect(!AutoOverview.isAllowed(onboardedAt: nil, now: day(18)))
    }
}

struct ExerciseEnglishTests {
    /// Every built-in exercise has an English name and tip, and English technique when it has Czech technique.
    @Test func everyExerciseHasEnglish() {
        for exercise in ExerciseCatalog.all {
            #expect(ExerciseCatalog.shownInEnglish[exercise.name] != nil, "No English for \(exercise.name)")
        }
        for (name, czech) in ExerciseTechnique.all.merging(ExerciseTechnique.more, uniquingKeysWith: { first, _ in first }) {
            let english = ExerciseTechnique.english[name]
            #expect(english?.steps.count == czech.steps.count, "Technique steps differ: \(name)")
            #expect(english?.mistakes.count == czech.mistakes.count, "Technique mistakes differ: \(name)")
        }
    }
}

@MainActor
struct ActivityNameTests {
    /// Built-in activity names stored in tasks are rewritten in the chosen language, both ways.
    @Test func builtInNamesFollowTheLanguage() {
        let toEnglish = ActivityNames.translations(to: .en)
        #expect(toEnglish["Ostatní"] == "Other")
        #expect(toEnglish["Práce"] == "Work")
        #expect(toEnglish["Procházka v přírodě"] != nil)
        let toCzech = ActivityNames.translations(to: .cs)
        #expect(toCzech["Other"] == "Ostatní")
        #expect(toCzech["Work"] == "Práce")
        // A name the user typed is not a built-in one.
        #expect(toEnglish["Kytara"] == nil)
    }
}
