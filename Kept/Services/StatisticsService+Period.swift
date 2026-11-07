import Foundation

/// Aggregations for the period switch in Stats (today, week, month, year).
extension StatisticsService {
    /// After a day under the streak bar, how many days on average until the next day at or above it.
    /// Nil when there was no bad day followed by a good one.
    static func averageRecovery(tasks: [TaskItem], in range: Range<Date>, now: Date = .now) -> Double? {
        let start = range.lowerBound.startOfDay
        let end = min(range.upperBound, now.startOfDay)
        let days = max(0, Calendar.app.dateComponents([.day], from: start, to: end).day ?? 0)
        guard days > 1 else { return nil }
        let closed = tasks.filter { $0.isClosed(now) && $0.countsInScores && !$0.isRecovery }
        let scores = dailyScores(tasks: closed, from: start, days: days, now: now)
            .compactMap { score in score.productivity.map { (day: score.day, value: $0) } }
        var gaps: [Int] = []
        var badDay: Date?
        for score in scores {
            if score.value < ScoreEngine.Config.streakThreshold {
                if badDay == nil { badDay = score.day }
            } else if let bad = badDay {
                gaps.append(Calendar.app.dateComponents([.day], from: bad, to: score.day).day ?? 1)
                badDay = nil
            }
        }
        guard !gaps.isEmpty else { return nil }
        return Double(gaps.reduce(0, +)) / Double(gaps.count)
    }

    /// Kept promises by the time of day they were done, in two-hour slots from midnight (12 slots).
    static func keptBySlot(_ tasks: [TaskItem]) -> [Int] {
        var slots = Array(repeating: 0, count: 12)
        for task in tasks where task.isDone {
            guard let done = task.completedAt else { continue }
            slots[min(Calendar.app.component(.hour, from: done) / 2, 11)] += 1
        }
        return slots
    }

    private static let minimumWeekdayTasks = 3

    /// The weekday with the highest share of kept promises, among days with enough of them.
    static func strongestWeekday(_ tasks: [TaskItem], now: Date = .now) -> (weekday: Int, rate: Double)? {
        let closed = tasks.filter { $0.isClosed(now) && $0.countsInScores && !$0.isRecovery }
        let byWeekday = Dictionary(grouping: closed) { Calendar.app.component(.weekday, from: $0.scheduledDate) }
        return byWeekday
            .filter { $0.value.count >= minimumWeekdayTasks }
            .map { (weekday: $0.key, rate: Double($0.value.filter(\.isDone).count) / Double($0.value.count)) }
            .max { $0.rate < $1.rate }
    }

    /// Seconds spent in the focus timer within the range.
    static func focusSeconds(_ sessions: [FocusSession], in range: Range<Date>, now: Date = .now) -> Double {
        sessions.filter { range.contains($0.startedAt) }.reduce(0) { $0 + $1.active(at: now) }
    }

    /// Productivity of each month of a year, oldest first. Months without closed tasks, or still to come, are nil.
    static func monthlyScores(tasks: [TaskItem], year: Int, now: Date = .now) -> [(month: Date, value: Double?)] {
        (1...12).compactMap { month -> (month: Date, value: Double?)? in
            guard let start = Calendar.app.date(from: DateComponents(year: year, month: month, day: 1)),
                  let end = Calendar.app.date(byAdding: .month, value: 1, to: start) else { return nil }
            guard start <= now else { return (start, nil) }
            let inMonth = tasks.filter { $0.scheduledDate >= start && $0.scheduledDate < end && $0.isClosed(now) && $0.countsInScores }
            return (start, inMonth.isEmpty ? nil : ScoreEngine.productivity(inMonth, now: now))
        }
    }

    /// Days in the range that reached the streak bar, out of the days that had anything to judge.
    static func keptDays(tasks: [TaskItem], from: Date, days: Int, now: Date = .now) -> (kept: Int, judged: Int) {
        let scores = dailyScores(tasks: tasks.filter { $0.countsInScores && !$0.isRecovery }, from: from, days: days, now: now)
            .compactMap(\.productivity)
        return (scores.filter { $0 >= ScoreEngine.Config.streakThreshold }.count, scores.count)
    }

    /// The category done most often so far, and how many times. Habits form over weeks of repeating.
    static func habitInProgress(_ tasks: [TaskItem]) -> (category: TaskCategory, count: Int)? {
        Dictionary(grouping: tasks.filter { $0.isDone && !$0.isRecovery }, by: \.category)
            .map { (category: $0.key, count: $0.value.count) }
            .max { $0.count < $1.count }
    }
}
