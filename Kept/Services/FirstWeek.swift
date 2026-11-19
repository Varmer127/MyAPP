import Foundation

/// The user's first week after the guide. Kept can be started on any day, so a guide finished on a Wednesday
/// makes a shorter first week: only the days that were left count, and the weekly minimum shrinks with them.
/// The shrinking is tied to the day of the guide, so it happens once and cannot be repeated by planning late.
enum FirstWeek {
    /// From Friday on, the week that is left is too short to plan; the first week is the next one.
    static let nextWeekFromWeekday = 6

    /// The week that counts as the first one: the week of the guide, or the next one when the guide ended on Friday to Sunday.
    static func start(onboardedAt: Date) -> Date {
        let weekday = Calendar.app.component(.weekday, from: onboardedAt)
        let startsNextWeek = weekday == 1 || weekday >= nextWeekFromWeekday
        return onboardedAt.weekStart.addingDays(startsNextWeek ? 7 : 0)
    }

    /// Days of the first week from the day of the guide to Sunday, both included, when it started after Monday.
    /// Nil for any other week and for a first week that starts on its Monday.
    static func daysCounted(weekStart: Date, onboardedAt: Date?) -> Int? {
        guard let onboardedAt, weekStart == onboardedAt.weekStart else { return nil }
        let passed = Calendar.app.dateComponents([.day], from: weekStart, to: onboardedAt.startOfDay).day ?? 0
        guard passed > 0 else { return nil }
        return 7 - passed
    }

    /// The weekly minimum for the week starting on `weekStart`: the usual one, or a share of it for a shorter first week.
    static func minimum(_ usual: Int, weekStart: Date, onboardedAt: Date?) -> Int {
        guard usual > 0, let days = daysCounted(weekStart: weekStart, onboardedAt: onboardedAt) else { return usual }
        return Int((Double(usual) * Double(days) / 7).rounded(.up))
    }
}

extension UserSettings {
    /// The weekly minimum that applies to the week starting on `weekStart` (smaller in a shortened first week).
    func minimumWeeklyTasks(forWeekStarting weekStart: Date) -> Int {
        FirstWeek.minimum(minimumWeeklyTasks, weekStart: weekStart, onboardedAt: onboardedAt)
    }
}
