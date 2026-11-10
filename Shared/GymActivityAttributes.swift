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
        /// The workout time frozen while the clock is stopped; nil while it runs.
        var heldTotal: Double?
    }
}

/// Stops or restarts the workout's clock from the lock screen or the Dynamic Island,
/// for a break that is neither training nor rest. Performed in the app's process.
struct GymHoldIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Zastavit čas tréninku"
    static var isDiscoverable = false

    @Parameter(title: "Zastavit")
    var hold: Bool

    init() {}

    init(hold: Bool) {
        self.hold = hold
    }

    func perform() async throws -> some IntentResult {
        await WidgetActions.gymHold?(hold)
        return .result()
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
