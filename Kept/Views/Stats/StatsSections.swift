import SwiftUI
import Charts

/// Productivity over the period chosen at the top: the days of the week or of the last 30 days,
/// or the months of the year.
struct TrendSection: View {
    let tasks: [TaskItem]
    let period: StatsPeriod

    private struct Point: Identifiable {
        let date: Date
        let value: Double
        var id: Date { date }
    }

    private var points: [Point] {
        let now = Date.now
        if period == .year {
            return StatisticsService.monthlyScores(tasks: tasks, year: Calendar.app.component(.year, from: now), now: now)
                .compactMap { item in item.value.map { Point(date: item.month, value: $0 * 100) } }
        }
        let range = period.range(now: now)
        let days = max(1, Calendar.app.dateComponents([.day], from: range.lowerBound, to: range.upperBound).day ?? 7)
        // A day that is still running would end the line on a low point only because the evening has not happened yet,
        // so today joins the trend once nothing in it is left open.
        let todayIsOpen = tasks.contains { !$0.isRemoved && $0.countsInScores && $0.status == .pending && $0.scheduledDate.isSameDay(as: now) }
        return StatisticsService.dailyScores(tasks: tasks, from: range.lowerBound, days: days)
            .filter { !(todayIsOpen && $0.day.isSameDay(as: now)) }
            .compactMap { score in score.productivity.map { Point(date: score.day, value: $0 * 100) } }
    }

    var body: some View {
        let points = points
        VStack(spacing: 10) {
            SectionLabel(text: "Trend produktivity")
            VStack(alignment: .leading, spacing: 10) {
                if points.count >= 2 {
                    Chart(points) { point in
                        LineMark(x: .value("Den", point.date), y: .value("Produktivita", point.value))
                            .foregroundStyle(Theme.textPrimary)
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Den", point.date), y: .value("Produktivita", point.value))
                            .foregroundStyle(Theme.textPrimary)
                            .symbolSize(period == .month ? 0 : 24)
                        RuleMark(y: .value("Cíl", ScoreEngine.Config.streakThreshold * 100))
                            .foregroundStyle(Theme.textTertiary)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    .chartYScale(domain: 0...100)
                    .chartXAxis {
                        if period == .year {
                            AxisMarks(values: .stride(by: .month, count: 2)) {
                                AxisValueLabel(format: Date.FormatStyle(locale: .app).month(.abbreviated))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        } else {
                            AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 7)) {
                                AxisValueLabel(format: Date.FormatStyle(locale: .app).day().month(.defaultDigits))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: [0, 50, 100]) {
                            AxisGridLine().foregroundStyle(Theme.border)
                            AxisValueLabel().foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .frame(height: 170)
                    Text("Čárkovaně je hranice série 80 %.")
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.textTertiary)
                } else {
                    Text("Trend se ukáže, až budeš mít aspoň dva dny s úkoly.")
                        .scaledFont(.caption)
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
                                Label(item.category.title, systemImage: item.category.icon)
                                    .scaledFont(.body)
                                    .foregroundStyle(Theme.textPrimary)
                                Text("\(item.count)×")
                                    .scaledFont(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer()
                                Text(item.rate.percentText)
                                    .scaledFont(.body, weight: .semibold)
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
                                        .scaledFont(.body, weight: .semibold)
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("\(week.dayMonthText) – \(week.addingDays(6).dayMonthText)")
                                        .scaledFont(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                                Text(ScoreEngine.promisesKept(tasks.filter { $0.scheduledDate.weekStart == week }, now: now).percentText)
                                    .scaledFont(.body, weight: .semibold)
                                    .foregroundStyle(Theme.textPrimary)
                                Image(systemName: "chevron.right")
                                    .scaledFont(.caption)
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
                                    .scaledFont(.body, weight: .semibold)
                                    .foregroundStyle(Theme.textPrimary)
                                Text(record.detail)
                                    .scaledFont(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Text(record.value)
                                .scaledFont(.heading, weight: .bold)
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
