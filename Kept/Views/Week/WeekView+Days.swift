import SwiftUI
import SwiftData

extension WeekView {
    /// The sent week's goals in one tappable line.
    var foldsSummary: Bool {
        plan?.isCommitted == true && !goalsExpanded && (!goals.isEmpty || weeklyTotal != nil)
    }

    var showsReviewLink: Bool { !showsNextWeek && plan?.tasks.isEmpty == false }

    var reviewLink: some View {
        NavigationLink {
            WeeklyReviewView(weekStart: weekStart)
        } label: {
            HStack {
                Text("PŘEHLED TÝDNE").labelStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Two or more past days in a row with nothing planned fold into one line; every other day keeps its section.
    var daySegments: [DaySegment] {
        var result: [DaySegment] = []
        var run: [Date] = []
        func flush() {
            if run.count >= 2 { result.append(.quiet(run)) } else { result += run.map(DaySegment.day) }
            run = []
        }
        for day in days {
            let isEmpty = !(plan?.activeTasks ?? []).contains { $0.scheduledDate.isSameDay(as: day) }
            if day.endOfDay <= Date.now && isEmpty {
                run.append(day)
            } else {
                flush()
                result.append(.day(day))
            }
        }
        flush()
        return result
    }

    func quietRow(_ run: [Date]) -> some View {
        HStack {
            Text("\(run[0].weekdayShortText.uppercased())–\(run[run.count - 1].weekdayShortText.uppercased())")
                .labelStyle(Theme.textSecondary)
            Spacer()
            Text("Bez závazků")
                .scaledFont(.body)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    var goalsSummaryRow: some View {
        let met = goals.filter(\.isMet).count
        return Button {
            withAnimation { goalsExpanded = true }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "target")
                    .foregroundStyle(Theme.textPrimary)
                if let total = weeklyTotal {
                    Text("\(total.done) / \(total.minimum) aktivit")
                        .scaledFont(.body, weight: .semibold)
                        .foregroundStyle(Theme.textPrimary)
                }
                if !goals.isEmpty {
                    Text("· cíle \(met) / \(goals.count)")
                        .scaledFont(.body)
                        .foregroundStyle(met == goals.count ? Theme.green : Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.down").foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Rozbalí cíle týdne")
    }

    var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TÝDEN \(weekStart.weekNumber)").labelStyle()
                    Text("\(weekStart.dayMonthText) – \(weekStart.addingDays(6).dayMonthText)")
                        .scaledFont(.title, weight: .bold)
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                NotificationBell(circled: true)
            }
            Picker("Týden", selection: $showsNextWeek) {
                Text("Tento týden").tag(false)
                Text("Příští týden").tag(true)
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    var statusCard: some View {
        if let plan, let committedAt = plan.committedAt {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("ZAPEČETĚNO", systemImage: "checkmark.seal.fill").labelStyle(Theme.textPrimary)
                        Text("Závazky: \(plan.committedTasks.count) · \(committedAt.stampText)")
                            .scaledFont(.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    if let share = SealedWeekShare(plan: plan) {
                        ShareLink(item: share, preview: SharePreview("Kept – týden \(share.weekNumber)",
                                                                     image: Image(systemName: "checkmark.seal.fill"))) {
                            Label("SDÍLET", systemImage: "square.and.arrow.up")
                                .scaledFont(.caption, weight: .bold)
                                .tracking(0.6)
                                .foregroundStyle(Theme.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Theme.cardRaised)
                                .clipShape(Capsule())
                        }
                    }
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
                     : "Naplánuj si týden a pak odešli plánovač.")
                    .scaledFont(.body)
                    .foregroundStyle(Theme.textSecondary)
            }
            .card()
        }
    }

    /// A rest day planned ahead keeps the streak alive. Two a month, so it stays a decision and not a loophole.
    func restDayButton(_ day: Date) -> some View {
        let isRest = RestDays.contains(day)
        return Button {
            switch RestDays.toggle(day) {
            case .set: Haptics.light()
            case .cleared: Haptics.light()
            case .limitReached: Haptics.warning(); restDayLimitHit = true
            case .inThePast: break
            }
        } label: {
            Image(systemName: isRest ? "moon.zzz.fill" : "moon.zzz")
                .scaledFont(.body, weight: .semibold)
                .foregroundStyle(isRest ? Theme.textPrimary : Theme.textTertiary)
                .frame(width: 36, height: 32)
        }
        .accessibilityLabel(isRest ? "Zrušit odpočinkový den" : "Označit jako odpočinkový den")
    }

    func daySection(_ day: Date) -> some View {
        let tasks = (plan?.activeTasks ?? [])
            .filter { $0.scheduledDate.isSameDay(as: day) }
            .sorted { $0.dueDate == $1.dueDate ? $0.priority.rank > $1.priority.rank : $0.dueDate < $1.dueDate }
        let isPast = day.endOfDay <= Date.now
        let isToday = day.isSameDay(as: .now)

        return VStack(spacing: 8) {
            HStack {
                Text(day.shortDayText.uppercased())
                    .labelStyle(isToday ? Theme.textPrimary : Theme.textSecondary)
                if RestDays.contains(day) {
                    Label("Odpočinek", systemImage: "moon.zzz.fill")
                        .scaledFont(.caption, weight: .semibold)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if !isPast {
                    restDayButton(day)
                    Button {
                        editor = EditorRequest(date: day)
                    } label: {
                        Image(systemName: "plus")
                            .scaledFont(.body, weight: .semibold)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 32, height: 24)
                    }
                }
            }
            let events = calendarEvents.filter { $0.start < day.endOfDay && $0.end > day.startOfDay }
            if !events.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(events) { event in
                        Label(event.summary, systemImage: "calendar")
                            .scaledFont(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if tasks.isEmpty {
                if isPast {
                    Text("Žádné závazky")
                        .scaledFont(.body)
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // An empty day invites the first task right where it would go.
                    Button {
                        editor = EditorRequest(date: day)
                    } label: {
                        Label("Přidat úkol na tento den", systemImage: "plus")
                            .scaledFont(.body, weight: .semibold)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 14)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Theme.textTertiary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        if index > 0 {
                            Divider().overlay(Theme.border)
                        }
                        WeekTaskRow(task: task)
                            .flightFrame(task.uid.uuidString)
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
