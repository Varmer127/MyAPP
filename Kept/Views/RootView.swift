import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case today, week, stats, gym, health, diary, settings
}

extension Notification.Name {
    /// Posted with the tab as its object when the tab that is already open is chosen again.
    static let tabReselected = Notification.Name("kept.tabReselected")
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
    @State private var showsSealStamp = false
    /// Bumped when the day or time zone changes, so what is computed from "now" is computed again.
    @State private var clockTick = 0
    /// Planned rest days change what the streak warnings say, so a change reschedules the notifications.
    @AppStorage(RestDays.storageKey) private var restDaysRaw = ""
    // Switching tabs slides the new screen in a little and fades it up, instead of an instant cut.
    @State private var slide: CGFloat = 0
    @State private var fade: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("devShowSeal") private var devShowSeal = false
    @Query private var failures: [FailureRecord]
    @Query private var diary: [DiaryEntry]
    /// Badges already shown to the user, so only a new one gets announced.
    @AppStorage("seenBadges") private var seenBadges = ""
    @AppStorage("badgesInitialised") private var badgesInitialised = false
    /// Health results that earn health badges; a change here is a reason to look for a new badge.
    @AppStorage(HealthStats.key) private var healthStatsData = Data()
    @State private var unlocked: Achievement?
    @AppStorage("devShowDayKept") private var devShowDayKept = false
    @AppStorage("devShowStory") private var devShowStory = false
    @AppStorage("devShowEvening") private var devShowEvening = false
    /// The selected tab; choosing the one that is already open tells it, so it can go back to its first screen.
    private var tabSelection: Binding<AppTab> {
        Binding(get: { tab }, set: { new in
            if new == tab { NotificationCenter.default.post(name: .tabReselected, object: new) }
            tab = new
        })
    }

    private var committedCount: Int { plans.filter(\.isCommitted).count }

    /// The Week tab shows where this week stands: sealed, waiting for its seal, or planned but not sealed yet.
    private var weekTabSymbol: String {
        _ = clockTick
        let plan = plans.first { $0.weekStart == Date.now.weekStart }
        if plan?.isCommitted == true { return "checkmark.seal.fill" }
        if plan?.isSealing == true { return "calendar.badge.clock" }
        if let plan, !plan.pledgeableTasks().isEmpty { return "calendar.badge.exclamationmark" }
        return "calendar"
    }
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
            hasher.combine(task.cue)
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
        hasher.combine(restDaysRaw)
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

    /// Days with a finished workout done in Kept: gym, sport, and the user's own activities marked as workouts.
    private var keptTrainingDays: Set<Date> {
        guard let settings else { return [] }
        return Set(tasks.filter { $0.isDone && settings.isWorkout($0) }.map { ($0.completedAt ?? $0.scheduledDate).startOfDay })
    }

    private var badgeSignature: Int {
        let done = tasks.filter(\.isDone).count
        let sealed = plans.filter(\.isCommitted).count
        return done * 1000 + sealed * 10 + failures.count + diary.count * 7 + healthStatsData.hashValue
    }

    /// Announces a badge that was earned since the last look. The first look only records what exists.
    private func announceNewBadges() async {
        guard settings?.onboardedAt != nil else { return }
        let weeklyTarget: (TaskCategory) -> Int = { settings?.weeklyTarget(for: $0) ?? $0.defaultWeeklyTarget }
        HealthStats.remember(keptTrainingDays: keptTrainingDays)
        let badges = BadgeService.evaluate(tasks: tasks, plans: plans, failures: failures, diary: diary, targets: weeklyTarget)
        let earned = badges.filter(\.isEarned)
        let seen = Set(seenBadges.split(separator: ",").map(String.init))
        seenBadges = earned.map(\.id).joined(separator: ",")
        guard badgesInitialised else {
            badgesInitialised = true
            return
        }
        guard let first = earned.filter({ !seen.contains($0.id) }).max(by: { $0.tier < $1.tier }) else { return }
        Haptics.success()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { unlocked = first }
        try? await Task.sleep(for: .seconds(3.2))
        withAnimation(.easeIn(duration: 0.3)) { unlocked = nil }
    }

