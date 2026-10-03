import SwiftUI
import SwiftData

struct TodayView: View {
    @Query private var tasks: [TaskItem]
    @Query private var plans: [WeeklyPlan]
    @State private var editor: EditorRequest?
    @State private var excuse: ExcuseRequest?
    let openWeek: () -> Void

    private static let refreshInterval: TimeInterval = 60

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
        .sheet(item: $editor) { TaskEditorView(task: $0.task, defaultDate: $0.date) }
        .fullScreenCover(item: $excuse) { NoExcusesView(task: $0.task, kind: $0.kind) }
    }

    private func content(now: Date) -> some View {
        let day = TodaySnapshot(tasks: tasks, plans: plans, now: now)
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                header(now: now)
                hero(day)
                metrics(day)
                if !day.weekIsCommitted {
                    uncommittedCard
                }
                if !day.unresolved.isEmpty {
                    section("Unresolved — \(day.unresolved.count)", color: Theme.red, tasks: day.unresolved, now: now)
                }
                if !day.critical.isEmpty {
                    section("Critical", tasks: day.critical, now: now)
                }
                if !day.open.isEmpty {
                    section("Tasks", tasks: day.open, now: now)
                }
                if !day.closed.isEmpty {
                    section("Closed", tasks: day.closed, now: now)
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
            Text("TODAY").labelStyle()
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
            Text("ACCOUNTABILITY").labelStyle()
            Text(day.accountability?.subtitle ?? "No history yet. Commit to a week and keep your word.")
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
                MetricTile(value: day.promisesKept.percentText, label: "Promises kept")
                MetricTile(value: day.productivity.percentText, label: "Productivity")
                MetricTile(value: "\(day.streak)", label: "Day streak")
            }
            if !day.scored.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Text("\(day.doneCount) / \(day.scored.count)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("TASKS COMPLETED").labelStyle()
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
                    Text("NO COMMITMENT THIS WEEK").labelStyle(Theme.orange)
                    Text("Nothing you do counts as a kept promise until you commit.")
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
            Text("Nothing planned today.")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("A day without commitments can't be kept or broken.")
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
                    onTap: { if task.status == .pending { editor = EditorRequest(task: task) } },
                    onDone: { withAnimation { task.markDone() } },
                    onFail: { excuse = ExcuseRequest(task: task, kind: task.isMissed(now) ? .missed : .skipped) }
                )
                .contextMenu {
                    if task.isDone {
                        Button("Undo completion") { withAnimation { task.reopen() } }
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
