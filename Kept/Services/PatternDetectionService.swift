import Foundation

/// How the last attempts at "the same task" (matched by title) went.
struct TaskHistory {
    let failures: Int
    let attempts: Int
    let topReason: FailureReason?
}

/// Finds repeating behaviour in the history. A pattern is only reported with enough
/// occurrences behind it, so the app never draws conclusions from a single case.
enum PatternDetectionService {
    private static let recentAttempts = 6
    private static let minimumAttempts = 3
    private static let minimumFailures = 2
    private static let minimumSample = 3
    private static let categoryGap = 0.25
    private static let weakDayGap = 0.15
    private static let eveningStartMinutes = 19 * 60
    private static let maxInsights = 6

    static func history(of title: String, tasks: [TaskItem], failures: [FailureRecord], now: Date = .now) -> TaskHistory {
        let key = FailureRecord.key(for: title)
        let attempts = tasks
            .filter { FailureRecord.key(for: $0.title) == key && $0.isClosed(now) }
            .sorted { $0.scheduledDate > $1.scheduledDate }
            .prefix(recentAttempts)
        let reasons = Dictionary(grouping: failures.filter { $0.titleKey == key }, by: \.reason)
        return TaskHistory(
            failures: attempts.filter { $0.isLost(now) }.count,
            attempts: attempts.count,
            topReason: reasons.max { $0.value.count < $1.value.count }?.key)
    }

    /// Confronts the user when a task they keep failing is on today's list.
    static func warning(for task: TaskItem, tasks: [TaskItem], failures: [FailureRecord], now: Date = .now) -> String? {
        let history = history(of: task.title, tasks: tasks, failures: failures, now: now)
        guard history.attempts >= minimumAttempts, history.failures >= minimumFailures else { return nil }
        return "Z posledních \(history.attempts) pokusů jsi \(history.failures) nesplnil. Dnes ten vzorec můžeš přerušit."
    }

    /// Plain-language observations about the given tasks (already limited to a period by the caller).
    static func insights(tasks: [TaskItem], failures: [FailureRecord], plans: [WeeklyPlan], now: Date = .now) -> [String] {
        let closed = tasks.filter { $0.isClosed(now) && !$0.isRecovery }
        var insights: [String] = []

        if ScoreEngine.isBusyNotProductive(closed, now: now) {
            insights.append("Splnil jsi hodně úkolů, ale ne ty důležité. Aktivita není produktivita.")
        }
        insights += repeatedFailures(closed, failures: failures, now: now)
        if let contrast = categoryContrast(closed) { insights.append(contrast) }
        if let day = weakestWeekday(closed, now: now) { insights.append(day) }
        if let evening = eveningWeakness(closed, now: now) { insights.append(evening) }
        if let excuse = topExcuse(failures) { insights.append(excuse) }

        let late = closed.filter { $0.status == .completedLate && !$0.isRemoved }.count
        if late >= minimumSample {
            insights.append("Pozdě dokončené úkoly: \(late). Děláš je, ale až po termínu.")
        }
        let edits = plans.flatMap(\.edits)
        let removed = edits.filter { $0.kind == .removed }.count
        let moved = edits.filter { $0.kind == .moved }.count
        if removed > 0 {
            insights.append("Po zavázání jsi odstranil úkoly: \(removed). Každý z nich je porušený slib.")
        }
        if moved >= minimumSample {
            insights.append("Přesunuté úkoly po zavázání: \(moved). Odkládáš, co sis naplánoval.")
        }
        return Array(insights.prefix(maxInsights))
    }

    private static func repeatedFailures(_ closed: [TaskItem], failures: [FailureRecord], now: Date) -> [String] {
        Dictionary(grouping: closed) { FailureRecord.key(for: $0.title) }
            .compactMap { _, group -> (text: String, lost: Int)? in
                let lost = group.filter { $0.isLost(now) }.count
                guard group.count >= minimumAttempts, lost >= minimumFailures, lost * 2 >= group.count,
                      let title = group.first?.title else { return nil }
                var text = "„\(title)“: nesplněno \(lost) z \(group.count)."
                if let reason = history(of: title, tasks: closed, failures: failures, now: now).topReason {
                    text += " Nejčastější důvod: \(reason.title)."
                }
                return (text, lost)
            }
            .sorted { $0.lost > $1.lost }
            .prefix(2)
            .map(\.text)
    }

    private static func categoryContrast(_ closed: [TaskItem]) -> String? {
        let rates = StatisticsService.categoryPerformance(closed).filter { $0.count >= minimumSample }
        guard let best = rates.max(by: { $0.rate < $1.rate }), let worst = rates.min(by: { $0.rate < $1.rate }),
              best.rate - worst.rate >= categoryGap else { return nil }
        return "\(best.category.title) plníš na \(best.rate.percentText), \(worst.category.title) jen na \(worst.rate.percentText)."
    }

    private static func weakestWeekday(_ closed: [TaskItem], now: Date) -> String? {
        guard let overall = ScoreEngine.productivity(closed, now: now) else { return nil }
        let byWeekday = Dictionary(grouping: closed) { Calendar.app.component(.weekday, from: $0.scheduledDate) }
        let scored = byWeekday.compactMap { _, group -> (day: Date, score: Double)? in
            guard group.count >= minimumSample, let score = ScoreEngine.productivity(group, now: now),
                  let day = group.first?.scheduledDate else { return nil }
            return (day, score)
        }
        guard scored.count >= 2, let worst = scored.min(by: { $0.score < $1.score }),
              overall - worst.score >= weakDayGap else { return nil }
        return "Nejslabší den v týdnu: \(worst.day.weekdayText) (\(worst.score.percentText)). Kritické úkoly plánuj jinam."
    }

    private static func eveningWeakness(_ closed: [TaskItem], now: Date) -> String? {
        let withDeadline = closed.filter { $0.deadline != nil }
        let evening = withDeadline.filter { ($0.deadline?.minutesIntoDay ?? 0) >= eveningStartMinutes }
        let earlier = withDeadline.filter { ($0.deadline?.minutesIntoDay ?? 0) < eveningStartMinutes }
        guard evening.count >= minimumSample, earlier.count >= minimumSample,
              let eveningRate = ScoreEngine.completionRate(evening),
              let earlierRate = ScoreEngine.completionRate(earlier),
              earlierRate - eveningRate >= categoryGap else { return nil }
        return "Po 19:00 plníš jen \(eveningRate.percentText) úkolů, dřív během dne \(earlierRate.percentText)."
    }

    private static func topExcuse(_ failures: [FailureRecord]) -> String? {
        guard let top = StatisticsService.excuseCounts(failures).first, top.count >= minimumFailures else { return nil }
        var text = "Nejčastější výmluva: „\(top.reason.title)“ (\(top.count)×)."
        if top.highValue * 2 >= top.count, top.highValue > 0 {
            text += " Z toho \(top.highValue)× u toho nejdůležitějšího."
        }
        return text
    }
}