    var body: some View {
        TabView(selection: tabSelection) {
            TodayView(openWeek: { tab = .week })
                .modifier(TabSlide(offset: slide, opacity: fade))
                .tabItem { Label("Dnes", systemImage: "sun.max") }
                .tag(AppTab.today)
            WeekView(showsNextWeek: $weekShowsNext)
                .modifier(TabSlide(offset: slide, opacity: fade))
                .tabItem { Label("Týden", systemImage: weekTabSymbol) }
                .tag(AppTab.week)
            if settings?.showsStatsTab != false {
                StatsView()
                    .modifier(TabSlide(offset: slide, opacity: fade))
                .tabItem { Label("Statistiky", systemImage: "chart.bar") }
                    .tag(AppTab.stats)
            }
            if settings?.showsGymTab == true {
                NavigationStack { GymProgressView() }
                    .modifier(TabSlide(offset: slide, opacity: fade))
                .tabItem { Label("Gym", systemImage: TaskCategory.gym.symbol) }
                    .tag(AppTab.gym)
            }
            if settings?.showsHealthTab == true {
                HealthSummaryView()
                    .modifier(TabSlide(offset: slide, opacity: fade))
                .tabItem { Label("Zdraví", systemImage: "heart") }
                    .tag(AppTab.health)
            }
            if settings?.showsDiaryTab == true, settings?.diaryEnabled != false {
                DiaryView()
                    .modifier(TabSlide(offset: slide, opacity: fade))
                .tabItem { Label("Deník", systemImage: "book.closed") }
                    .tag(AppTab.diary)
            }
            SettingsView()
                .modifier(TabSlide(offset: slide, opacity: fade))
                .tabItem { Label("Nastavení", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(Theme.textPrimary)
        .softBottomEdge()
        .onChange(of: tab) { old, new in
            guard !reduceMotion else { return }
            let order: [AppTab] = [.today, .week, .stats, .gym, .health, .diary, .settings]
            let direction: CGFloat = (order.firstIndex(of: new) ?? 0) >= (order.firstIndex(of: old) ?? 0) ? 1 : -1
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                slide = direction * 28
                fade = 0
            }
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.4)) {
                    slide = 0
                    fade = 1
                }
            }
        }
        .appLock(settings?.appLockEnabled == true)
        .modifier(StoreAlerts())
        .modifier(ClockChanges {
            clockTick += 1
            Task { await NotificationManager.reschedule(context: context) }
        })
        // A week turning into a promise gets its moment: the seal drops onto the plan.
        .onChange(of: committedCount) { old, new in
            guard new > old, scenePhase == .active, settings?.onboardedAt != nil else { return }
            withAnimation(.easeOut(duration: 0.2)) { showsSealStamp = true }
        }
        // The Today celebrations are only visible on Today, so the test switches go there first.
        .onChange(of: devShowDayKept) { _, on in if on { tab = .today } }
        .onChange(of: devShowStory) { _, on in if on { tab = .today } }
        .onChange(of: devShowEvening) { _, on in if on { tab = .today } }
        .onChange(of: devShowSeal) { _, on in
            guard on else { return }
            devShowSeal = false
            withAnimation(.easeOut(duration: 0.2)) { showsSealStamp = true }
        }
        // A newly earned badge slides in from the top for a moment.
        .task(id: badgeSignature) { await announceNewBadges() }
        .overlay(alignment: .top) {
            if let unlocked {
                BadgeUnlockBanner(badge: unlocked)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(6)
            }
        }
        .overlay {
            if showsSealStamp {
                SealStamp { withAnimation(.easeIn(duration: 0.3)) { showsSealStamp = false } }
                    .transition(.opacity)
                    .zIndex(5)
            }
        }
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
        // Every time the app comes to the front, Health is read again so health badges are earned without opening its tab.
        .task(id: "\(settings?.healthEnabled == true)-\(scenePhase == .active)") {
            guard settings?.healthEnabled == true, scenePhase == .active else { return }
            _ = await HealthService.summary(keptTrainingDays: keptTrainingDays)
        }
        .task(id: notificationSignature) {
            ActivityIcons.shared.register(custom: settings?.customActivities ?? [])
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
            GymActivityManager.reconcile(tasks)
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

/// The slide-and-fade a screen gets when its tab is chosen.
private struct TabSlide: ViewModifier {
    let offset: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content.offset(x: offset).opacity(opacity)
    }
}

/// "New badge" at the top of the screen, for a few seconds.
private struct BadgeUnlockBanner: View {
    let badge: Achievement
    @State private var popped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if badge.tier != .common {
                    // Rare and legendary badges send out a ring once.
                    Circle()
                        .stroke(badge.tier == .legendary ? Theme.orange : Theme.green, lineWidth: 2)
                        .scaleEffect(popped ? 1.9 : 1)
                        .opacity(popped ? 0 : 0.9)
                }
                Circle().fill(Theme.textPrimary)
                Image(systemName: badge.symbol)
                    .scaledFont(.heading, weight: .semibold)
                    .foregroundStyle(Theme.onPrimary)
            }
            .frame(width: 46, height: 46)
            .scaleEffect(popped || reduceMotion ? 1 : 0.3)
            .rotationEffect(.degrees(popped || reduceMotion ? 0 : -25))
            VStack(alignment: .leading, spacing: 2) {
                Text("NOVÝ ODZNAK · \(badge.tier.title)")
                    .scaledFont(.caption, weight: .heavy)
                    .tracking(1)
                    .foregroundStyle(badge.tier == .legendary ? Theme.orange : Theme.green)
                Text(badge.name)
                    .scaledFont(.heading, weight: .bold)
                    .foregroundStyle(Theme.textPrimary)
                Text(badge.how)
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.regularMaterial)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
        .padding(.horizontal, Theme.screenPadding)
        .accessibilityElement(children: .combine)
        .onAppear {
            guard !reduceMotion else { popped = true; return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.15)) { popped = true }
        }
    }
}
