import SwiftUI
import SwiftData
import Charts

/// Personal performance report for one week. Computed from history every time, never stored.
struct WeeklyReviewView: View {
    @Query private var tasks: [TaskItem]
    @Query private var plans: [WeeklyPlan]
    @Query private var failures: [FailureRecord]
    let weekStart: Date

    private static let daysInWeek = 7
    private static let truthGood = 0.8
    private static let truthPoor = 0.5

    private var now: Date { .now }
    private func closedTasks(in week: Date) -> [TaskItem] {
        tasks.filter { $0.scheduledDate.weekStart == week && $0.isClosed(now) && !$0.isRecovery }
    }
    private var closed: [TaskItem] { closedTasks(in: weekStart) }
    private var weekFailures: [FailureRecord] { failures.filter { $0.taskDate.weekStart == weekStart } }
    private var weekPlans: [WeeklyPlan] { plans.filter { $0.weekStart == weekStart } }
    private var promisesKept: Double? { ScoreEngine.promisesKept(closed, now: now) }
    private var productivity: Double? { ScoreEngine.productivity(closed, now: now) }
    private var dayScores: [StatisticsService.DayScore] {
        StatisticsService.dailyScores(tasks: tasks, from: weekStart, days: Self.daysInWeek, now: now)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                header
                if closed.isEmpty {
                    Text("V tomto týdnu zatím není žádný uzavřený úkol.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                        .card()
                } else {
                    counts
                    dayChart
                    highlights
                    excuses
                    patterns
                    selfCritique
                    truth
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 32)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TÝDEN \(weekStart.weekNumber) · \(weekStart.dayMonthText) – \(weekStart.addingDays(6).dayMonthText)")
                .labelStyle()
            Text(promisesKept.percentText)
                .font(.system(size: 72, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
            Text("DODRŽENÉ SLIBY").labelStyle()
            if let current = promisesKept,
               let previous = ScoreEngine.promisesKept(closedTasks(in: weekStart.addingDays(-7)), now: now) {
                let delta = Int(((current - previous) * 100).rounded())
                Text("\(delta >= 0 ? "+" : "−")\(abs(delta)) % oproti minulému týdnu")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(delta >= 0 ? Theme.green : Theme.red)
                    .padding(.top, 4)
            }
            HStack(spacing: 10) {
                MetricTile(value: productivity.percentText, label: "Produktivita")
                MetricTile(value: weekPlans.first.flatMap(ScoreEngine.commitmentIntegrity).percentText, label: "Věrnost plánu")
            }
            .padding(.top, 12)
        }
    }

    private var counts: some View {
        let done = closed.filter(\.isDone)
        let late = done.filter { $0.status == .completedLate }.count
        let missed = closed.count - done.count
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                MetricTile(value: "\(closed.count)", label: "Celkem")
                MetricTile(value: "\(done.count)", label: "Splněno")
                MetricTile(value: "\(missed)", label: "Nesplněno", color: missed > 0 ? Theme.red : Theme.textPrimary)
            }
            HStack(spacing: 10) {
                MetricTile(value: "\(done.count - late)", label: "Včas")
                MetricTile(value: "\(late)", label: "Pozdě", color: late > 0 ? Theme.orange : Theme.textPrimary)
            }
        }
    }

    private var dayChart: some View {
        VStack(spacing: 10) {
            SectionLabel(text: "Produktivita po dnech")
            Chart(dayScores) { score in
                BarMark(x: .value("Den", score.day.weekdayShortText.uppercased()),
                        y: .value("Produktivita", (score.productivity ?? 0) * 100))
                    .foregroundStyle(Theme.performanceColor(score.productivity))
                    .cornerRadius(3)
                    .annotation(position: .top) {
                        if let value = score.productivity {
                            Text("\(Int((value * 100).rounded()))")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
            }
            .chartYScale(domain: 0...110)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { AxisValueLabel().foregroundStyle(Theme.textSecondary) }
            }
            .frame(height: 180)
            .card()
        }
    }

    @ViewBuilder
    private var highlights: some View {
        let scored = dayScores.compactMap { score in score.productivity.map { (day: score.day, value: $0) } }
        let categories = StatisticsService.categoryPerformance(closed)
        let lost = Dictionary(grouping: closed.filter { $0.isLost(now) }) { FailureRecord.key(for: $0.title) }
        let mostFailed = lost.max { $0.value.count < $1.value.count }

        VStack(spacing: 10) {
            if scored.count >= 2, let best = scored.max(by: { $0.value < $1.value }),
               let worst = scored.min(by: { $0.value < $1.value }) {
                HStack(spacing: 10) {
                    highlight("Nejlepší den", best.day.weekdayText.capitalizedFirst, best.value.percentText)
                    highlight("Nejhorší den", worst.day.weekdayText.capitalizedFirst, worst.value.percentText)
                }
            }
            if categories.count >= 2, let best = categories.max(by: { $0.rate < $1.rate }),
               let worst = categories.min(by: { $0.rate < $1.rate }) {
                HStack(spacing: 10) {
                    highlight("Nejlepší kategorie", best.category.title, best.rate.percentText)
                    highlight("Nejhorší kategorie", worst.category.title, worst.rate.percentText)
                }
            }
            if let mostFailed, let title = mostFailed.value.first?.title {
                highlight("Nejčastěji nesplněný úkol", title, "\(mostFailed.value.count)× nesplněno")
            }
        }
    }

    private func highlight(_ label: String, _ value: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
        }
        .card(padding: 14)
    }

