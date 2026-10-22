import SwiftUI
import SwiftData

struct TodayView: View {
    @Query var tasks: [TaskItem]

    @Query var plans: [WeeklyPlan]

    @Query var settingsList: [UserSettings]

    @Query var failures: [FailureRecord]

    @Query var postponements: [Postponement]

    @Query var reflections: [WeekReflection]

    @Query var purchases: [PointsPurchase]

    @Query var diary: [DiaryEntry]

    @State var showsShop = false

    /// Points just earned, shown for a moment above the tab bar.
    @State var pointsGain: PointsGain?

    @State var showsDayKept = false

    @State var stopTask: TaskItem?

    @State var story: WeekStory?

    @AppStorage("storySeenWeek") var storySeenWeek = 0.0

    @AppStorage("storySeenMonth") var storySeenMonth = 0.0

    @State var monthStory: MonthStory?

    @AppStorage("devShowStory") var devShowStory = false

    @Query var diaryEntries: [DiaryEntry]

    @State var sparkTrigger = 0

    @State var heroFlash: Color?

    @State var showsMorning = false

    @AppStorage("lastActiveAt") var lastActiveAt = 0.0

    @AppStorage("morningGreetedDay") var morningGreetedDay = 0.0

    // Test switches set from the developer section (Debug builds only), harmless otherwise.
    @AppStorage("devShowMorning") var devShowMorning = false

    @AppStorage("devShowDayKept") var devShowDayKept = false

    @AppStorage("devShowEvening") var devShowEvening = false

    /// The day already celebrated, so undoing and redoing a task does not repeat it.
    @AppStorage("dayKeptCelebratedDay") var dayKeptCelebratedDay = 0.0

    /// Day on which the weekly reflection last opened by itself, so it only interrupts once a day.
    @AppStorage("reflectionPromptDay") var reflectionPromptDay = 0.0

    @State var reflection: ReflectionRequest?

    /// Minutes of a gym workout Apple Health recorded today, if any.
    @State var healthGymMinutes: Int?

    /// Start of the day (as a timestamp) on which the Morning Brief was last dismissed.
    /// "<day seed>:<category>,<category>" — suggestions the user declined today.
    @AppStorage("declinedSuggestions") var declinedSuggestions = ""

    /// Day (as a timestamp) of the streak break whose buy-back offer the user turned down.
    @AppStorage(StreakService.offerDismissedKey) var streakOfferDismissed = 0.0

    /// Broken streak waiting for the "really spend the points?" confirmation.
    @State var confirmRepair: StreakService.Broken?

    @State var showsRealityCheck = false

    @State var statsExpanded = false

    /// The Dnes header is scrolled out of sight; a thin bar with the day's progress takes its place.
    @State var compactHeader = false

    @State var upcomingExpanded = false

    /// The open task the user picked from the list to be the main one, with its "Splnil jsem" button.
    @State var pinnedNext: UUID?

    /// Watched only so the screen is drawn again when a rest day is set or cleared.
    @AppStorage(RestDays.storageKey) var restDaysRaw = ""

    /// A short coloured flash on the promise card (red when a sealed promise was just given up).
    @State var promiseFlash: Color?

    @Namespace var zoom

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @State var editor: EditorRequest?

    @State var workoutTask: TaskItem?

    @State var proofTask: TaskItem?

    @State var partialTask: TaskItem?

    /// Partial completion confirmed in the sheet; applied once the sheet has finished closing.
    @State var pendingPartial: (task: TaskItem, share: Double, note: String)?

    @State var postponeTask: TaskItem?

    /// Task the user wants to give up on; asks whether to postpone or to skip.
    @State var failChoice: TaskItem?

    @State var focusTask: TaskItem?

    @State var gymTimerTask: TaskItem?

    @State var detailTask: TaskItem?

    /// Task to complete once the focus screen has finished closing.
    @State var completeAfterFocus: TaskItem?

    /// Task waiting for the "did you really do it as planned?" confirmation.
    @State var confirmDone: TaskItem?

    @State var excuse: ExcuseRequest?

    let openWeek: () -> Void

    @Environment(\.modelContext) var context

    @Environment(\.scenePhase) var scenePhase

    static let refreshInterval: TimeInterval = 60

    static let comebackThreshold = 0.6

    /// Days with something planned before the reliability score is shown at all.
    static let daysBeforeScore = 7

    static let stakeQuestionDays = 7

    static let slippingAfterMinutes = 18 * 60

    /// From this time on, a streak that today would break is shown as at risk.
    static let streakWarningFromMinutes = 19 * 60

