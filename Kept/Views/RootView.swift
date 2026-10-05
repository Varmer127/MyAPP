import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case today, week, stats, settings
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var router = NotificationRouter.shared
    @Query private var tasks: [TaskItem]
    @Query private var plans: [WeeklyPlan]
    @Query private var settingsList: [UserSettings]
    @State private var tab: AppTab = .today
    @State private var weekShowsNext = false
    @State private var showsRealityCheck = false

    /// Changes whenever something that scheduled notifications depend on changes.
    private var notificationSignature: Int {
        var hasher = Hasher()
        for task in tasks {
            hasher.combine(task.uid)
            hasher.combine(task.title)
            hasher.combine(task.statusRaw)
            hasher.combine(task.priorityRaw)
            hasher.combine(task.scheduledDate)
            hasher.combine(task.deadline)
            hasher.combine(task.plannedMinutes)
            hasher.combine(task.isRemoved)
        }
        for plan in plans {
            hasher.combine(plan.weekStart)
            hasher.combine(plan.committedAt)
        }
        hasher.combine(settingsList.first?.notificationSignature)
        return hasher.finalize()
    }

    var body: some View {
        TabView(selection: $tab) {
            TodayView(openWeek: { tab = .week })
                .tabItem { Label("Dnes", systemImage: "sun.max") }
                .tag(AppTab.today)
            WeekView(showsNextWeek: $weekShowsNext)
                .tabItem { Label("Týden", systemImage: "calendar") }
                .tag(AppTab.week)
            StatsView()
                .tabItem { Label("Statistiky", systemImage: "chart.bar") }
                .tag(AppTab.stats)
            SettingsView()
                .tabItem { Label("Nastavení", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(.white)
        .fullScreenCover(isPresented: $showsRealityCheck) { RealityCheckView() }
        .task {
            _ = UserSettings.current(in: context)
            await NotificationManager.requestAuthorization()
            await NotificationManager.reschedule(context: context)
        }
        // `task(id:)` cancels the previous run, so a burst of edits reschedules once.
        .task(id: notificationSignature) {
            await NotificationManager.reschedule(context: context)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await NotificationManager.reschedule(context: context) }
        }
        .onChange(of: router.route) { _, route in
            guard let route else { return }
            open(route)
            router.route = nil
        }
    }

    private func open(_ route: AppRoute) {
        switch route {
        case .today:
            tab = .today
        case .planning:
            weekShowsNext = true
            tab = .week
        case .realityCheck:
            tab = .today
            showsRealityCheck = true
        }
    }
}

/// Identifiable request to open the task editor for a new or existing task.
struct EditorRequest: Identifiable {
    let id = UUID()
    var task: TaskItem?
    var date: Date = .now
    /// Category to prefill a new task from (used by suggestions).
    var suggestion: TaskCategory?
    /// Creates the task as a recovery task (extra work after a bad day).
    var isRecovery = false
}

struct ExcuseRequest: Identifiable {
    let id = UUID()
    let task: TaskItem
    let kind: FailureKind
}
