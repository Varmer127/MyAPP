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
}
