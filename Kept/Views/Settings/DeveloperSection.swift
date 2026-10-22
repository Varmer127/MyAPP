// DEVELOPER VERSION ONLY — remove this file and its use in SettingsView before real testing.
// Listed in docs/APP_STORE_CHECKLIST.md. Built only into Debug builds (Xcode → phone), never into Release.
#if DEBUG
import SwiftUI
import SwiftData
import UserNotifications

/// Wipes every plan from today on without any penalty, to start planning again from scratch while developing.
struct DeveloperSection: View {
    @Environment(\.modelContext) private var context
    @Query private var tasks: [TaskItem]
    @Query private var plans: [WeeklyPlan]
    @AppStorage("devShowMorning") private var showMorning = false
    @AppStorage("devShowSeal") private var showSeal = false
    @AppStorage("devShowStory") private var showStory = false
    @AppStorage("devShowDayKept") private var showDayKept = false
    @AppStorage("devShowEvening") private var showEvening = false
    @AppStorage("devHealthDemo") private var healthDemo = false
    @AppStorage("devUpcomingStyle") private var upcomingStyle = 0
    @State private var confirms = false
    @State private var confirmsReset = false

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
            Button("Ukázat ranní okamžik") {
                showMorning = true
            }
            .foregroundStyle(Theme.textPrimary)
            Button("Ukázat razítko zapečetění") {
                showSeal = true
            }
            .foregroundStyle(Theme.textPrimary)
            Button("Ukázat týdenní příběh") {
                showStory = true
            }
            .foregroundStyle(Theme.textPrimary)
            Button("Ukázat „Den dodržen“") {
                showDayKept = true
            }
            .foregroundStyle(Theme.textPrimary)
            Button("Ukázat večerní uzavření dne") {
                showEvening = true
            }
            .foregroundStyle(Theme.textPrimary)
            Picker("Další úkoly na Dnes", selection: $upcomingStyle) {
                Text("Boxy").tag(0)
                Text("Rozbalení").tag(1)
            }
            Toggle("Zdraví s ukázkovými daty", isOn: $healthDemo)
                .tint(Theme.textSecondary)
                .onChange(of: healthDemo) { _, on in
                    // The tab is optional, so the test turns it on.
                    if on { UserSettings.current(in: context).showsHealthTab = true }
                }
            Button("Spustit onboarding znovu") {
                UserSettings.current(in: context).onboardedAt = nil
            }
            .foregroundStyle(Theme.textPrimary)
            Button("Smazat všechna data a začít znovu", role: .destructive) { confirmsReset = true }
                .foregroundStyle(Theme.red)
        } header: {
            Text("Vývojář")
        } footer: {
            Text("DEVELOPER VERZE: před testováním se tahle tlačítka musí odstranit. „Spustit onboarding znovu“ ukáže průvodce prvního spuštění; data zůstanou, jen se volby z průvodce zapíšou do Nastavení. „Zrušit plány“ smaže otevřené úkoly od dneška dál a plánovače budoucích týdnů, bez postihu; historie zůstává. „Smazat všechna data“ smaže úplně všechno: úkoly, historii, body, deník, nastavení i widget, jako by se aplikace právě nainstalovala.")
                .foregroundStyle(Theme.orange)
        }
        .listRowBackground(Theme.card)
        .alert("Smazat všechna data?", isPresented: $confirmsReset) {
            Button("Smazat všechno", role: .destructive, action: resetEverything)
            Button("Nechat", role: .cancel) {}
        } message: {
            Text("Aplikace bude jako po nové instalaci. Nejde to vrátit.")
        }
        .alert("Zrušit všechny plány do budoucna?", isPresented: $confirms) {
            Button("Zrušit plány", role: .destructive, action: wipe)
            Button("Nechat", role: .cancel) {}
        } message: {
            Text("Smaže se otevřených úkolů: \(futureTasks.count). Nejde to vrátit.")
        }
    }

    /// Everything the app ever stored, as if it had just been installed.
    private func resetEverything() {
        try? context.delete(model: TaskItem.self)
        try? context.delete(model: WeeklyPlan.self)
        try? context.delete(model: CommitmentEdit.self)
        try? context.delete(model: FailureRecord.self)
        try? context.delete(model: FocusSession.self)
        try? context.delete(model: SetLog.self)
        try? context.delete(model: BodyEntry.self)
        PhotoVault.deleteAll()
        ActivityIcons.shared.reset()
        try? context.delete(model: ExerciseLog.self)
        try? context.delete(model: Postponement.self)
        try? context.delete(model: WeekReflection.self)
        try? context.delete(model: PointsPurchase.self)
        try? context.delete(model: DiaryEntry.self)
        try? context.delete(model: FutureLetter.self)
        try? context.delete(model: UserSettings.self)
        try? context.save()
        _ = UserSettings.current(in: context)
        try? context.save()
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
        UserDefaults(suiteName: WidgetSnapshot.appGroup)?.removePersistentDomain(forName: WidgetSnapshot.appGroup)
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        FocusActivityManager.end()
        SealActivityManager.reconcile([])
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
