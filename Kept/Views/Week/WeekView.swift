import SwiftUI
import SwiftData

struct WeekView: View {
    @Query(sort: \WeeklyPlan.weekStart) private var plans: [WeeklyPlan]
    @Query private var tasks: [TaskItem]
    @Query private var settingsList: [UserSettings]
    @Binding var showsNextWeek: Bool
    @State private var editor: EditorRequest?
    @State private var planToCommit: WeeklyPlan?
    @State private var showsQuickPlan = false
    @State private var detailTask: TaskItem?

    private var weekStart: Date { Date.now.weekStart.addingDays(showsNextWeek ? 7 : 0) }
    private var plan: WeeklyPlan? { plans.first { $0.weekStart == weekStart } }
    private var days: [Date] { (0..<7).map { weekStart.addingDays($0) } }

    private var goals: [WeeklyGoal] {
        let settings = settingsList.first
        return SuggestionService.goals(tasks: tasks, weekStart: weekStart) {
            settings?.weeklyTarget(for: $0) ?? $0.defaultWeeklyTarget
        }
    }

    private var weeklyTotal: (planned: Int, done: Int, minimum: Int)? {
        let minimum = settingsList.first?.minimumWeeklyTasks ?? UserSettings.defaultMinimumWeeklyTasks
        guard minimum > 0 else { return nil }
        let week = (plan?.committableTasks ?? [])
        return (week.count, week.filter(\.isDone).count, minimum)
    }

    private var canCommit: Bool {
        guard let plan else { return false }
        return !plan.isCommitted && !plan.isSealing && !plan.committableTasks.isEmpty && Date.now < plan.weekEnd
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                    header
                    statusCard
                    if Date.now < weekStart.addingDays(7) {
                        Button("RYCHLÉ PLÁNOVÁNÍ") { showsQuickPlan = true }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                    if !goals.isEmpty || weeklyTotal != nil {
                        WeeklyGoalsCard(goals: goals, total: weeklyTotal)
                    }
                    if !showsNextWeek, plan?.tasks.isEmpty == false {
                        NavigationLink {
                            WeeklyReviewView(weekStart: weekStart)
                        } label: {
                            HStack {
                                Text("PŘEHLED TÝDNE").labelStyle(Theme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
                            }
                            .card()
                        }
                    }
                    VStack(spacing: 20) {
                        ForEach(days, id: \.self) { day in
                            daySection(day)
                        }
                    }
                    if let plan, plan.isCommitted {
                        PlanChangesView(plan: plan)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 32)
            }
            .screenBackground()
            .safeAreaInset(edge: .bottom) {
                if canCommit, let plan {
                    Button("ZKONTROLOVAT A ODESLAT PLÁNOVAČ") { planToCommit = plan }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, Theme.screenPadding)
                        .padding(.vertical, 12)
                        .background(Theme.background)
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
        }
        .sheet(item: $editor) { TaskEditorView(task: $0.task, defaultDate: $0.date, suggestion: $0.suggestion) }
        .sheet(item: $planToCommit) { CommitSummaryView(plan: $0) }
        .sheet(item: $detailTask) { TaskDetailView(task: $0) }
        .sheet(isPresented: $showsQuickPlan) { QuickPlanView(weekStart: weekStart) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TÝDEN \(weekStart.weekNumber)").labelStyle()
                Text("\(weekStart.dayMonthText) – \(weekStart.addingDays(6).dayMonthText)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Picker("Týden", selection: $showsNextWeek) {
                Text("Tento týden").tag(false)
                Text("Příští týden").tag(true)
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var statusCard: some View {
        if let plan, let committedAt = plan.committedAt {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("ZAPEČETĚNO", systemImage: "checkmark.seal.fill").labelStyle(Theme.textPrimary)
                    Text("Závazky: \(plan.committedTasks.count) · \(committedAt.stampText)")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                }
                PerformanceBar(label: "Dodržené sliby", value: ScoreEngine.promisesKept(plan.tasks))
                PerformanceBar(label: "Věrnost plánu", value: ScoreEngine.commitmentIntegrity(plan))
            }
            .card()
            .transition(.scale(scale: 0.94).combined(with: .opacity))
        } else if let plan, let sealDate = plan.sealDate, let submittedAt = plan.submittedAt {
            SealingCard(plan: plan, submittedAt: submittedAt, sealDate: sealDate,
                        minimum: settingsList.first?.minimumWeeklyTasks ?? UserSettings.defaultMinimumWeeklyTasks)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("BEZ ZÁVAZKU").labelStyle(Theme.orange)
                Text(plan?.activeTasks.isEmpty == false
                     ? "Zatím je to jen návrh. Slibem se stane, až ho odešleš a zapečetí se."
                     : "Naplánuj si týden a pak se k němu zavaž.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
            }
            .card()
        }
    }

    private func daySection(_ day: Date) -> some View {
        let tasks = (plan?.activeTasks ?? [])
            .filter { $0.scheduledDate.isSameDay(as: day) }
            .sorted { $0.dueDate == $1.dueDate ? $0.priority.rank > $1.priority.rank : $0.dueDate < $1.dueDate }
        let isPast = day.endOfDay <= Date.now
        let isToday = day.isSameDay(as: .now)

        return VStack(spacing: 8) {
            HStack {
                Text(day.shortDayText.uppercased())
                    .labelStyle(isToday ? Theme.textPrimary : Theme.textSecondary)
                Spacer()
                if !isPast {
                    Button {
                        editor = EditorRequest(date: day)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 32, height: 24)
                    }
                }
            }
            if tasks.isEmpty {
                Text("Žádné závazky")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        if index > 0 {
                            Divider().overlay(Theme.border)
                        }
                        WeekTaskRow(task: task)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if task.status == .pending, !task.isMissed(.now) {
                                    editor = EditorRequest(task: task)
                                } else {
                                    detailTask = task
                                }
                            }
                    }
                }
                .card(padding: 0)
            }
        }
    }
}

