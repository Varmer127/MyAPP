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
