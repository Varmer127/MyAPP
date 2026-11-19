import Foundation

/// Which ready overview opens by itself when the app comes to the front, so it is not left waiting under the bell.
/// One per opening, the most useful first; the others follow on the next openings and stay in the bell meanwhile.
/// The morning greeting and the weekly reflection have their own rules and go before all of these.
enum AutoOverview: Equatable {
    /// The evening close of the day, once a day from the evening time on, while something is still open today.
    case evening
    case month
    case week
    /// How yesterday went; only before the evening, when the day has moved on to its own close.
    case yesterday

    static func next(eveningDue: Bool, eveningShownToday: Bool, hasMonth: Bool, hasWeek: Bool,
                     hasYesterday: Bool, isEvening: Bool) -> AutoOverview? {
        if eveningDue, !eveningShownToday { return .evening }
        if hasMonth { return .month }
        if hasWeek { return .week }
        if hasYesterday, !isEvening { return .yesterday }
        return nil
    }

    /// Nothing opens by itself on the day the guide was finished: the user has only just met the app.
    static func isAllowed(onboardedAt: Date?, now: Date) -> Bool {
        guard let onboardedAt else { return false }
        return onboardedAt.startOfDay < now.startOfDay
    }
}
