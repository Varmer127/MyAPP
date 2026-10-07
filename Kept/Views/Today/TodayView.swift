import SwiftUI
import SwiftData

struct TodayView: View {
    @Query private var tasks: [TaskItem]
    @Query private var plans: [WeeklyPlan]
    @Query private var settingsList: [UserSettings]
    @Query private var failures: [FailureRecord]
    @Query private var postponements: [Postponement]
    @Query private var reflections: [WeekReflection]
    /// Day on which the weekly reflection last opened by itself, so it only interrupts once a day.
    @AppStorage("reflectionPromptDay") private var reflectionPromptDay = 0.0
    @State private var reflection: ReflectionRequest?
    /// Minutes of a gym workout Apple Health recorded today, if any.
    @State private var healthGymMinutes: Int?
    /// Start of the day (as a timestamp) on which the Morning Brief was last dismissed.
    @AppStorage("briefDismissedDay") private var briefDismissedDay = 0.0
    /// "<day seed>:<category>,<category>" — suggestions the user declined today.
    @AppStorage("declinedSuggestions") private var declinedSuggestions = ""
    @State private var showsRealityCheck = false
    @State private var editor: EditorRequest?
    @State private var workoutTask: TaskItem?
    @State private var proofTask: TaskItem?
    @State private var postponeTask: TaskItem?
    /// Task the user wants to give up on; asks whether to postpone or to skip.
    @State private var failChoice: TaskItem?
    @State private var focusTask: TaskItem?
    @State private var detailTask: TaskItem?
    /// Task to complete once the focus screen has finished closing.
    @State private var completeAfterFocus: TaskItem?
    @State private var excuse: ExcuseRequest?
    let openWeek: () -> Void
    @Environment(\.scenePhase) private var scenePhase

