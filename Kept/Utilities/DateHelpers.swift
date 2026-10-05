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

extension Locale {
    /// The UI is Czech regardless of device language.
    static let app = Locale(identifier: "cs_CZ")
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
    /// "Wednesday"
    var weekdayText: String { text(Date.FormatStyle(locale: .app).weekday(.wide)) }
    /// "7 Oct"
    var dayMonthText: String { text(Date.FormatStyle(locale: .app).day().month(.defaultDigits)) }
    /// "7. 10. 18:00"
    var stampText: String { "\(dayMonthText) \(timeText)" }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }

    /// "1 den", "3 dny", "5 dní"
    static func days(_ count: Int) -> String {
        switch count {
        case 1: "1 den"
        case 2...4: "\(count) dny"
        default: "\(count) dní"
        }
    }
}
