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
}
