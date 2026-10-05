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

    private var weekStart: Date { Date.now.weekStart.addingDays(showsNextWeek ? 7 : 0) }
    private var plan: WeeklyPlan? { plans.first { $0.weekStart == weekStart } }
    private var days: [Date] { (0..<7).map { weekStart.addingDays($0) } }

    private var goals: [WeeklyGoal] {
        let settings = settingsList.first
        return SuggestionService.goals(tasks: tasks, weekStart: weekStart) {
            settings?.weeklyTarget(for: $0) ?? $0.defaultWeeklyTarget
        }
    }

    private var canCommit: Bool {
        guard let plan else { return false }
        return !plan.isCommitted && !plan.activeTasks.isEmpty && Date.now < plan.weekEnd
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
                    if !goals.isEmpty {
                        WeeklyGoalsCard(goals: goals)
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
                    Button("ZKONTROLOVAT A ZAVÁZAT SE") { planToCommit = plan }
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
                    Text("ZAVÁZÁNO").labelStyle(Theme.textPrimary)
                    Text("Závazky: \(plan.committedTasks.count) · \(committedAt.stampText)")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                }
                PerformanceBar(label: "Dodržené sliby", value: ScoreEngine.promisesKept(plan.tasks))
                PerformanceBar(label: "Věrnost plánu", value: ScoreEngine.commitmentIntegrity(plan))
            }
            .card()
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("BEZ ZÁVAZKU").labelStyle(Theme.orange)
                Text(plan?.activeTasks.isEmpty == false
                     ? "Zatím je to jen návrh. Slibem se stane, až se zavážeš."
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
                                if task.status == .pending { editor = EditorRequest(task: task) }
                            }
                    }
                }
                .card(padding: 0)
            }
        }
    }
}

private struct WeekTaskRow: View {
    let task: TaskItem

    private var statusIcon: (name: String, color: Color) {
        let now = Date.now
        if task.isDone {
            return ("checkmark.circle.fill", task.status == .completedLate ? Theme.orange : Theme.green)
        }
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
                Text(subtitle)
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
