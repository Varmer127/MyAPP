import ActivityKit
import Foundation

/// Data of the focus timer's Live Activity (lock screen and Dynamic Island).
/// Shared by the app, which starts and updates it, and the widget extension, which draws it.
struct FocusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// When the planned time runs out. In the past once the session is in overtime.
        var endDate: Date
        var isPaused: Bool
        /// Time left at the moment of pausing; negative in overtime. Only shown while paused.
        var remainingSeconds: Double
    }

    var title: String
    var plannedMinutes: Int
    /// The task has a deadline, so running over the planned time is shown as falling behind.
    var hasDeadline: Bool = false
}
