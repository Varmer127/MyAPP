import SwiftUI
import SwiftData

/// Pull a screen down to bring it up to date: Health is read again, plans whose hour ran out are sealed,
/// the notifications are planned again from the data and the widget is told. The numbers on screen come from
/// the local data, which is always current, so what this really refreshes are the outside sources and the plans.
struct DataRefresh: ViewModifier {
    @Environment(\.modelContext) private var context
    @Query private var settingsList: [UserSettings]
    /// Anything the screen itself has to reload, such as the calendar.
    var extra: () async -> Void = {}

    func body(content: Content) -> some View {
        content.refreshable {
            let settings = settingsList.first
            if settings?.healthEnabled == true {
                _ = await HealthService.summary(force: true)
            }
            let plans = (try? context.fetch(FetchDescriptor<WeeklyPlan>())) ?? []
            PlanService.sealDue(plans, minimum: settings?.minimumWeeklyTasks ?? UserSettings.defaultMinimumWeeklyTasks)
            Persistence.save(context)
            await extra()
            let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
            WidgetBridge.update(tasks: tasks, plans: plans, targets: settings?.weeklyTargets ?? [:])
            await NotificationManager.reschedule(context: context)
            // Long enough to see that something happened.
            try? await Task.sleep(for: .milliseconds(350))
        }
    }
}

extension View {
    func refreshesData(extra: @escaping () async -> Void = {}) -> some View {
        modifier(DataRefresh(extra: extra))
    }
}
