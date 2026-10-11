import SwiftUI
import SwiftData
import Charts

/// Optional tab: a read-only summary of what Apple Health knows — steps, energy, workouts and weight.
struct HealthSummaryView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settingsList: [UserSettings]
    @State private var summary: HealthService.Summary?
    @State private var isLoading = false

    /// True when shown inside another screen's navigation (opened from Settings) instead of as a tab.
    var isEmbedded = false

    private var settings: UserSettings? { settingsList.first }

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
                Text("Zdraví")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                if !HealthService.isAvailable {
                    info("Apple Health na tomto zařízení není dostupné.")
                } else if settings?.healthEnabled != true {
                    connectCard
                } else if let summary {
                    if summary.isEmpty {
                        info("Ze Zdraví zatím nepřišla žádná data. Zkontroluj v aplikaci Zdraví → Sdílení → Aplikace → Kept, že má Kept povolené čtení.")
                    } else {
                        today(summary)
                        steps(summary)
                        workouts(summary)
                        weight(summary)
                    }
                    Text("Kept data ze Zdraví jen čte a nikam je neposílá.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                } else {
                    info(isLoading ? "Načítám…" : "Žádná data.")
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 32)
        }
        .screenBackground()
        .toolbarBackground(Theme.background, for: .navigationBar)
        .task(id: "\(scenePhase == .active)-\(settings?.healthEnabled == true)") {
            guard scenePhase == .active, settings?.healthEnabled == true else { return }
            isLoading = true
            summary = await HealthService.summary()
            isLoading = false
        }
    }

    private var connectCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Propoj Kept s Apple Health a uvidíš tu kroky, tréninky a váhu. Kept data jen čte.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Button("PROPOJIT SE ZDRAVÍM") {
                Task {
                    await HealthService.requestAccess()
                    settings?.healthEnabled = true
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .card()
    }

    private func info(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .card()
    }

    private func today(_ summary: HealthService.Summary) -> some View {
        HStack(spacing: 10) {
            MetricTile(value: summary.stepsToday.map { "\($0.formatted(.number.locale(.app)))" } ?? "—", label: "Kroky dnes")
            MetricTile(value: summary.energyToday.map { "\($0) kcal" } ?? "—", label: "Aktivní energie")
            MetricTile(value: "\(summary.workouts.count)", label: "Tréninky za 7 dní")
        }
    }

    @ViewBuilder
    private func steps(_ summary: HealthService.Summary) -> some View {
        if summary.dailySteps.contains(where: { $0.steps > 0 }) {
            let average = summary.dailySteps.map(\.steps).reduce(0, +) / max(summary.dailySteps.count, 1)
            VStack(spacing: 10) {
                SectionLabel(text: "Kroky za 7 dní")
                VStack(alignment: .leading, spacing: 12) {
                    Text("Průměr \(average.formatted(.number.locale(.app))) kroků denně")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                    Chart(summary.dailySteps, id: \.day) { item in
                        BarMark(x: .value("Den", item.day.weekdayShortText.uppercased()), y: .value("Kroky", item.steps))
                            .foregroundStyle(Theme.textPrimary)
                            .cornerRadius(3)
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 3)) {
                            AxisGridLine().foregroundStyle(Theme.border)
                            AxisValueLabel().foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .chartXAxis { AxisMarks { AxisValueLabel().foregroundStyle(Theme.textSecondary) } }
                    .frame(height: 150)
                }
                .card()
            }
        }
    }

    @ViewBuilder
    private func workouts(_ summary: HealthService.Summary) -> some View {
        if !summary.workouts.isEmpty {
            let minutes = summary.workouts.map(\.minutes).reduce(0, +)
            VStack(spacing: 10) {
                SectionLabel(text: "Tréninky za 7 dní · \(minutes / 60) h \(minutes % 60) min")
                VStack(spacing: 0) {
                    ForEach(Array(summary.workouts.enumerated()), id: \.offset) { index, workout in
                        if index > 0 {
                            Divider().overlay(Theme.border)
                        }
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(workout.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text("\(workout.date.longDayText) · \(workout.date.timeText)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Text("\(workout.minutes) min")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                    }
                }
                .card(padding: 0)
            }
        }
    }

    @ViewBuilder
    private func weight(_ summary: HealthService.Summary) -> some View {
        if let first = summary.weights.first, let last = summary.weights.last {
            let change = last.kilograms - first.kilograms
            VStack(spacing: 10) {
                SectionLabel(text: "Váha za 90 dní")
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(last.kilograms.kilogramText)
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        if summary.weights.count > 1 {
                            Text("\(change >= 0 ? "+" : "−")\(abs(change).kilogramText) od \(first.date.dayMonthText)")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    if summary.weights.count > 1 {
                        let values = summary.weights.map(\.kilograms)
                        Chart(Array(summary.weights.enumerated()), id: \.offset) { _, point in
                            LineMark(x: .value("Den", point.date), y: .value("kg", point.kilograms))
                                .foregroundStyle(Theme.textPrimary)
                                .interpolationMethod(.monotone)
                        }
                        .chartYScale(domain: ((values.min() ?? 0) - 1)...((values.max() ?? 0) + 1))
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
                        .frame(height: 160)
                    }
                }
                .card()
            }
        }
    }
}
