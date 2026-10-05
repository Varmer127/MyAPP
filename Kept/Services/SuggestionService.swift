import Foundation

/// Progress of one category towards its weekly target.
struct WeeklyGoal: Identifiable {
    let category: TaskCategory
    let target: Int
    let done: Int
    /// Open tasks still scheduled this week (today included).
    let planned: Int

    var id: String { category.rawValue }
    var isMet: Bool { done >= target }
}

struct Suggestion: Identifiable {
    let goal: WeeklyGoal
    let daysLeft: Int
    /// Skipping today makes the weekly target unreachable.
    let isUrgent: Bool
    /// Extra advice, e.g. which gym workout is due.
    let hint: String?

    var id: String { goal.id }
    var category: TaskCategory { goal.category }

    var reason: String {
        let progress = "Tento týden \(goal.done) / \(goal.target)."
        if isUrgent { return "\(progress) Dnes musíš, jinak týdenní cíl nesplníš." }
        return "\(progress) Do konce týdne: \(String.days(daysLeft))."
    }
}

/// Turns weekly targets ("gym 4× a week") into progress and into suggestions for today.
enum SuggestionService {
    private static let maxShown = 3
    private static let daysInWeek = 7

    static func goals(tasks: [TaskItem], weekStart: Date, now: Date = .now,
                      target: (TaskCategory) -> Int) -> [WeeklyGoal] {
        let today = now.startOfDay
        let week = tasks.filter { !$0.isRemoved && $0.scheduledDate.weekStart == weekStart }
        return TaskCategory.allCases.compactMap { category in
            let goal = target(category)
            guard goal > 0 else { return nil }
            let inCategory = week.filter { $0.category == category }
            return WeeklyGoal(
                category: category,
                target: goal,
                done: inCategory.filter(\.isDone).count,
                planned: inCategory.filter { $0.status == .pending && $0.scheduledDate >= today }.count)
        }
    }

    /// A category is suggested when its target is not covered by done + planned tasks,
    /// nothing in it is scheduled today, and the week's pace says it is due.
    static func suggestions(tasks: [TaskItem], workoutPresets: [String], now: Date = .now,
                            target: (TaskCategory) -> Int) -> [Suggestion] {
        let today = now.startOfDay
        let dayIndex = (Calendar.app.dateComponents([.day], from: now.weekStart, to: today).day ?? 0) + 1
        let daysLeft = daysInWeek - dayIndex + 1

        let ranked: [(suggestion: Suggestion, pressure: Double)] =
            goals(tasks: tasks, weekStart: now.weekStart, now: now, target: target).compactMap { goal in
                let hasToday = tasks.contains {
                    !$0.isRemoved && $0.category == goal.category && $0.scheduledDate.isSameDay(as: today)
                }
                let needed = goal.target - goal.done - goal.planned
                guard needed > 0, !hasToday else { return nil }

                // Even pace through the week: 4× a week means 1 by Monday, 2 by Wednesday, 3 by Friday.
                let expectedByToday = Int((Double(goal.target) * Double(dayIndex) / Double(daysInWeek)).rounded())
                let isUrgent = needed >= daysLeft
                guard isUrgent || goal.done < expectedByToday else { return nil }

                let hint = goal.category == .gym ? workoutHint(tasks: tasks, presets: workoutPresets) : nil
                return (Suggestion(goal: goal, daysLeft: daysLeft, isUrgent: isUrgent, hint: hint),
                        Double(needed) / Double(daysLeft))
            }
        return ranked.sorted { $0.pressure > $1.pressure }.prefix(maxShown).map(\.suggestion)
    }

    /// The preset that has gone longest without being trained.
    private static func workoutHint(tasks: [TaskItem], presets: [String]) -> String? {
        guard !presets.isEmpty else { return nil }
        let logged = tasks.filter { $0.isDone && !$0.workoutType.isEmpty }
        let lastTrained = Dictionary(grouping: logged, by: \.workoutType)
            .mapValues { $0.map { $0.completedAt ?? $0.scheduledDate }.max() ?? .distantPast }
        let next = presets.min { (lastTrained[$0] ?? .distantPast) < (lastTrained[$1] ?? .distantPast) }
        return next.map { "Na řadě: \($0)" }
    }
}
