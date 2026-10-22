import Foundation

/// Rest days planned in advance: a day the user decided to rest (an illness, a trip, a real break) neither
/// extends nor breaks the streak, like a day with nothing planned. They are limited, so it stays a choice
/// made ahead of time and not a way around a bad day.
enum RestDays {
    static let storageKey = "restDays"
    static let monthlyLimit = 2

    enum Result { case set, cleared, limitReached, inThePast }

    nonisolated(unsafe) private static var cachedRaw: String?
    nonisolated(unsafe) private static var cachedDays: Set<Date> = []

    /// Days as start-of-day times, kept as a comma separated string so a screen can watch it with `@AppStorage`.
    static var all: Set<Date> {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? ""
        if raw != cachedRaw {
            cachedRaw = raw
            cachedDays = Set(raw.split(separator: ",").compactMap(Double.init).map { Date(timeIntervalSince1970: $0).startOfDay })
        }
        return cachedDays
    }

    static func contains(_ day: Date) -> Bool { all.contains(day.startOfDay) }

    static func count(inMonthOf day: Date) -> Int {
        all.filter { Calendar.app.isDate($0, equalTo: day, toGranularity: .month) }.count
    }

    static func left(inMonthOf day: Date) -> Int { max(0, monthlyLimit - count(inMonthOf: day)) }

    /// Marks the day as a rest day or takes the mark back. Days that are over cannot be turned into rest days.
    @discardableResult
    static func toggle(_ day: Date, now: Date = .now) -> Result {
        let day = day.startOfDay
        var days = all
        if days.contains(day) {
            days.remove(day)
            save(days)
            return .cleared
        }
        guard day >= now.startOfDay else { return .inThePast }
        guard left(inMonthOf: day) > 0 else { return .limitReached }
        days.insert(day)
        save(days)
        return .set
    }

    private static func save(_ days: Set<Date>) {
        let raw = days.sorted().map { String(Int($0.timeIntervalSince1970)) }.joined(separator: ",")
        UserDefaults.standard.set(raw, forKey: storageKey)
    }
}
