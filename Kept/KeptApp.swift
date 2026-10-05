import SwiftUI
import SwiftData
import UserNotifications

@main
struct KeptApp: App {
    init() {
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .environment(\.locale, .app)
        }
        .modelContainer(for: [
            TaskItem.self,
            WeeklyPlan.self,
            CommitmentEdit.self,
            FailureRecord.self,
            FocusSession.self,
            UserSettings.self,
        ])
    }
}