    private static let refreshInterval: TimeInterval = 60
    private static let briefVisibleUntilHour = 12
    private static let comebackThreshold = 0.6
    private static let stakeQuestionDays = 7
    private static let slippingAfterMinutes = 18 * 60
    private static let slippingCriticalCount = 2

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: Self.refreshInterval)) { timeline in
                content(now: timeline.date)
            }
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editor = EditorRequest(date: .now)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
        }
        .sheet(item: $editor) {
            TaskEditorView(task: $0.task, defaultDate: $0.date, suggestion: $0.suggestion, isRecovery: $0.isRecovery)
        }
        .fullScreenCover(item: $excuse) { NoExcusesView(task: $0.task, kind: $0.kind) }
        .fullScreenCover(isPresented: $showsRealityCheck) { RealityCheckView() }
        .sheet(item: $workoutTask) { WorkoutLogView(task: $0) }
        .sheet(item: $proofTask) { ProofView(task: $0) }
        .fullScreenCover(item: $reflection) { ReflectionView(weekStart: $0.weekStart) }
        .task(id: scenePhase) {
            // Opens the reflection by itself the first time the app is used after the week ends.
            let today = Date.now.startOfDay.timeIntervalSince1970
            // Never on top of the focus timer: presenting a second cover would close the first.
            guard scenePhase == .active, reflectionPromptDay != today, focusTask == nil,
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
            Button("Odložit bez postihu (zbývá \(postponesLeft) z \(postponeLimit))") { postponeTask = task }
            Button("Přeskočit a vysvětlit", role: .destructive) { excuse = ExcuseRequest(task: task, kind: .skipped) }
        }
        .sheet(item: $detailTask) { TaskDetailView(task: $0) }
        .fullScreenCover(item: $focusTask, onDismiss: {
            if let task = completeAfterFocus {
                completeAfterFocus = nil
                complete(task)
            }
        }) { task in
            FocusView(task: task) { completeAfterFocus = task }
        }
    }

    private var postponeLimit: Int { settingsList.first?.postponeLimit ?? UserSettings.postponeLimitRange.upperBound }
    private var postponesLeft: Int { max(0, postponeLimit - PlanService.postponementsUsed(postponements)) }

    /// Skipping first offers a penalty-free postponement while the month's allowance lasts.
    private func giveUp(on task: TaskItem, now: Date) {
        if task.isMissed(now) {
            excuse = ExcuseRequest(task: task, kind: .missed)
        } else if postponesLeft > 0, !task.isRecovery {
            failChoice = task
        } else {
            excuse = ExcuseRequest(task: task, kind: .skipped)
        }
    }

    /// Gym tasks ask what was trained and proof tasks ask for proof before they count as done.
    private func complete(_ task: TaskItem) {
        if task.category == .gym {
            workoutTask = task
        } else if task.requiresProof {
            proofTask = task
        } else {
            withAnimation { task.markDone() }
        }
    }

    private func showsBrief(_ day: TodaySnapshot, now: Date) -> Bool {
        settingsList.first?.morningBriefEnabled != false
            && !day.visible.isEmpty
            && now.minutesIntoDay < Self.briefVisibleUntilHour * 60
            && briefDismissedDay != now.startOfDay.timeIntervalSince1970
    }

    /// From the configured time on, as long as something is still open today.
    private func showsRealityCheckCard(_ day: TodaySnapshot, now: Date) -> Bool {
        guard let settings = settingsList.first, settings.realityCheckEnabled else { return false }
        return now.minutesIntoDay >= settings.realityCheckMinutes && !(day.critical + day.open).isEmpty
    }

    private func content(now: Date) -> some View {
        let day = TodaySnapshot(tasks: tasks, plans: plans, now: now)
        let slipping = isSlipping(day, now: now)
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                header(now: now, streak: day.streak)
                if slipping {
                    slippingBanner(day)
                }
                if showsBrief(day, now: now) {
                    MorningBriefCard(tasks: tasks, todayTasks: day.visible, promisesKeptThisWeek: day.promisesKept,
                                     streak: day.streak, now: now) {
                        withAnimation { briefDismissedDay = now.startOfDay.timeIntervalSince1970 }
                    }
                }
                if let pending = ReflectionRequest.pending(tasks: tasks, reflections: reflections, now: now) {
                    reflectionCard(pending)
                }
                comebackCard(day, now: now)
                stakeCards(now: now)
                healthWorkoutCard(day)
                hero(day)
                metrics(day)
                if showsRealityCheckCard(day, now: now) {
                    realityCheckCard
                }
                if !day.weekIsCommitted {
                    uncommittedCard
                }
                if !day.unresolved.isEmpty {
                    section("Nevyřešené — \(day.unresolved.count)", color: Theme.red, tasks: day.unresolved, now: now)
                }
                if !day.critical.isEmpty {
                    section("Kritické", tasks: day.critical, now: now)
                }
                if !day.open.isEmpty {
                    section("Úkoly", tasks: day.open, now: now)
                }
                suggestionsSection(now: now)
                if !day.closed.isEmpty {
                    section("Uzavřené", tasks: day.closed, now: now)
                }
                if day.visible.isEmpty && day.unresolved.isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 32)
        }
        .background(alignment: .top) {
            // Savage tone only: a quiet dark-red wash at the top while the day is being lost.
            LinearGradient(colors: [Theme.red.opacity(slipping ? 0.22 : 0), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 340)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: slipping)
        }
    }

    /// The failure state exists only in the savage tone and only when the day is really going wrong:
    /// several critical tasks overdue or all of them lost, or under 50 % by the evening.
    private func isSlipping(_ day: TodaySnapshot, now: Date) -> Bool {
        guard settingsList.first?.tone == .savage else { return false }
        let critical = day.scored.filter { $0.scoringPriority == .critical && !$0.isRemoved }
        let overdue = critical.filter { $0.isOverdue(now) }.count
        let allCriticalGone = critical.count >= Self.slippingCriticalCount
            && critical.allSatisfy { $0.isLost(now) || $0.isOverdue(now) }
        let weakEvening = now.minutesIntoDay >= Self.slippingAfterMinutes
            && !day.scored.isEmpty && (day.productivity ?? 0) < Theme.poorThreshold
        return overdue >= Self.slippingCriticalCount || allCriticalGone || weakEvening
    }

    private func slippingBanner(_ day: TodaySnapshot) -> some View {
        let critical = day.scored.filter { $0.scoringPriority == .critical && !$0.isRemoved }
        return VStack(alignment: .leading, spacing: 6) {
            Text("DNEŠEK TI UTÍKÁ")
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(Theme.red)
            if !critical.isEmpty {
                Text("KRITICKÉ ÚKOLY \(critical.filter(\.isDone).count) / \(critical.count)")
                    .labelStyle(Theme.red)
            }
        }
    }

    private func header(now: Date, streak: Int) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DNES").labelStyle()
                Text(now.longDayText)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            // Days in a row at 80 % or better. Lit only while the streak is alive.
            VStack(spacing: 0) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 30))
                    .symbolEffect(.bounce, options: .nonRepeating, value: streak)
                Text("\(streak)")
                    .font(.system(size: 17, weight: .heavy))
                    .contentTransition(.numericText())
            }
            .foregroundStyle(streak > 0 ? Theme.orange : Theme.textTertiary)
            .animation(.easeOut(duration: 0.4), value: streak)
        }
    }

    private func hero(_ day: TodaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(day.accountability.map { "\($0.score)" } ?? "—")
                .font(.system(size: 72, weight: .heavy))
                .foregroundStyle(heroColor(day.accountability?.score))
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.6), value: day.accountability?.score)
            Text("SPOLEHLIVOST").labelStyle()
            Text(day.accountability?.subtitle ?? "Zatím žádná historie. Zavaž se k týdnu a dodrž slovo.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 4)
        }
    }

    private func heroColor(_ score: Int?) -> Color {
        guard let score else { return Theme.textTertiary }
        return Double(score) / 100 < Theme.poorThreshold ? Theme.red : Theme.textPrimary
    }

    private func metrics(_ day: TodaySnapshot) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                MetricTile(value: day.promisesKept.percentText, label: "Dodržené sliby")
                MetricTile(value: day.productivity.percentText, label: "Produktivita")
                MetricTile(value: "\(day.streak)", label: "Série dní")
            }
            if !day.scored.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Text("\(day.doneCount) / \(day.scored.count)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("ÚKOLŮ SPLNĚNO").labelStyle()
                        Spacer()
                    }
                    ThinBar(value: Double(day.doneCount) / Double(day.scored.count),
                            color: day.doneCount == day.scored.count ? Theme.green : Theme.textPrimary)
                }
            }
        }
    }

    private var uncommittedCard: some View {
        Button(action: openWeek) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TENTO TÝDEN BEZ ZÁVAZKU").labelStyle(Theme.orange)
                    Text("Dokud se nezavážeš, nic z toho, co uděláš, se nepočítá jako dodržený slib.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private func declinedToday(_ now: Date) -> Set<String> {
        let parts = declinedSuggestions.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, parts[0] == "\(now.daySeed)" else { return [] }
        return Set(parts[1].split(separator: ",").map(String.init))
    }

    @ViewBuilder
    private func suggestionsSection(now: Date) -> some View {
        let declined = declinedToday(now)
        let settings = settingsList.first
        let suggestions = SuggestionService.suggestions(
            tasks: tasks,
            workoutPresets: settings?.workoutPresets ?? UserSettings.defaultWorkoutPresets,
            now: now,
            target: { settings?.weeklyTarget(for: $0) ?? $0.defaultWeeklyTarget }
        ).filter { !declined.contains($0.category.rawValue) }
        if !suggestions.isEmpty {
            VStack(spacing: 10) {
                SectionLabel(text: "Návrhy")
                ForEach(suggestions) { suggestion in
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Label(suggestion.category.suggestionTitle, systemImage: suggestion.category.symbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text(suggestion.reason)
                                .font(.system(size: 13))
                                .foregroundStyle(suggestion.isUrgent ? Theme.orange : Theme.textSecondary)
                            if let hint = suggestion.hint {
                                Text(hint)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                        }
                        HStack(spacing: 10) {
                            Button("PŘIDAT NA DNES") {
                                editor = EditorRequest(date: now, suggestion: suggestion.category)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            Button("DNES NE") {
                                let all = declined.union([suggestion.category.rawValue])
                                withAnimation { declinedSuggestions = "\(now.daySeed):\(all.sorted().joined(separator: ","))" }
                            }
                            .buttonStyle(SecondaryButtonStyle(textColor: Theme.textSecondary))
                        }
                    }
                    .card()
                }
            }
        }
    }

    /// After a day under 60 %, today is framed as a comeback: orange until today is back above 80 %.
    @ViewBuilder
    private func comebackCard(_ day: TodaySnapshot, now: Date) -> some View {
        let yesterdayTasks = tasks.filter { $0.scheduledDate.isSameDay(as: now.startOfDay.addingDays(-1)) }
        if let yesterday = ScoreEngine.productivity(yesterdayTasks, now: now), yesterday < Self.comebackThreshold {
            let today = day.productivity ?? 0
            let succeeded = today >= ScoreEngine.Config.streakThreshold
            let color = succeeded ? Theme.green : Theme.orange
            VStack(alignment: .leading, spacing: 14) {
                Text(succeeded ? "COMEBACK SE POVEDL" : "COMEBACK DAY").labelStyle(color)
                HStack(spacing: 28) {
                    comebackFigure("Včera", yesterday.percentText, Theme.textSecondary)
                    comebackFigure("Dnes", today.percentText, color)
                }
                Text(succeeded ? "Včerejšek jsi nezměnil. Dnešek ano." : "Včerejšek nezměníš. Dnešek ano.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                if !succeeded {
                    Button("VYTVOŘIT RECOVERY ÚKOL") {
                        editor = EditorRequest(date: now, isRecovery: true)
                    }
                    .buttonStyle(PrimaryButtonStyle(color: Theme.orange))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(color.opacity(0.5), lineWidth: 1))
        }
    }

    private func comebackFigure(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).labelStyle()
            Text(value)
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(color)
        }
    }

    /// After failing a task with a stake on it, asks whether the stake was honoured.
    @ViewBuilder
    private func stakeCards(now: Date) -> some View {
        let since = now.startOfDay.addingDays(-Self.stakeQuestionDays)
        let open = tasks.filter {
            !$0.stake.isEmpty && $0.stakeOutcome == 0 && $0.scheduledDate >= since
                && ($0.status == .skipped || $0.status == .failed)
        }
        ForEach(open) { task in
            VStack(alignment: .leading, spacing: 12) {
                Text("SÁZKA").labelStyle(Theme.orange)
                Text("Nesplnil jsi „\(task.title)“. Vsadil ses o tohle:")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                Text("„\(task.stake)“")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 10) {
                    Button("DODRŽEL JSEM") { withAnimation { task.stakeOutcome = 1 } }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("NEDODRŽEL") { withAnimation { task.stakeOutcome = 2 } }
                        .buttonStyle(SecondaryButtonStyle(textColor: Theme.red))
                }
            }
            .card()
        }
    }

    /// Apple Health saw a workout today while a gym task is still open: one tap to log and close it.
    @ViewBuilder
    private func healthWorkoutCard(_ day: TodaySnapshot) -> some View {
        if let minutes = healthGymMinutes,
           let gym = (day.critical + day.open).first(where: { $0.category == .gym }) {
            VStack(alignment: .leading, spacing: 12) {
                Label("APPLE HEALTH", systemImage: "heart.fill").labelStyle(Theme.green)
                Text("Dnes máš zaznamenaný trénink (\(minutes) min). Zapiš, co jsi jel, a „\(gym.title)“ je splněný.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("ZAPSAT TRÉNINK") { complete(gym) }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .card()
        }
    }

    private func reflectionCard(_ pending: ReflectionRequest) -> some View {
        Button {
            reflection = pending
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SEBEREFLEXE TÝDNE \(pending.weekStart.weekNumber)").labelStyle(Theme.textPrimary)
                    Text("Projdi si týden a zapiš do deníčku, jak jsi se sebou spokojený.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private var realityCheckCard: some View {
        Button {
            showsRealityCheck = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("VEČERNÍ BILANCE").labelStyle(Theme.orange)
                    Text("Den končí a ty máš pořád otevřené závazky.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Na dnešek nemáš nic v plánu.")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Den bez závazků nejde dodržet ani porušit.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
        }
        .card()
    }

    private func section(_ title: String, color: Color = Theme.textSecondary, tasks: [TaskItem], now: Date) -> some View {
        VStack(spacing: 10) {
            SectionLabel(text: title, color: color)
            ForEach(tasks) { task in
                TaskCard(
                    task: task,
                    now: now,
                    warning: PatternDetectionService.warning(for: task, tasks: self.tasks, failures: failures, now: now),
                    onTap: {
                        if task.status == .pending, !task.isMissed(now) {
                            editor = EditorRequest(task: task)
                        } else {
                            detailTask = task
                        }
                    },
                    onDone: { complete(task) },
                    onFail: { giveUp(on: task, now: now) },
                    onFocus: { focusTask = task }
                )
                .contextMenu {
                    if task.isDone {
                        Button("Vrátit splnění") { withAnimation { task.reopen() } }
                    }
                }
            }
        }
    }
}

/// Everything the Today screen shows, derived once per render.
private struct TodaySnapshot {
    let scored: [TaskItem]
    let visible: [TaskItem]
    let unresolved: [TaskItem]
    let critical: [TaskItem]
    let open: [TaskItem]
    let closed: [TaskItem]
    let accountability: ScoreEngine.Accountability?
    let promisesKept: Double?
    let productivity: Double?
    let streak: Int
    let weekIsCommitted: Bool

    var doneCount: Int { scored.filter(\.isDone).count }

    init(tasks: [TaskItem], plans: [WeeklyPlan], now: Date) {
        let weekStart = now.weekStart
        scored = tasks.filter { $0.scheduledDate.isSameDay(as: now) }
        visible = scored.filter { !$0.isRemoved }
        unresolved = tasks.filter { $0.isMissed(now) }.sorted { $0.scheduledDate > $1.scheduledDate }

        let pending = visible.filter { $0.status == .pending }.sorted {
            $0.dueDate == $1.dueDate ? $0.priority.rank > $1.priority.rank : $0.dueDate < $1.dueDate
        }
        critical = pending.filter { $0.priority == .critical }
        open = pending.filter { $0.priority != .critical }
        closed = visible.filter { $0.status != .pending }

        accountability = ScoreEngine.accountability(tasks: tasks, plans: plans, now: now)
        promisesKept = ScoreEngine.promisesKept(tasks.filter { $0.scheduledDate.weekStart == weekStart }, now: now)
        productivity = ScoreEngine.productivity(scored, now: now)
        streak = ScoreEngine.dayStreak(tasks, now: now)
        weekIsCommitted = plans.first { $0.weekStart == weekStart }?.isCommitted ?? false
    }
}
