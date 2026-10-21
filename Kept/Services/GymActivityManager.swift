import ActivityKit
import Foundation
import SwiftData

/// Mirrors the running gym workout to the lock screen, the Dynamic Island and the gym widget,
/// and handles the rest button pressed there.
@MainActor
enum GymActivityManager {
    private typealias GymActivity = Activity<GymActivityAttributes>

    /// Brings the stopwatch outside the app up to date with the workout and the chosen rest.
    static func sync(task: TaskItem, rest: RestPreset, now: Date = .now) {
        guard let session = task.activeFocusSession else { return end() }
        let restEnd = session.pausedSince.map { $0.addingTimeInterval(TimeInterval(rest.seconds)) }
        let workout = task.workoutType.isEmpty ? task.title : task.workoutType
        WidgetBridge.setGym(WidgetSnapshot.Gym(startDate: session.startedAt, restStart: session.pausedSince,
                                               restEnd: restEnd, restSeconds: rest.seconds, workout: workout))
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = GymActivityAttributes.ContentState(startDate: session.startedAt, restStart: session.pausedSince,
                                                       restEnd: restEnd, restName: rest.name,
                                                       restSeconds: rest.seconds, workout: workout)
        // Going stale when the rest is over switches the label to "next set".
        let content = ActivityContent(state: state, staleDate: restEnd.flatMap { $0 > now ? $0 : nil })
        if let activity = GymActivity.activities.first {
            Task { await activity.update(content) }
        } else {
            _ = try? GymActivity.request(attributes: GymActivityAttributes(), content: content, pushType: nil)
        }
    }

    static func end() {
        WidgetBridge.setGym(nil)
        for activity in GymActivity.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// Removes the stopwatch once no workout is running any more.
    static func reconcile(_ tasks: [TaskItem]) {
        if runningWorkout(in: tasks) == nil, !GymActivity.activities.isEmpty || WidgetSnapshot.load()?.gym != nil {
            end()
        }
    }

    /// The rest button on the lock screen or in the widget, performed in the app's process.
    static func toggleRest(start: Bool) async {
        let context = AppStore.container.mainContext
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        guard let task = runningWorkout(in: tasks), let session = task.activeFocusSession else { return end() }
        let rest = currentRest(in: context)
        if start {
            if session.isPaused { session.resume() }
            session.pause()
            await NotificationManager.scheduleRestEnd(in: TimeInterval(rest.seconds))
        } else if session.isPaused {
            session.resume()
            NotificationManager.cancelRestEnd()
        }
        sync(task: task, rest: rest)
    }

    private static func runningWorkout(in tasks: [TaskItem]) -> TaskItem? {
        tasks.first { $0.category == .gym && $0.status == .pending && !$0.isRemoved && $0.activeFocusSession != nil }
    }

    /// The rest length last chosen in the workout, or the default one.
    private static func currentRest(in context: ModelContext) -> RestPreset {
        let presets = UserSettings.current(in: context).restPresets
        if let state = GymActivity.activities.first?.content.state,
           let preset = presets.first(where: { $0.name == state.restName }) {
            return preset
        }
        if let seconds = WidgetSnapshot.load()?.gym?.restSeconds,
           let preset = presets.first(where: { $0.seconds == seconds }) {
            return preset
        }
        return presets.first ?? RestPreset.defaults[0]
    }
}