    static let slippingCriticalCount = 2

    static let streakUrgentSeconds: TimeInterval = 6 * 3600

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: Self.refreshInterval)) { timeline in
                ZStack {
                    // When the day turns over while the screen is open, the new day fades up instead of jumping in.
                    content(now: timeline.date)
                        .id(timeline.date.startOfDay)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 18)), removal: .opacity))
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: timeline.date.startOfDay)
            }
            .screenBackground()
            // The add button sits in the header row, so the empty navigation bar on top is gone.
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $editor) {
            TaskEditorView(task: $0.task, defaultDate: $0.date, suggestion: $0.suggestion, isRecovery: $0.isRecovery)
        }
        .fullScreenCover(item: $excuse) { NoExcusesView(task: $0.task, kind: $0.kind) }
        .fullScreenCover(isPresented: $showsRealityCheck) { RealityCheckView() }
        .sheet(item: $workoutTask) { WorkoutLogView(task: $0) }
        .sheet(item: $proofTask) { ProofView(task: $0) }
        .sheet(item: $partialTask, onDismiss: {
            if let partial = pendingPartial {
                pendingPartial = nil
                complete(partial.task, share: partial.share, note: partial.note)
            }
        }) { task in
            PartialView(task: task) { share, note in pendingPartial = (task, share, note) }
        }
        .fullScreenCover(item: $reflection) { ReflectionView(weekStart: $0.weekStart) }
        .task(id: scenePhase) {
            // Opens the reflection by itself the first time the app is used after the week ends.
            let today = Date.now.startOfDay.timeIntervalSince1970
            // Never on top of the focus timer: presenting a second cover would close the first.
            guard scenePhase == .active, reflectionPromptDay != today, focusTask == nil, gymTimerTask == nil,
                  let pending = ReflectionRequest.pending(tasks: tasks, reflections: reflections) else { return }
            reflectionPromptDay = today
            reflection = pending
        }
        .task(id: scenePhase) {
            guard scenePhase == .active, settingsList.first?.healthEnabled == true else { return }
            healthGymMinutes = await HealthService.gymMinutesToday()
        }
        .sheet(item: $postponeTask) { PostponeView(task: $0, remaining: postponesLeft, limit: postponeLimit) }
        .confirmationDialog("Co s tím úkolem?", isPresented: Binding(get: { failChoice != nil }, set: { if !$0 { failChoice = nil } }),
                            titleVisibility: .visible, presenting: failChoice) { task in
            if postponesLeft > 0, !task.isRecovery {
                Button("Odložit bez postihu (zbývá \(postponesLeft) z \(postponeLimit))") { postponeTask = task }
            }
            if PointsService.canRedeem(task, balance: PointsService.balance(tasks, purchases: purchases, diary: diary)) {
                Button("Zrušit za \(PointsService.passCost) bodů bez postihu") {
                    withAnimation { PointsService.redeem(task) }
                }
            }
            Button("Přeskočit a vysvětlit", role: .destructive) { excuse = ExcuseRequest(task: task, kind: .skipped) }
        }
        .sheet(item: $detailTask) {
            TaskDetailView(task: $0).navigationTransition(.zoom(sourceID: $0.uid, in: zoom))
        }
        .sheet(isPresented: $showsShop) { ShopView() }
        // Every rise of the balance gets a short celebration: completing, partial completion, a milestone bonus.
        .onChange(of: PointsService.balance(tasks, purchases: purchases, diary: diary)) { old, new in
            if new > old { pointsGain = PointsGain(amount: new - old) }
        }
        .overlay(alignment: .bottom) {
            if let pointsGain {
                PointsGainToast(amount: pointsGain.amount, text: pointsGain.text) { self.pointsGain = nil }
                    .id(pointsGain.id)
                    .padding(.bottom, 24)
                    .allowsHitTesting(false)
            }
        }
        .sensoryFeedback(.success, trigger: pointsGain?.id) { _, new in new != nil }
        .confirmationDialog("Zastavit časovač?", isPresented: Binding(get: { stopTask != nil }, set: { if !$0 { stopTask = nil } }),
                            titleVisibility: .visible, presenting: stopTask) { task in
            Button("Zastavit", role: .destructive) { withAnimation { FocusView.stop(task) } }
            Button("Nechat běžet", role: .cancel) {}
        } message: { _ in
            Text("Úkol zůstane otevřený a odpracovaný čas se uloží.")
        }
        // The last open task of the day closes the day: a short, full-screen moment.
        .onChange(of: todayKept) { _, kept in
            let today = Date.now.startOfDay.timeIntervalSince1970
            guard kept, dayKeptCelebratedDay != today else { return }
            dayKeptCelebratedDay = today
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(.easeOut(duration: 0.25)) { showsDayKept = true }
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            let now = Date.now
            if phase == .active {
                if !showsMorning, MorningMoment.isDue(now: now,
                                                      lastActive: lastActiveAt > 0 ? Date(timeIntervalSince1970: lastActiveAt) : nil,
                                                      lastGreetedDay: morningGreetedDay > 0 ? Date(timeIntervalSince1970: morningGreetedDay) : nil,
                                                      onboardedAt: settingsList.first?.onboardedAt) {
                    morningGreetedDay = now.timeIntervalSince1970
                    showsMorning = true
                }
                lastActiveAt = now.timeIntervalSince1970
            } else {
                lastActiveAt = now.timeIntervalSince1970
            }
        }
        .onChange(of: devShowMorning) { _, on in
            guard on else { return }
            devShowMorning = false
            showsMorning = true
        }
        .onChange(of: devShowStory) { _, on in
            guard on else { return }
            devShowStory = false
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                // The test shows this week even before it is over; on a week without closed tasks, the last one with any.
                let thisWeek = Date.now.weekStart
                story = [thisWeek, thisWeek.addingDays(-7), thisWeek.addingDays(-14)]
                    .lazy.compactMap { WeekStory.make(tasks: tasks, diary: diaryEntries, weekStart: $0) }.first
                    ?? WeekStory.demo
            }
        }
        .fullScreenCover(item: $monthStory) { month in
            MonthStoryView(story: month) {
                storySeenMonth = month.monthStart.timeIntervalSince1970
                monthStory = nil
            }
            .appAppearance()
        }
        .fullScreenCover(item: Binding(get: { story.map { StoryBox(story: $0) } }, set: { if $0 == nil { story = nil } })) { box in
            WeekStoryView(story: box.story) {
                storySeenWeek = box.story.weekStart.timeIntervalSince1970
                story = nil
            }
            .appAppearance()
        }
        .onChange(of: devShowEvening) { _, on in
            guard on else { return }
            devShowEvening = false
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                showsRealityCheck = true
            }
        }
        .onChange(of: devShowDayKept) { _, on in
            guard on else { return }
            devShowDayKept = false
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                withAnimation(.easeOut(duration: 0.25)) { showsDayKept = true }
            }
        }
        .fullScreenCover(isPresented: $showsMorning) {
            MorningGreeting(name: settingsList.first?.addressName ?? "",
                            tasks: todayTasks,
                            streak: ScoreEngine.dayStreak(tasks),
                            openFromBefore: tasks.filter { $0.isMissed(.now) }.count,
                            freshStart: FreshStart.today(tasks: tasks, now: .now),
                            onStart: { showsMorning = false },
                            onAdd: {
                                showsMorning = false
                                Task {
                                    try? await Task.sleep(for: .milliseconds(450))
                                    editor = EditorRequest(date: .now)
                                }
                            },
                            onPlanWeek: {
                                showsMorning = false
                                openWeek()
                            })
                .appAppearance()
        }
        .overlay {
            if showsDayKept {
                DayKeptCelebration(done: max(todayTasks.filter(\.isDone).count, 1), streak: ScoreEngine.dayStreak(tasks),
                                   milestone: StreakService.milestones(tasks).last { $0.reachedOn?.isSameDay(as: .now) == true }) {
                    withAnimation(.easeIn(duration: 0.25)) { showsDayKept = false }
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
        // A moment to be honest before anything counts as done.
        .alert("Opravdu jsi to splnil podle plánu?",
               isPresented: Binding(get: { confirmDone != nil }, set: { if !$0 { confirmDone = nil } }),
               presenting: confirmDone) { task in
            Button("Ano, splnil jsem") { complete(task) }
            if !task.isMissed(.now) {
                Button("Jen částečně") { partialTask = task }
            }
            Button("Zrušit", role: .cancel) {}
        } message: { task in
            Text("\(task.title) · \(task.plannedMinutes) min\n\nBuď k sobě upřímný. Podvedl bys jen sám sebe.")
        }
        .fullScreenCover(item: $focusTask, onDismiss: {
            if let task = completeAfterFocus {
                completeAfterFocus = nil
                confirmDone = task
            }
        }) { task in
            FocusView(task: task) { completeAfterFocus = task }
        }
        .fullScreenCover(item: $gymTimerTask, onDismiss: {
            if let task = completeAfterFocus {
                completeAfterFocus = nil
                confirmDone = task
            }
        }) { task in
            GymTimerView(task: task) { completeAfterFocus = task }
        }
    }

    var postponeLimit: Int { settingsList.first?.postponeLimit ?? UserSettings.postponeLimitRange.upperBound }

    var postponesLeft: Int {
        max(0, postponeLimit + PointsService.extraPostponements(purchases) - PlanService.postponementsUsed(postponements))
    }

    /// Skipping first offers a penalty-free postponement while the month's allowance lasts.
    func giveUp(on task: TaskItem, now: Date) {
        if task.isMissed(now) {
            excuse = ExcuseRequest(task: task, kind: .missed)
        } else if (postponesLeft > 0 && !task.isRecovery) || PointsService.canRedeem(task, balance: PointsService.balance(tasks, purchases: purchases, diary: diary), now: now) {
            failChoice = task
        } else {
            excuse = ExcuseRequest(task: task, kind: .skipped)
        }
    }

    /// Gym tasks ask what was trained and proof tasks ask for proof before they count as done.
    func complete(_ task: TaskItem, share: Double = 1, note: String = "") {
        // Set on every attempt, so a cancelled partial completion never leaks into a later full one.
        task.completionShare = share
        task.partialNote = note
        if task.category == .gym {
            workoutTask = task
        } else if task.requiresProof {
            proofTask = task
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { task.markDone() }
            // Outside a sent plan a task earns no points, but keeping your word still deserves a moment.
            if PointsService.earned(by: task) == 0 {
                pointsGain = PointsGain(amount: 0, text: share < 1 ? "ČÁSTEČNĚ SPLNĚNO" : "SPLNĚNO")
            }
        }
    }

    var todayTasks: [TaskItem] {
        tasks.filter { $0.scheduledDate.isSameDay(as: .now) && $0.countsInScores && !$0.isRemoved }
    }

    /// Everything planned for today is done, and there was something.
    var todayKept: Bool {
        let today = todayTasks
        return !today.isEmpty && today.allSatisfy(\.isDone)
    }

    /// From the configured time on, as long as something is still open today.
    func showsRealityCheckCard(_ day: TodaySnapshot, now: Date) -> Bool {
        guard let settings = settingsList.first, settings.realityCheckEnabled else { return false }
        return now.minutesIntoDay >= settings.realityCheckMinutes && !(day.critical + day.open).isEmpty
    }

    func content(now: Date) -> some View {
        let day = TodaySnapshot(tasks: tasks, plans: plans, targets: settingsList.first?.weeklyTargets ?? [:], now: now)
        let slipping = isSlipping(day, now: now)
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                header(now: now, day: day)
                weekStoryCard(now: now)
                monthStoryCard(now: now)
                todaysPromise(day, now: now)
                FirstWeekCard(tasks: tasks, plans: plans, streak: day.streak,
                              onboardedAt: settingsList.first?.onboardedAt, onOpenWeek: openWeek)
                if slipping {
                    slippingBanner(day)
                }
                streakCard(day, now: now)
                insuranceUsedCard(now: now)
                if let pending = ReflectionRequest.pending(tasks: tasks, reflections: reflections, now: now) {
                    reflectionCard(pending)
                }
                comebackCard(day, now: now)
                stakeCards(now: now)
                healthWorkoutCard(day)
                if showsRealityCheckCard(day, now: now) {
                    realityCheckCard
                }
                if !day.unresolved.isEmpty {
                    section("Uzavři, co zůstalo otevřené · \(day.unresolved.count)", color: Theme.orange, tasks: day.unresolved, now: now)
                }
                if !day.critical.isEmpty {
                    section("Kritické", tasks: day.critical, now: now)
                }
                if !day.open.isEmpty {
                    section("Úkoly", tasks: day.open, now: now)
                }
                if !day.weekIsCommitted {
                    uncommittedCard
                }
                statsStrip(day, now: now)
                suggestionsSection(now: now)
                if !day.closed.isEmpty {
                    section("Uzavřené", tasks: day.closed, now: now)
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 32)
        }
        .refreshesData()
        .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > 170 } action: { _, scrolled in
            withAnimation(.easeOut(duration: 0.2)) { compactHeader = scrolled }
        }
        .overlay(alignment: .top) {
            if compactHeader, !day.visible.isEmpty {
                compactBar(day)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(alignment: .top) {
            // Savage tone only: a quiet dark-red wash at the top while the day is being lost.
            LinearGradient(colors: [Theme.red.opacity(slipping ? 0.22 : 0), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 340)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: slipping)
        }
    }

}