/// The handed-in plan ("plánovač") on its way to being sealed: a ring that empties over the hour.
private struct SealingCard: View {
    let plan: WeeklyPlan
    let submittedAt: Date
    let sealDate: Date
    let minimum: Int
    @State private var confirmsWithdraw = false
    /// Day of the overview whose tasks are listed underneath. Monday until the user picks another one.
    @State private var selectedDay: Date?

    private static let maxIconsPerDay = 3
    private static let ringSize: CGFloat = 148
    private static let ringWidth: CGFloat = 8

    var body: some View {
        VStack(spacing: 18) {
            Label("PLÁNOVAČ ČEKÁ NA ZAPEČETĚNÍ", systemImage: "calendar.badge.clock").labelStyle(Theme.orange)
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let total = sealDate.timeIntervalSince(submittedAt)
                let left = max(sealDate.timeIntervalSince(timeline.date), 0)
                ZStack {
                    Circle().stroke(Theme.cardRaised, lineWidth: Self.ringWidth)
                    Circle().trim(from: 0, to: total > 0 ? left / total : 0)
                        .stroke(Theme.orange, style: StrokeStyle(lineWidth: Self.ringWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: left)
                    VStack(spacing: 4) {
                        Image(systemName: left > 0 ? "lock.open.fill" : "lock.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.orange)
                        Text(FocusView.clock(left))
                            .font(.system(size: 30, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                        Text("DO ZAPEČETĚNÍ")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(width: Self.ringSize, height: Self.ringSize)
            }
            VStack(spacing: 6) {
                Text("Závazky v plánovači: \(plan.committableTasks.count)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Zapečetí se sám v \(sealDate.timeText). Do té doby můžeš plán měnit bez postihu. Urychlit to nejde.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if plan.committableTasks.isEmpty || PlanService.missesMinimum(plan, minimum: minimum, now: sealDate) {
                    Text("Plánovač je pod minimem \(minimum) aktivit. Když ho nedoplníš, nezapečetí se a vrátí se ti jako návrh.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            overview
            Button {
                confirmsWithdraw = true
            } label: {
                Label("STÁHNOUT PLÁNOVAČ", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(PrimaryButtonStyle(color: Theme.orange))
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius)
            .stroke(Theme.orange.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])))
        .alert("Stáhnout plánovač?", isPresented: $confirmsWithdraw) {
            Button("Stáhnout", role: .destructive) { withAnimation { PlanService.withdraw(plan) } }
            Button("Zrušit", role: .cancel) {}
        } message: {
            Text("Plán bude zase jen návrh. Až ho odešleš znovu, hodina poběží od začátku.")
        }
    }
}

private extension SealingCard {
    func tasks(on day: Date) -> [TaskItem] {
        plan.committableTasks.filter { $0.scheduledDate.isSameDay(as: day) }
            .sorted { $0.dueDate == $1.dueDate ? $0.priority.rank > $1.priority.rank : $0.dueDate < $1.dueDate }
    }

    func duration(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes) min" : (minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(minutes % 60)")
    }

    /// The whole week at a glance: one column a day with what is planned on it. One day is always open underneath, Monday first.
    var overview: some View {
        let days = (0..<7).map { plan.weekStart.addingDays($0) }
        let all = plan.committableTasks
        return VStack(spacing: 12) {
            HStack {
                Text("CO JE V PLÁNOVAČI").labelStyle()
                Spacer()
                Text("\(duration(all.reduce(0) { $0 + $1.plannedMinutes })) · kritické: \(all.filter { $0.priority == .critical }.count)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack(alignment: .top, spacing: 6) {
                ForEach(days, id: \.self) { day in
                    dayColumn(day)
                }
            }
            dayList(selectedDay ?? plan.weekStart)
        }
        .padding(.top, 4)
    }

    func dayColumn(_ day: Date) -> some View {
        let items = tasks(on: day)
        let isSelected = (selectedDay ?? plan.weekStart) == day
        return Button {
            withAnimation(.easeOut(duration: 0.2)) { selectedDay = day }
        } label: {
            VStack(spacing: 6) {
                Text(day.weekdayShortText.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(day.isSameDay(as: .now) ? Theme.textPrimary : Theme.textSecondary)
                VStack(spacing: 5) {
                    if items.isEmpty {
                        Image(systemName: "minus")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    ForEach(items.prefix(Self.maxIconsPerDay)) { task in
                        Image(systemName: task.category.symbol)
                            .font(.system(size: 13))
                            .foregroundStyle(task.priority == .critical ? Theme.orange : Theme.textPrimary)
                            .frame(height: 16)
                    }
                    if items.count > Self.maxIconsPerDay {
                        Text("+\(items.count - Self.maxIconsPerDay)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 84)
                .background(isSelected ? Theme.orange.opacity(0.14) : Theme.cardRaised)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(isSelected ? Theme.orange : Theme.border, lineWidth: 1))
                Text(items.isEmpty ? " " : "\(items.count)×")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    func dayList(_ day: Date) -> some View {
        let items = tasks(on: day)
        return VStack(alignment: .leading, spacing: 8) {
            Text(day.longDayText).labelStyle(Theme.textPrimary)
            if items.isEmpty {
                Text("Žádné závazky")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)
            }
            ForEach(items) { task in
                HStack(spacing: 10) {
                    Image(systemName: task.category.symbol)
                        .font(.system(size: 13))
                        .foregroundStyle(task.priority == .critical ? Theme.orange : Theme.textSecondary)
                        .frame(width: 20)
                    Text(task.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text([task.deadline.map { "do \($0.timeText)" }, duration(task.plannedMinutes)]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.cardRaised)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct WeekTaskRow: View {
    let task: TaskItem

    private var statusIcon: (name: String, color: Color) {
        let now = Date.now
        if task.isDone {
            if task.isPartial { return ("circle.lefthalf.filled", Theme.orange) }
            return ("checkmark.circle.fill", task.status == .completedLate ? Theme.orange : Theme.green)
        }
        if task.status == .excused { return ("minus.circle.fill", Theme.textTertiary) }
        if task.status != .pending || task.isMissed(now) { return ("xmark.circle.fill", Theme.red) }
        if task.isOverdue(now) { return ("exclamationmark.circle.fill", Theme.red) }
        return ("circle", Theme.textTertiary)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon.name)
                .foregroundStyle(statusIcon.color)
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(task.status == .pending ? Theme.textPrimary : Theme.textSecondary)
                HStack(spacing: 5) {
                    Image(systemName: task.category.symbol)
                    Text(subtitle)
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if task.priority.rank >= TaskPriority.high.rank {
                Badge(text: task.priority.badge,
                      color: task.priority == .critical ? Theme.textPrimary : Theme.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var subtitle: String {
        var parts = [task.category.title, "\(task.plannedMinutes) min"]
        if let deadline = task.deadline { parts.append(deadline.timeText) }
        if task.moveCount > 0 { parts.append("přesunuto") }
        if task.isAddedAfterCommitment { parts.append("přidáno později") }
        return parts.joined(separator: " · ")
    }
}

/// Original plan vs. current plan, with the full log of changes made after committing.
private struct PlanChangesView: View {
    let plan: WeeklyPlan

    private var removed: [TaskItem] { plan.tasks.filter(\.isRemoved) }
    private var movedCount: Int { plan.committedTasks.filter { $0.moveCount > 0 }.count }
    private var addedCount: Int { plan.activeTasks.filter { !$0.isCommitted }.count }
    private var edits: [CommitmentEdit] { plan.edits.sorted { $0.date > $1.date } }

    var body: some View {
        VStack(spacing: 10) {
            SectionLabel(text: "Původní vs. aktuální plán")
            HStack(spacing: 10) {
                MetricTile(value: "\(plan.committedTasks.count)", label: "Původní")
                MetricTile(value: "\(plan.activeTasks.count)", label: "Aktuální")
                MetricTile(value: "\(removed.count)", label: "Odstraněno",
                           color: removed.isEmpty ? Theme.textPrimary : Theme.red)
                MetricTile(value: "\(movedCount)", label: "Přesunuto",
                           color: movedCount == 0 ? Theme.textPrimary : Theme.orange)
            }
            if addedCount > 0 {
                Text("Přidáno po závazku: \(addedCount). Počítají se do produktivity, ne jako sliby.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !edits.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(edits.enumerated()), id: \.element.id) { index, edit in
                        if index > 0 {
                            Divider().overlay(Theme.border)
                        }
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(edit.taskTitle)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                    .strikethrough(edit.kind == .removed)
                                Text("\(edit.kind.title) · \(edit.detail)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(edit.kind.integrityPenalty > 0 ? Theme.orange : Theme.textSecondary)
                            }
                            Spacer()
                            Text(edit.date.stampText)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                    }
                }
                .card(padding: 0)
            }
        }
    }
}
