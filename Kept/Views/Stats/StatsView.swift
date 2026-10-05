import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query private var tasks: [TaskItem]
    @Query(sort: \WeeklyPlan.weekStart) private var plans: [WeeklyPlan]
    @Query private var failures: [FailureRecord]
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
        let inRange = tasks.filter { range.contains($0.scheduledDate) }
        return period == .today ? inRange : inRange.filter { $0.isClosed(now) }
    }

    private var integrity: Double? {
        let values = plans.filter { $0.weekEnd > range.lowerBound && $0.weekStart < range.upperBound }
            .compactMap(ScoreEngine.commitmentIntegrity)
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Statistiky")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Picker("Období", selection: $period) {
                            ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    scores
                    counts
                    CategorySection(tasks: scoped)
                    StreaksSection(tasks: tasks)
                    TrendSection(tasks: tasks)
                    longTerm
                    weightProgress
                    ReviewHistorySection(tasks: tasks)
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 32)
            }
            .screenBackground()
            .toolbarBackground(Theme.background, for: .navigationBar)
        }
    }

    private var scores: some View {
        let now = Date.now
        let accountability = ScoreEngine.accountability(tasks: tasks, plans: plans, now: now)
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(accountability.map { "\($0.score)" } ?? "—")
                    .font(.system(size: 48, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("SPOLEHLIVOST").labelStyle()
                    Text("Posledních \(ScoreEngine.Config.accountabilityWindowDays) dní")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            PerformanceBar(label: "Dodržené sliby", value: ScoreEngine.promisesKept(scoped, now: now))
            PerformanceBar(label: "Produktivita", value: ScoreEngine.productivity(scoped, now: now))
            PerformanceBar(label: "Věrnost plánu", value: integrity)
            if ScoreEngine.isBusyNotProductive(scoped, now: now) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Splněno úkolů: \(ScoreEngine.completionRate(scoped).percentText)")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                    Text("Byl jsi aktivní. Nebyl jsi produktivní.")
                        .font(.system(size: 17, weight: .bold))
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

        return VStack(spacing: 10) {
            SectionLabel(text: "Výsledky")
            HStack(spacing: 10) {
                MetricTile(value: "\(completed)", label: "Včas")
                MetricTile(value: "\(late)", label: "Pozdě", color: late > 0 ? Theme.orange : Theme.textPrimary)
                MetricTile(value: "\(skipped)", label: "Přeskočeno", color: skipped > 0 ? Theme.red : Theme.textPrimary)
            }
            HStack(spacing: 10) {
                MetricTile(value: "\(missed)", label: "Nesplněno", color: missed > 0 ? Theme.red : Theme.textPrimary)
                MetricTile(value: "\(removed)", label: "Odstraněno", color: removed > 0 ? Theme.red : Theme.textPrimary)
                MetricTile(value: critical.isEmpty ? "—" : "\(critical.filter(\.isDone).count) / \(critical.count)",
                           label: "Kritické splněno")
            }
        }
    }

    /// Body weight logged with gym workouts, across all time (not limited by the period picker).
    @ViewBuilder
    private var weightProgress: some View {
        let entries = tasks.compactMap { task -> (date: Date, weight: Double)? in
            guard let weight = task.bodyWeight, task.isDone else { return nil }
            return (task.completedAt ?? task.scheduledDate, weight)
        }.sorted { $0.date < $1.date }

        if let first = entries.first, let last = entries.last {
            let change = last.weight - first.weight
            let weights = entries.map(\.weight)
            let low = (weights.min() ?? last.weight) - 1
            let high = (weights.max() ?? last.weight) + 1
            VStack(spacing: 10) {
                SectionLabel(text: "Váha")
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(last.weight.kilogramText)
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        if entries.count > 1 {
                            Text("\(change >= 0 ? "+" : "−")\(abs(change).kilogramText) od \(first.date.dayMonthText)")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    if entries.count > 1 {
                        Chart(entries, id: \.date) { entry in
                            LineMark(x: .value("Den", entry.date), y: .value("Váha", entry.weight))
                                .foregroundStyle(Theme.textPrimary)
                                .interpolationMethod(.monotone)
                            PointMark(x: .value("Den", entry.date), y: .value("Váha", entry.weight))
                                .foregroundStyle(Theme.textPrimary)
                                .symbolSize(24)
                        }
                        .chartYScale(domain: low...high)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4)) {
                                AxisValueLabel(format: Date.FormatStyle(locale: .app).day().month(.defaultDigits))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(values: .automatic(desiredCount: 4)) {
                                AxisGridLine().foregroundStyle(Theme.border)
                                AxisValueLabel().foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .frame(height: 180)
                    } else {
                        Text("Graf se ukáže po druhém zápisu váhy.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .card()
            }
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
