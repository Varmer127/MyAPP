import SwiftUI
import SwiftData

@main
struct KeptApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [
            TaskItem.self,
            WeeklyPlan.self,
            CommitmentEdit.self,
            FailureRecord.self,
            UserSettings.self,
        ])
    }
}
