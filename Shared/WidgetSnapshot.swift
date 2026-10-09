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

    var day: Date
    var score: Int?
    var done: Int
    var total: Int
    var streak: Int
    var promisesKept: Double?
    var nextTitle: String?
    var focus: Focus?

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
