import Foundation
import WidgetKit

/// Publishes today's numbers and the running focus timer to the widgets.
enum WidgetBridge {
    static func update(tasks: [TaskItem], plans: [WeeklyPlan], now: Date = .now) {
        let today = tasks.filter { $0.scheduledDate.isSameDay(as: now) && !$0.isRemoved }
        let next = today.filter { $0.status == .pending }
            .sorted { $0.dueDate == $1.dueDate ? $0.priority.rank > $1.priority.rank : $0.dueDate < $1.dueDate }
            .first
        // The gym stopwatch counts up and has no planned end, so it is not shown as a focus countdown.
        let focusing = tasks.first {
            $0.status == .pending && !$0.isRemoved && $0.category != .gym && $0.activeFocusSession != nil
        }
        WidgetSnapshot(
            day: now.startOfDay,
            score: ScoreEngine.accountability(tasks: tasks, plans: plans, now: now)?.score,
            done: today.filter(\.isDone).count,
            total: today.count,
            streak: ScoreEngine.dayStreak(tasks, now: now),
            promisesKept: ScoreEngine.promisesKept(tasks.filter { $0.scheduledDate.weekStart == now.weekStart }, now: now),
            nextTitle: next?.title,
            focus: focusing.flatMap { task in task.activeFocusSession.map { focus($0, title: task.title, now: now) } }
        ).save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Updates only the focus part right away when the timer starts, pauses, resumes or ends.
    static func setFocus(_ session: FocusSession?, title: String, now: Date = .now) {
        guard var snapshot = WidgetSnapshot.load() else { return }
        snapshot.focus = session.map { focus($0, title: title, now: now) }
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func focus(_ session: FocusSession, title: String, now: Date) -> WidgetSnapshot.Focus {
        let remaining = session.remaining(at: now)
        return WidgetSnapshot.Focus(title: title, endDate: now.addingTimeInterval(remaining),
                                    isPaused: session.isPaused, remainingSeconds: remaining,
                                    hasDeadline: session.task?.deadline != nil)
    }
}
