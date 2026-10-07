import SwiftUI
import Charts

struct StreaksSection: View {
    let tasks: [TaskItem]

    var body: some View {
        VStack(spacing: 10) {
            SectionLabel(text: "Série")
            HStack(spacing: 10) {
                MetricTile(value: "\(ScoreEngine.dayStreak(tasks))", label: "Dní nad 80 %")
                MetricTile(value: "\(StatisticsService.perfectDayStreak(tasks))", label: "Perfektní dny")
                MetricTile(value: "\(StatisticsService.weeklyPromiseStreak(tasks))", label: "Týdny nad 80 %")
            }
        }
    }
}

/// Daily productivity over the last 7 / 30 / 90 days.
struct TrendSection: View {
    let tasks: [TaskItem]
    @State private var days = 30

    private static let options = [7, 30, 90]

    var body: some View {
        let scores = StatisticsService.dailyScores(tasks: tasks, from: Date.now.startOfDay.addingDays(-days + 1), days: days)
            .compactMap { score in score.productivity.map { (day: score.day, value: $0 * 100) } }
        VStack(spacing: 10) {
            SectionLabel(text: "Trend produktivity")
            VStack(spacing: 14) {
                Picker("Rozsah", selection: $days) {
                    ForEach(Self.options, id: \.self) { Text("\($0) dní").tag($0) }
                }
                .pickerStyle(.segmented)
                if scores.count >= 2 {
                    Chart(scores, id: \.day) { score in
                        LineMark(x: .value("Den", score.day), y: .value("Produktivita", score.value))
                            .foregroundStyle(Theme.textPrimary)
                            .interpolationMethod(.monotone)
                        RuleMark(y: .value("Cíl", ScoreEngine.Config.streakThreshold * 100))
                            .foregroundStyle(Theme.textTertiary)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    .chartYScale(domain: 0...100)
                    .chartXAxis {
                        // Whole-day steps, so a short history doesn't repeat the same date.
                        AxisMarks(values: .stride(by: .day, count: max(1, days / 4))) {
                            AxisValueLabel(format: Date.FormatStyle(locale: .app).day().month(.defaultDigits))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: [0, 50, 100]) {
                            AxisGridLine().foregroundStyle(Theme.border)
                            AxisValueLabel().foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .frame(height: 180)
                } else {
                    Text("Trend se ukáže, až budeš mít aspoň dva dny s úkoly.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .card()
        }
    }
}

struct CategorySection: View {
    let tasks: [TaskItem]

    var body: some View {
        let rates = StatisticsService.categoryPerformance(tasks)
        if !rates.isEmpty {
            VStack(spacing: 10) {
                SectionLabel(text: "Kategorie")
                VStack(spacing: 14) {
                    ForEach(rates) { item in
                        VStack(spacing: 6) {
                            HStack {
                                Label(item.category.title, systemImage: item.category.symbol)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Theme.textPrimary)
                                Text("\(item.count)×")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer()
                                Text(item.rate.percentText)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            ThinBar(value: item.rate, color: Theme.performanceColor(item.rate))
                        }
                    }
                }
                .card()
            }
        }
    }
}

/// Links to the Weekly Review of every week that has tasks, newest first.
struct ReviewHistorySection: View {
    let tasks: [TaskItem]

    var body: some View {
        let now = Date.now
        let weeks = Set(tasks.map { $0.scheduledDate.weekStart }).filter { $0 <= now }.sorted(by: >)
        if !weeks.isEmpty {
            VStack(spacing: 10) {
                SectionLabel(text: "Přehledy týdnů")
                VStack(spacing: 0) {
                    ForEach(Array(weeks.enumerated()), id: \.element) { index, week in
                        if index > 0 {
                            Divider().overlay(Theme.border)
                        }
                        NavigationLink {
                            WeeklyReviewView(weekStart: week)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Týden \(week.weekNumber)")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("\(week.dayMonthText) – \(week.addingDays(6).dayMonthText)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                                Text(ScoreEngine.promisesKept(tasks.filter { $0.scheduledDate.weekStart == week }, now: now).percentText)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                        }
                    }
                }
                .card(padding: 0)
            }
        }
    }
}

/// Planned task time against time actually spent in the focus timer.
struct EffortSection: View {
    let tasks: [TaskItem]
    let sessions: [FocusSession]

    private static let weeks = 6

    private static func hours(_ minutes: Int) -> String {
        "\(minutes / 60) h \(String(format: "%02d", minutes % 60)) min"
    }

    var body: some View {
        let effort = StatisticsService.effort(tasks: tasks, sessions: sessions, weeks: Self.weeks)
        if let current = effort.last, effort.contains(where: { $0.plannedMinutes > 0 }) {
            let ratio = current.plannedMinutes > 0 ? Double(current.focusedMinutes) / Double(current.plannedMinutes) : nil
            VStack(spacing: 10) {
                SectionLabel(text: "Plán vs. skutečnost")
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        MetricTile(value: Self.hours(current.plannedMinutes), label: "Plán tento týden")
                        MetricTile(value: Self.hours(current.focusedMinutes), label: "Soustředění")
                    }
                    PerformanceBar(label: "Odpracováno z plánu", value: ratio.map { min($0, 1) })
                    Chart(effort) { week in
                        BarMark(x: .value("Týden", "T\(week.weekStart.weekNumber)"),
                                y: .value("Hodiny", Double(week.plannedMinutes) / 60))
                            .foregroundStyle(by: .value("Typ", "Plán"))
                            .position(by: .value("Typ", "Plán"))
                        BarMark(x: .value("Týden", "T\(week.weekStart.weekNumber)"),
                                y: .value("Hodiny", Double(week.focusedMinutes) / 60))
                            .foregroundStyle(by: .value("Typ", "Soustředění"))
                            .position(by: .value("Typ", "Soustředění"))
                    }
                    .chartForegroundStyleScale(["Plán": Theme.textTertiary, "Soustředění": Theme.textPrimary])
                    .chartXAxis { AxisMarks { AxisValueLabel().foregroundStyle(Theme.textSecondary) } }
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 3)) {
                            AxisGridLine().foregroundStyle(Theme.border)
                            AxisValueLabel().foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .chartLegend(position: .bottom, alignment: .leading)
                    .frame(height: 170)
                    Text("Počítá se jen čas odměřený focus timerem.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
                .card()
            }
        }
    }
}

struct RecordsSection: View {
    let tasks: [TaskItem]
    let sessions: [FocusSession]

    var body: some View {
        let records = StatisticsService.records(tasks: tasks, sessions: sessions)
        if !records.isEmpty {
            VStack(spacing: 10) {
                SectionLabel(text: "Osobní rekordy")
                VStack(spacing: 0) {
                    ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                        if index > 0 {
                            Divider().overlay(Theme.border)
                        }
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(record.label)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(record.detail)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Text(record.value)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                }
                .card(padding: 0)
            }
        }
    }
}

/// Entry point to the journal of weekly reflections.
struct JournalLinkSection: View {
    let count: Int

    var body: some View {
        NavigationLink {
            JournalView()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("DENÍČEK").labelStyle(Theme.textPrimary)
                    Text(count == 0 ? "První zápis vznikne v neděli večer" : "Zápisy: \(count)")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
            }
            .card()
        }
    }
}