    @ViewBuilder
    private var excuses: some View {
        let counts = StatisticsService.excuseCounts(weekFailures)
        if !counts.isEmpty {
            VStack(spacing: 10) {
                SectionLabel(text: "Tvoje výmluvy")
                ExcuseList(counts: counts)
            }
        }
    }

    @ViewBuilder
    private var patterns: some View {
        let insights = PatternDetectionService.insights(tasks: closed, failures: weekFailures, plans: weekPlans, now: now)
        if !insights.isEmpty {
            VStack(spacing: 10) {
                SectionLabel(text: "Zjištěné vzorce")
                InsightList(insights: insights)
            }
        }
    }

    @ViewBuilder
    private var selfCritique: some View {
        let records = weekFailures.sorted { $0.date < $1.date }
        if !records.isEmpty {
            let repeated = StatisticsService.excuseCounts(weekFailures).first { $0.count >= 2 }
            VStack(spacing: 10) {
                SectionLabel(text: "Tvoje vlastní slova")
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(records) { record in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(record.taskDate.weekdayText.capitalizedFirst) · \(record.taskTitle)")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                            Text("„\(record.critique)“")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                    if let repeated {
                        Text("„\(repeated.reason.title)“ jsi jako důvod uvedl \(repeated.count)×. Pojmenoval jsi problém a stejně se opakoval.")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.orange)
                    }
                }
                .card()
            }
        }
    }

    /// The single most important takeaway of the week, visually separated from the rest.
    private var truth: some View {
        let highValue = ScoreEngine.completionRate(closed.filter { $0.category.isHighValue })
        let rest = ScoreEngine.completionRate(closed.filter { !$0.category.isHighValue })
        let verdict = truthVerdict
        return VStack(alignment: .leading, spacing: 14) {
            Text("PRAVDA").labelStyle(verdict.color)
            if let rest {
                Text("Sport, čtení a ostatní jsi splnil na \(rest.percentText).")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textPrimary)
            }
            if let highValue {
                Text("To nejdůležitější jsi splnil na \(highValue.percentText).")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textPrimary)
            }
            Text(verdict.text)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(verdict.color)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(verdict.color.opacity(0.5), lineWidth: 1))
    }

    private var truthVerdict: (text: String, color: Color) {
        if ScoreEngine.isBusyNotProductive(closed, now: now) {
            return ("Byl jsi aktivní. Nebyl jsi produktivní.", Theme.red)
        }
        let kept = promisesKept ?? ScoreEngine.completionRate(closed) ?? 0
        let productive = productivity ?? 0
        if kept >= Self.truthGood, productive >= Self.truthGood {
            return ("Dodržel jsi slovo.", Theme.green)
        }
        if kept < Self.truthPoor {
            return ("Většinu toho, co sis slíbil, jsi nedodržel.", Theme.red)
        }
        return ("Slušný týden. Rezervy znáš sám nejlíp.", Theme.orange)
    }
}

struct ExcuseList: View {
    let counts: [StatisticsService.ExcuseCount]

    var body: some View {
        let maximum = counts.first?.count ?? 1
        VStack(spacing: 14) {
            ForEach(counts) { item in
                VStack(spacing: 6) {
                    HStack {
                        Text(item.reason.title)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("\(item.count)×")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    ThinBar(value: Double(item.count) / Double(maximum), color: Theme.red)
                    if item.highValue > 0 {
                        Text("Z toho \(item.highValue)× u toho nejdůležitějšího.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .card()
    }
}

struct InsightList: View {
    let insights: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(insights, id: \.self) { insight in
                Text(insight)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }
}
