import SwiftUI
import SwiftData

struct TodayView: View {
    @Query private var tasks: [TaskItem]
    @Query private var plans: [WeeklyPlan]
    @Query private var settingsList: [UserSettings]
    @Query private var failures: [FailureRecord]
    /// Start of the day (as a timestamp) on which the Morning Brief was last dismissed.
    @AppStorage("briefDismissedDay") private var briefDismissedDay = 0.0
    /// "<day seed>:<category>,<category>" — suggestions the user declined today.
    @AppStorage("declinedSuggestions") private var declinedSuggestions = ""
    @State private var showsRealityCheck = false
    @State private var editor: EditorRequest?
    @State private var workoutTask: TaskItem?
    @State private var excuse: ExcuseRequest?
    let openWeek: () -> Void

    private static let refreshInterval: TimeInterval = 60
    private static let briefVisibleUntilHour = 12

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
        .sheet(item: $editor) { TaskEditorView(task: $0.task, defaultDate: $0.date, suggestion: $0.suggestion) }
        .fullScreenCover(item: $excuse) { NoExcusesView(task: $0.task, kind: $0.kind) }
        .fullScreenCover(isPresented: $showsRealityCheck) { RealityCheckView() }
        .sheet(item: $workoutTask) { WorkoutLogView(task: $0) }
    }

    /// Gym tasks ask what was trained before they count as done.
    private func complete(_ task: TaskItem) {
        if task.category == .gym {
            workoutTask = task
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
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                header(now: now)
                if showsBrief(day, now: now) {
                    MorningBriefCard(tasks: tasks, todayTasks: day.visible, promisesKeptThisWeek: day.promisesKept,
                                     streak: day.streak, now: now) {
                        withAnimation { briefDismissedDay = now.startOfDay.timeIntervalSince1970 }
                    }
                }
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
    }

    private func header(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DNES").labelStyle()
            Text(now.longDayText)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private func hero(_ day: TodaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(day.accountability.map { "\($0.score)" } ?? "—")
                .font(.system(size: 72, weight: .heavy))
                .foregroundStyle(heroColor(day.accountability?.score))
                .contentTransition(.numericText())
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
                            Text(suggestion.category.suggestionTitle)
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
                    onTap: { if task.status == .pending { editor = EditorRequest(task: task) } },
                    onDone: { complete(task) },
                    onFail: { excuse = ExcuseRequest(task: task, kind: task.isMissed(now) ? .missed : .skipped) }
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
