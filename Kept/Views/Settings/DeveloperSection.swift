// DEVELOPER VERSION ONLY — remove this file and its use in SettingsView before real testing.
// Listed in docs/APP_STORE_CHECKLIST.md. Built only into Debug builds (Xcode → phone), never into Release.
#if DEBUG
import SwiftUI
import SwiftData

/// Wipes every plan from today on without any penalty, to start planning again from scratch while developing.
struct DeveloperSection: View {
    @Environment(\.modelContext) private var context
    @Query private var tasks: [TaskItem]
    @Query private var plans: [WeeklyPlan]
    @State private var confirms = false

    /// Still-open tasks from today on. Anything already done, skipped or failed stays as history.
    private var futureTasks: [TaskItem] {
        let today = Date.now.startOfDay
        return tasks.filter { $0.scheduledDate >= today && $0.status == .pending }
    }

    var body: some View {
        Section {
            Button("Zrušit všechny plány do budoucna", role: .destructive) { confirms = true }
                .foregroundStyle(Theme.red)
                .disabled(futureTasks.isEmpty && !plans.contains { $0.weekStart > Date.now.weekStart || $0.isSealing })
        } header: {
            Text("Vývojář")
        } footer: {
            Text("DEVELOPER VERZE: před testováním se tohle tlačítko musí odstranit. Smaže všechny otevřené úkoly od dneška dál a plánovače budoucích týdnů, bez postihu a bez záznamu. Splněné úkoly a historie zůstávají.")
                .foregroundStyle(Theme.orange)
        }
        .listRowBackground(Theme.card)
        .alert("Zrušit všechny plány do budoucna?", isPresented: $confirms) {
            Button("Zrušit plány", role: .destructive, action: wipe)
            Button("Nechat", role: .cancel) {}
        } message: {
            Text("Smaže se otevřených úkolů: \(futureTasks.count). Nejde to vrátit.")
        }
    }

    private func wipe() {
        for task in futureTasks {
            task.finishFocusSessions()
            context.delete(task)
        }
        let thisWeek = Date.now.weekStart
        for plan in plans {
            if plan.weekStart > thisWeek {
                context.delete(plan)
            } else if plan.isSealing {
                PlanService.withdraw(plan)
            }
        }
        try? context.save()
    }
}
#endif
