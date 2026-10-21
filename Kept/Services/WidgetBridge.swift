import Foundation
import WidgetKit

/// Publishes today's numbers and the running focus timer to the widgets.
enum WidgetBridge {
    static func update(tasks: [TaskItem], plans: [WeeklyPlan], targets: [TaskCategory: Int], now: Date = .now) {
        let today = tasks.filter { $0.scheduledDate.isSameDay(as: now) && !$0.isRemoved }
        let next = today.filter { $0.status == .pending }
            .sorted { $0.dueDate == $1.dueDate ? $0.priority.rank > $1.priority.rank : $0.dueDate < $1.dueDate }
            .first
        // The gym stopwatch counts up and has no planned end, so it is not shown as a focus countdown.
        let focusing = tasks.first {
            $0.status == .pending && !$0.isRemoved && $0.category != .gym && $0.activeFocusSession != nil
        }
        let weekStart = now.weekStart
        let week = (0..<7).map { offset -> WidgetSnapshot.Day in
            let date = weekStart.addingDays(offset)
            let day = tasks.filter { $0.scheduledDate.isSameDay(as: date) && !$0.isRemoved }
            return WidgetSnapshot.Day(date: date, done: day.filter(\.isDone).count, total: day.count)
        }
        let workouts = tasks.filter { $0.category == .gym && $0.isDone }
        let gymRunning = tasks.contains { $0.category == .gym && $0.status == .pending && !$0.isRemoved && $0.activeFocusSession != nil }
        WidgetSnapshot(
            day: now.startOfDay,
            score: ScoreEngine.accountability(tasks: tasks, plans: plans, targets: targets, now: now)?.score ?? ScoreEngine.startingScore,
            done: today.filter(\.isDone).count,
            total: today.count,
            streak: ScoreEngine.dayStreak(tasks, now: now),
            promisesKept: ScoreEngine.promisesKept(tasks.filter { $0.scheduledDate.weekStart == now.weekStart }, now: now),
            nextTitle: next?.title,
            nextCompletableID: next.flatMap { AppStore.canCompleteFromWidget($0) ? $0.uid.uuidString : nil },
            focus: focusing.flatMap { task in task.activeFocusSession.map { focus($0, title: task.title, now: now) } },
            // The running workout is written by the gym stopwatch; here it is only kept or cleared.
            gym: gymRunning ? WidgetSnapshot.load()?.gym : nil,
            nextIcon: next?.icon,
            week: week,
            gymThisWeek: workouts.filter { ($0.completedAt ?? $0.scheduledDate).weekStart == weekStart }.count,
            gymTarget: targets[.gym],
            lastGym: workouts.compactMap { $0.completedAt ?? $0.scheduledDate }.max()
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

    /// Updates only the running workout right away when it starts, rests or ends.
    static func setGym(_ gym: WidgetSnapshot.Gym?) {
        guard var snapshot = WidgetSnapshot.load() else { return }
        snapshot.gym = gym
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
