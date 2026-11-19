import Foundation

extension Calendar {
    /// Monday-based calendar used for all week math, independent of device region.
    static let app: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()
}

/// The language Kept speaks: the one chosen in the app (in the guide or in Settings), otherwise the suggested one.
enum AppLanguage: String, CaseIterable, Identifiable {
    case cs, en

    var id: String { rawValue }

    /// The language's own name, never translated.
    var title: String {
        switch self {
        case .cs: "Čeština"
        case .en: "English"
        }
    }

    static var current: AppLanguage {
        KeptLanguage.chosen.flatMap(AppLanguage.init(rawValue:)) ?? suggested
    }

    /// English, unless the phone looks Czech: set to the Czech region, or with Czech among its languages.
    /// Only the phone's own settings are read; nothing about the user leaves the device.
    static var suggested: AppLanguage {
        suggested(region: Locale.current.region?.identifier, languages: Locale.preferredLanguages)
    }

    static func suggested(region: String?, languages: [String]) -> AppLanguage {
        region == "CZ" || languages.contains { $0.lowercased().hasPrefix("cs") } ? .cs : .en
    }
}

extension Locale {
    /// Dates, numbers and speech in the app's language. English keeps the phone's region, so dates read
    /// the British or the American way as the user is used to.
    static var app: Locale {
        switch AppLanguage.current {
        case .cs:
            return Locale(identifier: "cs_CZ")
        case .en:
            let region = Locale.current.region?.identifier ?? "GB"
            return Locale(identifier: "en_\(region)")
        }
    }
}

extension Date {
    var startOfDay: Date { Calendar.app.startOfDay(for: self) }

    /// Start of the following day (exclusive end of this day).
    var endOfDay: Date { startOfDay.addingDays(1) }

    var weekStart: Date {
        Calendar.app.dateInterval(of: .weekOfYear, for: self)?.start ?? startOfDay
    }

    var weekNumber: Int { Calendar.app.component(.weekOfYear, from: self) }

    func addingDays(_ days: Int) -> Date {
        Calendar.app.date(byAdding: .day, value: days, to: self) ?? self
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.app.isDate(self, inSameDayAs: other)
    }

    /// Same clock time as `time`, on the day of `self`.
    func settingTime(from time: Date) -> Date {
        let parts = Calendar.app.dateComponents([.hour, .minute], from: time)
        return Calendar.app.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: startOfDay) ?? self
    }

    /// Stable per-day number, used to pick the same copy for a day across launches.
    var daySeed: Int { Int(startOfDay.timeIntervalSinceReferenceDate / 86_400) }

    var minutesIntoDay: Int {
        let parts = Calendar.app.dateComponents([.hour, .minute], from: self)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    private func text(_ style: Date.FormatStyle) -> String {
        var style = style
        style.timeZone = .autoupdatingCurrent
        return formatted(style)
    }

    /// "18:00"
    var timeText: String { text(Date.FormatStyle(locale: .app).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)) }
    /// "Středa 7. října"
    var longDayText: String { text(Date.FormatStyle(locale: .app).weekday(.wide).day().month(.wide)).capitalizedFirst }
    /// "Wed 7"
    var shortDayText: String { text(Date.FormatStyle(locale: .app).weekday(.abbreviated).day()) }
    /// "st"
    var weekdayShortText: String { text(Date.FormatStyle(locale: .app).weekday(.abbreviated)) }
    /// "Wednesday"
    var weekdayText: String { text(Date.FormatStyle(locale: .app).weekday(.wide)) }
    /// "7 Oct"
    var dayMonthText: String { text(Date.FormatStyle(locale: .app).day().month(.defaultDigits)) }
    /// "7. 10. 18:00"
    var stampText: String { "\(dayMonthText) \(timeText)" }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }

    /// "1 den", "3 dny", "5 dní" / "1 day", "5 days": the plural forms of both languages live in the string catalog.
    static func days(_ count: Int) -> String {
        String(localized: "\(count) dní", bundle: .kept, comment: "A number of days, with plural forms")
    }
}

extension Date {
    var startOfMonth: Date {
        Calendar.app.date(from: Calendar.app.dateComponents([.year, .month], from: self)) ?? self
    }

    var monthYearText: String {
        formatted(.dateTime.month(.wide).year().locale(.app)).capitalizedFirst
    }
}
