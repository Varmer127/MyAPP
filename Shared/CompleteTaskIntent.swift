import AppIntents

/// The "done" button of the home-screen widget.
/// As a `LiveActivityIntent` it is performed in the app's process, not in the widget's, so it can use
/// the app's data store and reschedule notifications. The app registers what it does in `WidgetActions`.
struct CompleteTaskIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Splnit úkol"
    static var isDiscoverable = false

    @Parameter(title: "Úkol")
    var taskID: String

    init() {}

    init(taskID: String) {
        self.taskID = taskID
    }

    func perform() async throws -> some IntentResult {
        await WidgetActions.complete?(taskID)
        return .result()
    }
}

enum WidgetActions {
    /// Set by the app at launch. Stays nil inside the widget extension.
    @MainActor static var complete: ((String) async -> Void)?
    /// Starts (true) or ends (false) a rest in the running workout.
    @MainActor static var gymRest: ((Bool) async -> Void)?
    /// Stops (true) or restarts (false) the running workout's clock.
    @MainActor static var gymHold: ((Bool) async -> Void)?
    /// Stops whatever timer is running, focus or workout, without completing the task.
    @MainActor static var stopTimer: (() async -> Void)?
    /// Pauses (true) or resumes (false) the running focus timer.
    @MainActor static var focusPause: ((Bool) async -> Void)?
}

/// Stops the running focus timer or workout from the lock screen or the Dynamic Island.
/// The task stays open and the time so far is kept, the same as STOP inside the app.
struct StopTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Zastavit časovač"
    static var isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        await WidgetActions.stopTimer?()
        return .result()
    }
}

/// Pauses or resumes the focus timer from the lock screen or the Dynamic Island.
struct FocusPauseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pozastavit focus"
    static var isDiscoverable = false

    @Parameter(title: "Pozastavit")
    var pause: Bool

    init() {}

    init(pause: Bool) {
        self.pause = pause
    }

    func perform() async throws -> some IntentResult {
        await WidgetActions.focusPause?(pause)
        return .result()
    }
}
