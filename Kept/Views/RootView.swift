import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case today, week, stats, gym, health, diary, settings
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var router = NotificationRouter.shared
    @Query private var tasks: [TaskItem]
    @Query private var plans: [WeeklyPlan]
    @Query private var settingsList: [UserSettings]
    @Query private var purchases: [PointsPurchase]
    @State private var tab: AppTab = .today
    @State private var weekShowsNext = false
    @State private var showsRealityCheck = false
    /// Existing installs from before the guide existed are not sent through it.
    @AppStorage("onboardingMigrated") private var onboardingMigrated = false
    /// Called once the data store is set up and the first screen can be used.
    var onReady: () -> Void = {}

    private var settings: UserSettings? { settingsList.first }

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
            hasher.combine(task.completionShare)
            hasher.combine(task.streakRepairDay)
        }
        for plan in plans {
            hasher.combine(plan.weekStart)
            hasher.combine(plan.committedAt)
            hasher.combine(plan.submittedAt)
        }
        for purchase in purchases {
            hasher.combine(purchase.date)
            hasher.combine(purchase.usedOn)
        }
        hasher.combine(settingsList.first?.notificationSignature)
        return hasher.finalize()
    }

    /// The next moment a handed-in plan is due to be sealed.
    private var nextSealDate: Date? { plans.compactMap(\.sealDate).min() }

    private func sealDuePlans() {
        withAnimation(.spring(duration: 0.5)) {
            PlanService.sealDue(plans, minimum: settings?.minimumWeeklyTasks ?? UserSettings.defaultMinimumWeeklyTasks)
        }
        SealActivityManager.reconcile(plans)
    }

    var body: some View {
        TabView(selection: $tab) {
            TodayView(openWeek: { tab = .week })
                .tabItem { Label("Dnes", systemImage: "sun.max") }
                .tag(AppTab.today)
            WeekView(showsNextWeek: $weekShowsNext)
                .tabItem { Label("Týden", systemImage: "calendar") }
                .tag(AppTab.week)
            if settings?.showsStatsTab != false {
                StatsView()
                    .tabItem { Label("Statistiky", systemImage: "chart.bar") }
                    .tag(AppTab.stats)
            }
            if settings?.showsGymTab == true {
                NavigationStack { GymProgressView() }
                    .tabItem { Label("Gym", systemImage: TaskCategory.gym.symbol) }
                    .tag(AppTab.gym)
            }
            if settings?.showsHealthTab == true {
                HealthSummaryView()
                    .tabItem { Label("Zdraví", systemImage: "heart") }
                    .tag(AppTab.health)
            }
            if settings?.showsDiaryTab == true, settings?.diaryEnabled != false {
                DiaryView()
                    .tabItem { Label("Deník", systemImage: "book.closed") }
                    .tag(AppTab.diary)
            }
            SettingsView()
                .tabItem { Label("Nastavení", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(Theme.textPrimary)
        .appLock(settings?.appLockEnabled == true)
        .fullScreenCover(isPresented: $showsRealityCheck) { RealityCheckView() }
        .fullScreenCover(isPresented: Binding(
            get: { onboardingMigrated && settings != nil && settings?.onboardedAt == nil },
            set: { _ in })) {
            OnboardingView(onFinish: finishOnboarding)
                .interactiveDismissDisabled()
        }
        .task {
            let current = UserSettings.current(in: context)
            if !onboardingMigrated {
                if current.onboardedAt == nil, !tasks.isEmpty { current.onboardedAt = .now }
                onboardingMigrated = true
            }
            onReady()
            // A new user is asked for notifications inside the guide, at the moment it makes sense.
            if current.onboardedAt != nil {
                await NotificationManager.requestAuthorization()
            }
            await NotificationManager.reschedule(context: context)
        }
        // `task(id:)` cancels the previous run, so a burst of edits reschedules once.
        .task(id: settings?.healthEnabled) {
            if settings?.healthEnabled == true {
                HealthService.startWorkoutObserver()
            }
        }
        .task(id: notificationSignature) {
            FocusSession.closeAbandoned(in: tasks)
            StreakService.applyInsurance(tasks: tasks, purchases: purchases)
            HealthService.noteGymLogged(tasks.contains {
                $0.category == .gym && $0.isDone && $0.scheduledDate.isSameDay(as: .now)
            })
            if !FocusActivityManager.reconcile(tasks) {
                NotificationManager.cancelFocusEnd()
                NotificationManager.cancelRestEnd()
            }
            WidgetBridge.update(tasks: tasks, plans: plans, targets: settings?.weeklyTargets ?? [:])
            SealActivityManager.reconcile(plans)
            await NotificationManager.reschedule(context: context)
        }
        // Nothing runs while the app is closed, so a plan is sealed here: when its hour runs out
        // with the app open, or the next time the app comes to the front.
        .task(id: nextSealDate) {
            sealDuePlans()
            guard let nextSealDate else { return }
            try? await Task.sleep(for: .seconds(max(nextSealDate.timeIntervalSinceNow, 0) + 0.5))
            if !Task.isCancelled { sealDuePlans() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            sealDuePlans()
            StreakService.applyInsurance(tasks: tasks, purchases: purchases)
            FocusSession.closeAbandoned(in: tasks)
            Task { await NotificationManager.reschedule(context: context) }
        }
        .onChange(of: router.route) { _, route in
            guard let route else { return }
            open(route)
            router.route = nil
        }
    }

    /// After the guide the user lands on the week to plan: this one, or the next one from Friday on.
    private func finishOnboarding() {
        let weekday = Calendar.app.component(.weekday, from: .now)
        weekShowsNext = weekday == 1 || weekday >= 6
        tab = .week
        Task { await NotificationManager.reschedule(context: context) }
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
