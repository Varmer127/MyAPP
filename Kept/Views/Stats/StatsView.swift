import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query private var tasks: [TaskItem]
    @Query(sort: \WeeklyPlan.weekStart) private var plans: [WeeklyPlan]
    @Query private var failures: [FailureRecord]
    @Query private var sessions: [FocusSession]
    @Query private var reflections: [WeekReflection]
    @Query private var diary: [DiaryEntry]
    @Query private var settingsList: [UserSettings]
    @State private var period: Period = .week

    private static let monthDays = 30
    private static let longTermDays = 90

    enum Period: String, CaseIterable, Identifiable {
        case today = "Dnes", week = "Týden", month = "Měsíc"
        var id: String { rawValue }
    }

    private var range: Range<Date> {
        let now = Date.now
        switch period {
        case .today: return now.startOfDay..<now.endOfDay
        case .week: return now.weekStart..<now.weekStart.addingDays(7)
        case .month: return now.startOfDay.addingDays(-Self.monthDays + 1)..<now.endOfDay
        }
    }

    /// Today is judged as a whole; longer periods only on tasks whose outcome is final.
    private var scoped: [TaskItem] {
        let now = Date.now
        let inRange = tasks.filter { range.contains($0.scheduledDate) && $0.countsInScores }
        return period == .today ? inRange : inRange.filter { $0.isClosed(now) }
    }

    private var integrity: Double? {
        let values = plans.filter { $0.weekEnd > range.lowerBound && $0.weekStart < range.upperBound }
            .compactMap(ScoreEngine.commitmentIntegrity)
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    /// True when shown inside another screen's navigation (opened from Settings) instead of as a tab.
    var isEmbedded = false

    var body: some View {
        if isEmbedded {
            content
        } else {
            NavigationStack { content }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Statistiky")
                            .scaledFont(.title, weight: .bold)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        NotificationBell(circled: true)
                    }
                    Picker("Období", selection: $period) {
                        ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                scores
                FriendsEntryCard()
                NavigationLink {
                    GymProgressView()
                } label: {
                    HStack {
                        Label("GYM – PROGRES", systemImage: TaskCategory.gym.symbol).labelStyle(Theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
                    }
                    .card()
                }
                counts
                CategorySection(tasks: scoped)
                StreaksSection(tasks: tasks)
                TrendSection(tasks: tasks)
                CalendarSection(tasks: tasks, diaryDays: Set(diary.filter(\.hasWriting).map { $0.day.startOfDay }))
                EffortSection(tasks: tasks, sessions: sessions)
                longTerm
                RecordsSection(tasks: tasks, sessions: sessions)
                JournalLinkSection(count: reflections.count)
                ReviewHistorySection(tasks: tasks)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 32)
        }
        .screenBackground()
        .refreshesData()
        .toolbarBackground(Theme.background, for: .navigationBar)
    }

    private static let sparkWeeks = 8

    /// One value per week for the last weeks, oldest first, from the tasks that were planned in that week.
    private func weeklySeries(now: Date, _ value: ([TaskItem]) -> Double?) -> [Double?] {
        (0..<Self.sparkWeeks).reversed().map { back in
            let start = now.weekStart.addingDays(-7 * back)
            let week = tasks.filter { !$0.isRemoved && $0.scheduledDate.weekStart == start }
            return week.isEmpty ? nil : value(week)
        }
    }

    private var scores: some View {
        let now = Date.now
        let targets = settingsList.first?.weeklyTargets ?? [:]
        let accountability = ScoreEngine.accountability(tasks: tasks, plans: plans, targets: targets, now: now)
        // Before a week of history the score says nothing, so it is not shown: the same rule as on Today.
        let hasHistory = Set(tasks.filter { !$0.isRemoved && $0.countsInScores && $0.scheduledDate < now.startOfDay }
            .map { $0.scheduledDate.startOfDay }).count >= 7
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if hasHistory {
                    Text("\(accountability?.score ?? ScoreEngine.startingScore)")
                        .scaledFont(.hero, weight: .heavy)
                        .foregroundStyle(Theme.textPrimary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("SPOLEHLIVOST").labelStyle()
                    Text(hasHistory ? "Vždy za posledních \(ScoreEngine.Config.accountabilityWindowDays) dní" : "Zatím sbíráme data, ukáže se po prvním týdnu")
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            PerformanceBar(label: "Dodržené sliby", value: ScoreEngine.promisesKept(scoped, now: now),
                           series: weeklySeries(now: now) { ScoreEngine.promisesKept($0, now: now) })
            PerformanceBar(label: "Produktivita", value: ScoreEngine.productivity(scoped, now: now),
                           series: weeklySeries(now: now) { ScoreEngine.productivity($0, now: now) })
            PerformanceBar(label: "Věrnost plánu", value: integrity,
                           series: (0..<Self.sparkWeeks).reversed().map { back in
                               let start = now.weekStart.addingDays(-7 * back)
                               return plans.first { $0.weekStart == start }.flatMap(ScoreEngine.commitmentIntegrity)
                           })
            PerformanceBar(label: "Týdenní cíle", value: accountability?.weeklyGoals)
            if ScoreEngine.isBusyNotProductive(scoped, now: now) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Splněno úkolů: \(ScoreEngine.completionRate(scoped).percentText)")
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Text("Byl jsi aktivní. Nebyl jsi produktivní.")
                        .scaledFont(.heading, weight: .bold)
                        .foregroundStyle(Theme.red)
                }
            }
        }
        .card()
    }

    private var counts: some View {
        let now = Date.now
        let completed = scoped.filter { $0.status == .completed && !$0.isRemoved }.count
        let late = scoped.filter { $0.status == .completedLate && !$0.isRemoved }.count
        let skipped = scoped.filter { $0.status == .skipped && !$0.isRemoved }.count
        let missed = scoped.filter { ($0.status == .failed || $0.isMissed(now)) && !$0.isRemoved }.count
        let removed = scoped.filter(\.isRemoved).count
        let critical = scoped.filter { $0.scoringPriority == .critical }

        // Nothing was ever closed: one card instead of tiles of zeros.
        if scoped.allSatisfy({ $0.status == .pending && !$0.isRemoved && !$0.isMissed(now) }) {
            return AnyView(newcomerCard)
        }
        return AnyView(VStack(spacing: 10) {
            SectionLabel(text: "Výsledky")
            TileRow {
                MetricTile(value: "\(completed)", label: "Včas")
                MetricTile(value: "\(late)", label: "Pozdě", color: late > 0 ? Theme.orange : Theme.textPrimary)
                MetricTile(value: "\(skipped)", label: "Přeskočeno", color: skipped > 0 ? Theme.red : Theme.textPrimary)
            }
            TileRow {
                MetricTile(value: "\(missed)", label: "Nesplněno", color: missed > 0 ? Theme.red : Theme.textPrimary)
                MetricTile(value: "\(removed)", label: "Odstraněno", color: removed > 0 ? Theme.red : Theme.textPrimary)
                MetricTile(value: critical.isEmpty ? "—" : "\(critical.filter(\.isDone).count) / \(critical.count)",
                           label: "Kritické splněno")
            }
        })
    }

    /// Statistics wake up with the first closed task; until then they say what to do.
    private var newcomerCard: some View {
        let planned = !tasks.filter { !$0.isRemoved }.isEmpty
        let sealed = plans.contains(where: \.isCommitted)
        return VStack(spacing: 10) {
            SectionLabel(text: "Výsledky")
            VStack(spacing: 12) {
                EmptyStateArt(kind: .stats)
                Text("Statistiky se rozjedou po prvním týdnu")
                    .scaledFont(.heading, weight: .bold)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Zapečeť týden a splň první úkoly. Pak tu uvidíš, kdy ti to jde a kdy ne.")
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { step in
                        Capsule()
                            .fill(step < (sealed ? 2 : (planned ? 1 : 0)) ? Theme.green : Theme.cardRaised)
                            .frame(width: 26, height: 6)
                    }
                    Text(sealed ? "Zbývá splnit první úkol" : (planned ? "Další krok: zapečeť týden" : "První krok: naplánuj týden"))
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.leading, 6)
                }
            }
            .frame(maxWidth: .infinity)
            .card()
        }
    }

    /// Excuses and patterns always look at the last 90 days, whatever period is selected.
    @ViewBuilder
    private var longTerm: some View {
        let since = Date.now.startOfDay.addingDays(-Self.longTermDays)
        let recentFailures = failures.filter { $0.taskDate >= since }
        let insights = PatternDetectionService.insights(
            tasks: tasks.filter { $0.scheduledDate >= since }, failures: recentFailures,
            plans: plans.filter { $0.weekEnd > since })
        if !insights.isEmpty {
            VStack(spacing: 10) {
                SectionLabel(text: "Zjištěné vzorce")
                InsightList(insights: insights)
            }
        }
        let counts = StatisticsService.excuseCounts(recentFailures)
        if !counts.isEmpty {
            VStack(spacing: 10) {
                SectionLabel(text: "Výmluvy za \(Self.longTermDays) dní")
                ExcuseList(counts: counts)
            }
        }
    }
}
