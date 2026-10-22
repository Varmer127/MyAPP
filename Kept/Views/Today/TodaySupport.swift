import SwiftUI
import SwiftData


/// Everything the Today screen shows, derived once per render.
struct TodaySnapshot {
    let scored: [TaskItem]
    let visible: [TaskItem]
    let unresolved: [TaskItem]
    let critical: [TaskItem]
    let open: [TaskItem]
    let closed: [TaskItem]
    let accountability: ScoreEngine.Accountability?
    let promisesKept: Double?
    let productivity: Double?
    let streak: Int
    let weekIsCommitted: Bool

    var doneCount: Int { scored.filter(\.isDone).count }

    /// Before anything was ever closed there is nothing to measure yet, so the record shows as clean (100 %).
    func freshValue(_ value: Double?) -> String {
        value == nil && accountability == nil ? MetricTile.noData : value.percentText
    }
    var partialCount: Int { scored.filter(\.isPartial).count }

    init(tasks: [TaskItem], plans: [WeeklyPlan], targets: [TaskCategory: Int], now: Date) {
        let weekStart = now.weekStart
        scored = tasks.filter { $0.scheduledDate.isSameDay(as: now) && $0.countsInScores }
        visible = scored.filter { !$0.isRemoved }
        unresolved = tasks.filter { $0.isMissed(now) }.sorted { $0.scheduledDate > $1.scheduledDate }

        let pending = visible.filter { $0.status == .pending }.sorted {
            $0.dueDate == $1.dueDate ? $0.priority.rank > $1.priority.rank : $0.dueDate < $1.dueDate
        }
        critical = pending.filter { $0.priority == .critical }
        open = pending.filter { $0.priority != .critical }
        closed = visible.filter { $0.status != .pending }

        accountability = ScoreEngine.accountability(tasks: tasks, plans: plans, targets: targets, now: now)
        promisesKept = ScoreEngine.promisesKept(tasks.filter { $0.scheduledDate.weekStart == weekStart }, now: now)
        productivity = ScoreEngine.productivity(scored, now: now)
        streak = ScoreEngine.dayStreak(tasks, now: now)
        // A plan that is handed in and waiting to be sealed is as good as committed here.
        weekIsCommitted = plans.first { $0.weekStart == weekStart }.map { $0.isCommitted || $0.isSealing } ?? false
    }
}

/// Lets the story be used as the item of a full-screen cover.
struct StoryBox: Identifiable {
    let story: WeekStory
    var id: Date { story.weekStart }
}

