import ActivityKit
import Foundation

/// Mirrors the running focus session into a Live Activity, so the timer is visible
/// on the lock screen and in the Dynamic Island while the app is in the background.
enum FocusActivityManager {
    private typealias FocusActivity = Activity<FocusActivityAttributes>

    /// Starts the Live Activity for a session, or brings an existing one up to date (pause, resume).
    static func sync(_ session: FocusSession, title: String, now: Date = .now) {
        WidgetBridge.setFocus(session, title: title, now: now)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let remaining = session.remaining(at: now)
        let endDate = now.addingTimeInterval(remaining)
        let state = FocusActivityAttributes.ContentState(
            endDate: endDate, isPaused: session.isPaused, remainingSeconds: remaining)
        // Going stale at the planned end lets the widget switch its label to "overtime".
        let content = ActivityContent(state: state, staleDate: !session.isPaused && remaining > 0 ? endDate : nil)

        if let activity = FocusActivity.activities.first {
            Task { await activity.update(content) }
        } else {
            let attributes = FocusActivityAttributes(title: title, plannedMinutes: session.plannedMinutes,
                                                     hasDeadline: session.task?.deadline != nil)
            _ = try? FocusActivity.request(attributes: attributes, content: content, pushType: nil)
        }
    }

    static func end() {
        WidgetBridge.setFocus(nil, title: "")
        for activity in FocusActivity.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// Removes a leftover Live Activity when no open task has a session running any more
    /// (for example after the task was skipped or removed).
    /// Returns whether a focus session is still running.
    @discardableResult
    static func reconcile(_ tasks: [TaskItem]) -> Bool {
        let isFocusing = tasks.contains { $0.status == .pending && !$0.isRemoved && $0.activeFocusSession != nil }
        if !isFocusing {
            end()
        }
        return isFocusing
    }
}
