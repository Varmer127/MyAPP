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
    /// The UI is English with 24h time, regardless of device language.
    static let app = Locale(identifier: "en_GB")
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
    /// "Wednesday 7 October"
    var longDayText: String { text(Date.FormatStyle(locale: .app).weekday(.wide).day().month(.wide)) }
    /// "Wed 7"
    var shortDayText: String { text(Date.FormatStyle(locale: .app).weekday(.abbreviated).day()) }
    /// "Wednesday"
    var weekdayText: String { text(Date.FormatStyle(locale: .app).weekday(.wide)) }
    /// "7 Oct"
    var dayMonthText: String { text(Date.FormatStyle(locale: .app).day().month(.abbreviated)) }
    /// "Wed 7 Oct, 18:00"
    var stampText: String { "\(shortDayText) \(text(Date.FormatStyle(locale: .app).month(.abbreviated))), \(timeText)" }
}
