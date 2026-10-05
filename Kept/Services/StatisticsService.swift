import Foundation

/// Aggregations over the history used by Stats and the Weekly Review.
enum StatisticsService {
    struct DayScore: Identifiable {
        let day: Date
        let productivity: Double?
        var id: Date { day }
    }

    struct CategoryRate: Identifiable {
        let category: TaskCategory
        let rate: Double
        let count: Int
        var id: String { category.rawValue }
    }

    struct ExcuseCount: Identifiable {
        let reason: FailureReason
        let count: Int
        /// How many of them were high-value tasks (new skill, building, work, school).
        let highValue: Int
        var id: String { reason.rawValue }
    }

    private static let promiseStreakThreshold = 0.8
    private static let maxStreakWeeks = 520

    /// Productivity of each day in `days` consecutive days starting at `from`. Future days are nil.
    static func dailyScores(tasks: [TaskItem], from: Date, days: Int, now: Date = .now) -> [DayScore] {
        let byDay = Dictionary(grouping: tasks) { $0.scheduledDate.startOfDay }
        return (0..<days).map { offset in
            let day = from.startOfDay.addingDays(offset)
            let score = day > now.startOfDay ? nil : ScoreEngine.productivity(byDay[day] ?? [], now: now)
            return DayScore(day: day, productivity: score)
        }
    }

    /// Share of tasks done per category, for categories that have any task.
    static func categoryPerformance(_ tasks: [TaskItem]) -> [CategoryRate] {
        TaskCategory.allCases.compactMap { category in
            let inCategory = tasks.filter { $0.category == category && !$0.isRecovery }
            guard !inCategory.isEmpty else { return nil }
            return CategoryRate(category: category,
                                rate: Double(inCategory.filter(\.isDone).count) / Double(inCategory.count),
                                count: inCategory.count)
        }
    }

    static func excuseCounts(_ failures: [FailureRecord]) -> [ExcuseCount] {
        Dictionary(grouping: failures, by: \.reason)
            .map { ExcuseCount(reason: $0.key, count: $0.value.count,
                               highValue: $0.value.filter { $0.category.isHighValue }.count) }
            .sorted { $0.count > $1.count }
    }

    /// Consecutive days on which every task was done. Days without tasks are skipped.
    static func perfectDayStreak(_ tasks: [TaskItem], now: Date = .now) -> Int {
        let byDay = Dictionary(grouping: tasks.filter { !$0.isRecovery }) { $0.scheduledDate.startOfDay }
        guard let earliest = byDay.keys.min() else { return 0 }
        let today = now.startOfDay
        var streak = 0
        if let todays = byDay[today], todays.allSatisfy(\.isDone) { streak += 1 }
        var day = today.addingDays(-1)
        while day >= earliest {
            if let group = byDay[day] {
                guard group.allSatisfy(\.isDone) else { break }
                streak += 1
            }
            day = day.addingDays(-1)
        }
        return streak
    }

    /// Consecutive finished weeks with Promises Kept ≥ 80%. A week without a commitment breaks it.
    static func weeklyPromiseStreak(_ tasks: [TaskItem], now: Date = .now) -> Int {
        let byWeek = Dictionary(grouping: tasks) { $0.scheduledDate.weekStart }
        var streak = 0
        var week = now.weekStart.addingDays(-7)
        while streak < maxStreakWeeks,
              let kept = ScoreEngine.promisesKept(byWeek[week] ?? [], now: now), kept >= promiseStreakThreshold {
            streak += 1
            week = week.addingDays(-7)
        }
        return streak
    }

    // MARK: Planned vs actual

    struct EffortWeek: Identifiable {
        let weekStart: Date
        let plannedMinutes: Int
        let focusedMinutes: Int
        var id: Date { weekStart }
    }

    /// Planned task time vs. time actually spent in the focus timer, for the last `weeks` weeks.
    static func effort(tasks: [TaskItem], sessions: [FocusSession], weeks: Int, now: Date = .now) -> [EffortWeek] {
        (0..<weeks).reversed().map { offset in
            let week = now.weekStart.addingDays(-7 * offset)
            let planned = tasks.filter { !$0.isRemoved && $0.scheduledDate.weekStart == week }
                .reduce(0) { $0 + $1.plannedMinutes }
            let focused = sessions.filter { $0.startedAt.weekStart == week }
                .reduce(0.0) { $0 + $1.active(at: now) }
            return EffortWeek(weekStart: week, plannedMinutes: planned, focusedMinutes: Int(focused / 60))
        }
    }

