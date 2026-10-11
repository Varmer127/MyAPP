import ActivityKit
import Foundation

/// Mirrors the hour before a weekly plan is sealed into a Live Activity on the lock screen and in the Dynamic Island.
enum SealActivityManager {
    private typealias SealActivity = Activity<SealActivityAttributes>

    /// Shows the countdown of the plan that is sealed next, keeps its numbers current and removes it
    /// once nothing is waiting any more (sealed or withdrawn).
    static func reconcile(_ plans: [WeeklyPlan], now: Date = .now) {
        let waiting = plans.filter { ($0.sealDate ?? .distantPast) > now }.min { ($0.sealDate ?? now) < ($1.sealDate ?? now) }
        guard let plan = waiting, let sealDate = plan.sealDate else {
            for activity in SealActivity.activities {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = SealActivityAttributes.ContentState(sealDate: sealDate, commitments: plan.committableTasks.count)
        // Nothing can update it while the app is closed; going stale at the seal time lets the widget show "sealed".
        let content = ActivityContent(state: state, staleDate: sealDate)
        if let activity = SealActivity.activities.first {
            guard activity.content.state != state else { return }
            Task { await activity.update(content) }
        } else {
            _ = try? SealActivity.request(attributes: SealActivityAttributes(weekNumber: plan.weekStart.weekNumber),
                                          content: content, pushType: nil)
        }
    }
}
