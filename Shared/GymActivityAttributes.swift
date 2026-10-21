import ActivityKit
import AppIntents
import Foundation

/// Data of the gym stopwatch's Live Activity (lock screen and Dynamic Island).
/// The workout time counts up from `startDate`; a rest counts down from `restStart` to `restEnd`.
struct GymActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
        var restStart: Date?
        var restEnd: Date?
        /// The rest length chosen in the app, used when a rest is started from the lock screen.
        var restName: String
        var restSeconds: Int
        var workout: String
    }
}

/// Starts or ends a rest from the lock screen, the Dynamic Island or the gym widget.
/// Performed in the app's process, where the workout lives.
struct GymRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pauza v tréninku"
    static var isDiscoverable = false

    @Parameter(title: "Začít pauzu")
    var start: Bool

    init() {}

    init(start: Bool) {
        self.start = start
    }

    func perform() async throws -> some IntentResult {
        await WidgetActions.gymRest?(start)
        return .result()
    }
}