    // MARK: Personal records

    struct Record: Identifiable {
        let label: String
        let value: String
        let detail: String
        var id: String { label }
    }

    private static let minimumDayTasks = 2
    private static let minimumWeekTasks = 3
    private static let minimumMonthTasks = 5

    static func records(tasks: [TaskItem], sessions: [FocusSession], now: Date = .now) -> [Record] {
        let closed = tasks.filter { $0.isClosed(now) }
        let byDay = Dictionary(grouping: closed) { $0.scheduledDate.startOfDay }
        let byWeek = Dictionary(grouping: closed) { $0.scheduledDate.weekStart }
        let byMonth = Dictionary(grouping: closed) {
            Calendar.app.dateInterval(of: .month, for: $0.scheduledDate)?.start ?? $0.scheduledDate
        }
        var records: [Record] = []

        func best(_ groups: [Date: [TaskItem]], minimum: Int, score: ([TaskItem]) -> Double?) -> (date: Date, value: Double)? {
            groups.compactMap { date, group -> (Date, Double)? in
                guard group.count >= minimum, let value = score(group) else { return nil }
                return (date, value)
            }.max { $0.1 < $1.1 }.map { (date: $0.0, value: $0.1) }
        }
        func weekText(_ week: Date) -> String { "Týden \(week.weekNumber) · od \(week.dayMonthText)" }

        if let day = best(byDay, minimum: minimumDayTasks, score: { ScoreEngine.productivity($0, now: now) }) {
            records.append(Record(label: "Nejproduktivnější den", value: day.value.percentText, detail: day.date.longDayText))
        }
        if let most = byDay.map({ (date: $0.key, done: $0.value.filter(\.isDone).count) }).max(by: { $0.done < $1.done }),
           most.done > 0 {
            records.append(Record(label: "Nejvíc splněných úkolů za den", value: "\(most.done)", detail: most.date.longDayText))
        }
        if let week = best(byWeek, minimum: minimumWeekTasks, score: { ScoreEngine.productivity($0, now: now) }) {
            records.append(Record(label: "Nejproduktivnější týden", value: week.value.percentText, detail: weekText(week.date)))
        }
        if let week = best(byWeek, minimum: minimumWeekTasks, score: { ScoreEngine.promisesKept($0, now: now) }) {
            records.append(Record(label: "Nejlepší týden slibů", value: week.value.percentText, detail: weekText(week.date)))
        }
        if let month = best(byMonth, minimum: minimumMonthTasks, score: { ScoreEngine.productivity($0, now: now) }) {
            let name = month.date.formatted(Date.FormatStyle(locale: .app).month(.wide).year()).capitalizedFirst
            records.append(Record(label: "Nejproduktivnější měsíc", value: month.value.percentText, detail: name))
        }

        let days = byDay.keys.sorted()
        let strong = longestRun(days) { (ScoreEngine.productivity(byDay[$0] ?? [], now: now) ?? 0) >= ScoreEngine.Config.streakThreshold }
        if strong > 0 {
            records.append(Record(label: "Nejdelší série dní nad 80 %", value: String.days(strong), detail: "Dny bez úkolů sérii nepřeruší"))
        }
        let perfect = longestRun(days) { (byDay[$0] ?? []).filter { !$0.isRecovery }.allSatisfy(\.isDone) }
        if perfect > 0 {
            records.append(Record(label: "Nejdelší perfektní série", value: String.days(perfect), detail: "Všechny úkoly dne splněné"))
        }

        let focusByDay = Dictionary(grouping: sessions) { $0.startedAt.startOfDay }
            .mapValues { $0.reduce(0.0) { $0 + $1.active(at: now) } }
        if let focus = focusByDay.max(by: { $0.value < $1.value }), focus.value >= 60 {
            let minutes = Int(focus.value / 60)
            records.append(Record(label: "Nejvíc soustředění za den", value: "\(minutes / 60) h \(minutes % 60) min",
                                  detail: focus.key.longDayText))
        }
        return records
    }

    /// Longest stretch of consecutive listed days that all satisfy the condition.
    private static func longestRun(_ days: [Date], where condition: (Date) -> Bool) -> Int {
        var longest = 0
        var current = 0
        for day in days {
            current = condition(day) ? current + 1 : 0
            longest = max(longest, current)
        }
        return longest
    }
}
