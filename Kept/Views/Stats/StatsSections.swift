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
                                Text(item.category.title)
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
