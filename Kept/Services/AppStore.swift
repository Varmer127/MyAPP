import Foundation
import SwiftData

/// The one data store of the app, shared by the UI and by actions that arrive while no screen is open
/// (the widget's "done" button).
@MainActor
enum AppStore {
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: TaskItem.self, WeeklyPlan.self, CommitmentEdit.self, FailureRecord.self,
                                      FocusSession.self, ExerciseLog.self, Postponement.self, WeekReflection.self,
                                      PointsPurchase.self, DiaryEntry.self, FutureLetter.self, UserSettings.self)
        } catch {
            fatalError("Could not open the data store: \(error)")
        }
    }()

    /// Tasks the widget may complete with one tap: nothing that needs a proof photo or a workout log.
    nonisolated static func canCompleteFromWidget(_ task: TaskItem) -> Bool {
        task.status == .pending && !task.isRemoved && !task.requiresProof && task.category != .gym
    }

    static func completeFromWidget(_ id: String) async {
        let context = container.mainContext
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        guard let task = tasks.first(where: { $0.uid.uuidString == id }), canCompleteFromWidget(task) else { return }
        task.markDone()
        try? context.save()
        let plans = (try? context.fetch(FetchDescriptor<WeeklyPlan>())) ?? []
        if !FocusActivityManager.reconcile(tasks) {
            NotificationManager.cancelFocusEnd()
        }
        WidgetBridge.update(tasks: tasks, plans: plans)
        await NotificationManager.reschedule(context: context)
    }
}
