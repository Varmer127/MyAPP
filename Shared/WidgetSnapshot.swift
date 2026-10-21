import Foundation

/// The few numbers the home-screen widget shows. The app writes them into the shared
/// App Group container whenever something changes; the widget only reads them.
struct WidgetSnapshot: Codable {
    /// The focus timer that is currently open, if any.
    struct Focus: Codable {
        var title: String
        /// When the planned time runs out. In the past once the session is in overtime.
        var endDate: Date
        var isPaused: Bool
        /// Time left at the moment of pausing; negative in overtime. Only shown while paused.
        var remainingSeconds: Double
        /// The task has a deadline, so running over the planned time is shown as falling behind.
        var hasDeadline: Bool?
    }

    /// The gym workout that is running, if any.
    struct Gym: Codable {
        var startDate: Date
        var restStart: Date?
        var restEnd: Date?
        var restSeconds: Int
        var workout: String
    }

    /// One day of the current week, Monday first.
    struct Day: Codable {
        var date: Date
        var done: Int
        var total: Int
    }

    var day: Date
    var score: Int?
    var done: Int
    var total: Int
    var streak: Int
    var promisesKept: Double?
    var nextTitle: String?
    /// The next task's identifier, when the widget may complete it with one tap.
    var nextCompletableID: String?
    var focus: Focus?
    var gym: Gym?
    /// Icon of the next task (SF Symbol name).
    var nextIcon: String?
    var week: [Day]?
    var gymThisWeek: Int?
    var gymTarget: Int?
    var lastGym: Date?

    static let appGroup = "group.cz.philipstryka.kept"
    private static let key = "widgetSnapshot"

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: WidgetSnapshot.appGroup)?.set(data, forKey: WidgetSnapshot.key)
    }
}
