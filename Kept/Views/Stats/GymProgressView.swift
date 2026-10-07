import SwiftUI
import SwiftData
import Charts

/// Everything about training in one place: body weight, what gets trained and what gets skipped, and strength.
struct GymProgressView: View {
    @Query private var tasks: [TaskItem]
    @Query private var settingsList: [UserSettings]
    @State private var healthWeights: [(date: Date, kilograms: Double)] = []
    @State private var selectedLift = ""

    private static let recentDays = 30
    private static let neglectDays = 10
    private static let healthHistoryDays = 365

    private var workouts: [TaskItem] {
        tasks.filter { $0.isDone && $0.category == .gym }
            .sorted { Self.date(of: $0) < Self.date(of: $1) }
    }
    private var recent: [TaskItem] {
        let since = Date.now.startOfDay.addingDays(-Self.recentDays)
        return workouts.filter { Self.date(of: $0) >= since }
    }
    private static func date(of task: TaskItem) -> Date { task.completedAt ?? task.scheduledDate }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                Text("Gym")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                summary
                bodyParts
                strength
                weight
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 32)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .task {
            if settingsList.first?.healthEnabled == true {
                healthWeights = await HealthService.weights(since: Date.now.addingDays(-Self.healthHistoryDays))
            }
        }
    }

    private var summary: some View {
        let thisWeek = workouts.filter { Self.date(of: $0).weekStart == Date.now.weekStart }.count
        let target = settingsList.first?.weeklyTarget(for: .gym) ?? TaskCategory.gym.defaultWeeklyTarget
        return HStack(spacing: 10) {
            MetricTile(value: target > 0 ? "\(thisWeek) / \(target)" : "\(thisWeek)", label: "Tento týden",
                       color: target > 0 && thisWeek >= target ? Theme.green : Theme.textPrimary)
            MetricTile(value: "\(recent.count)", label: "Za 30 dní")
            MetricTile(value: "\(workouts.count)", label: "Celkem")
        }
    }

    // MARK: What gets trained

    @ViewBuilder
    private var bodyParts: some View {
        let presets = settingsList.first?.workoutPresets ?? UserSettings.defaultWorkoutPresets
        let logged = recent.filter { !$0.workoutType.isEmpty }
        let counts = Dictionary(grouping: logged, by: \.workoutType).mapValues(\.count)
        // Presets are listed even with zero sessions: the gaps are the point.
        let names = presets + counts.keys.filter { !presets.contains($0) }.sorted()
        let maximum = max(counts.values.max() ?? 0, 1)
        let lastTrained = Dictionary(grouping: workouts.filter { !$0.workoutType.isEmpty }, by: \.workoutType)
            .mapValues { $0.map(Self.date(of:)).max() ?? .distantPast }

        if !names.isEmpty {
            VStack(spacing: 10) {
                SectionLabel(text: "Co jsi jel za \(Self.recentDays) dní")
                VStack(spacing: 14) {
                    ForEach(names, id: \.self) { name in
                        let count = counts[name] ?? 0
                        VStack(spacing: 6) {
                            HStack {
                                Text(name)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text("\(count)×")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(count == 0 ? Theme.orange : Theme.textPrimary)
                            }
                            ThinBar(value: Double(count) / Double(maximum))
                            if let warning = neglectWarning(name, last: lastTrained[name], isPreset: presets.contains(name)) {
                                Text(warning)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.orange)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    let abs = recent.filter(\.workoutAbs).count
                    HStack {
                        Text("Břicho")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("\(abs)× z \(recent.count) tréninků")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .card()
            }
        }
    }

    private func neglectWarning(_ name: String, last: Date?, isPreset: Bool) -> String? {
        guard isPreset, !workouts.isEmpty else { return nil }
        guard let last else { return "Tohle jsi ještě nikdy nejel." }
        let days = Calendar.app.dateComponents([.day], from: last.startOfDay, to: Date.now.startOfDay).day ?? 0
        return days >= Self.neglectDays ? "Naposledy před \(days) dny. Vynecháváš to." : nil
    }

    // MARK: Strength

    private struct LiftEntry: Identifiable {
        let date: Date
        let weight: Double
        let reps: Int
        var id: Date { date }
    }

    private var lifts: [String: [LiftEntry]] {
        let logged = workouts.compactMap { task -> (String, LiftEntry)? in
            guard !task.liftName.isEmpty, let weight = task.liftWeight else { return nil }
            return (task.liftName, LiftEntry(date: Self.date(of: task), weight: weight, reps: task.liftReps))
        }
        return Dictionary(grouping: logged, by: { $0.0 }).mapValues { $0.map(\.1) }
    }

    @ViewBuilder
    private var strength: some View {
        let all = lifts
        let names = all.keys.sorted()
        VStack(spacing: 10) {
            SectionLabel(text: "Síla")
            if names.isEmpty {
                Text("Při zápisu tréninku vyplň hlavní cvik a váhu na čince. Tady pak uvidíš, jak sílíš.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .card()
            } else {
                let current = names.contains(selectedLift) ? selectedLift : names[0]
                let entries = all[current] ?? []
                VStack(alignment: .leading, spacing: 16) {
                    if names.count > 1 {
                        Picker("Cvik", selection: Binding(get: { current }, set: { selectedLift = $0 })) {
                            ForEach(names, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .tint(.white)
                    } else {
                        Text(current)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    if let first = entries.first, let last = entries.last {
                        let best = entries.map(\.weight).max() ?? last.weight
                        HStack(spacing: 10) {
                            MetricTile(value: last.weight.kilogramText, label: last.reps > 0 ? "Naposledy × \(last.reps)" : "Naposledy")
                            MetricTile(value: best.kilogramText, label: "Maximum")
                            MetricTile(value: "\(last.weight >= first.weight ? "+" : "−")\(abs(last.weight - first.weight).kilogramText)",
                                       label: "Od začátku",
                                       color: last.weight > first.weight ? Theme.green : Theme.textPrimary)
                        }
                        if entries.count > 1 {
                            lineChart(entries.map { ($0.date, $0.weight) })
                        }
                    }
                }
                .card()
            }
        }
    }

    // MARK: Body weight

    @ViewBuilder
    private var weight: some View {
        let logged = tasks.compactMap { task -> (Date, Double)? in
            guard let weight = task.bodyWeight, task.isDone else { return nil }
            return (Self.date(of: task), weight)
        }
        let entries = (logged + healthWeights.map { ($0.date, $0.kilograms) }).sorted { $0.0 < $1.0 }
        if let first = entries.first, let last = entries.last {
            let change = last.1 - first.1
            VStack(spacing: 10) {
                SectionLabel(text: "Tělesná váha")
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(last.1.kilogramText)
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        if entries.count > 1 {
                            Text("\(change >= 0 ? "+" : "−")\(abs(change).kilogramText) od \(first.0.dayMonthText)")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    if entries.count > 1 {
                        lineChart(entries)
                    } else {
                        Text("Graf se ukáže po druhém zápisu váhy.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    if !healthWeights.isEmpty {
                        Text("Včetně měření z Apple Health.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .card()
            }
        }
    }

    private func lineChart(_ points: [(Date, Double)]) -> some View {
        let values = points.map(\.1)
        let low = (values.min() ?? 0) - 1
        let high = (values.max() ?? 0) + 1
        return Chart(Array(points.enumerated()), id: \.offset) { _, point in
            LineMark(x: .value("Den", point.0), y: .value("kg", point.1))
                .foregroundStyle(Theme.textPrimary)
                .interpolationMethod(.monotone)
            PointMark(x: .value("Den", point.0), y: .value("kg", point.1))
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
    }
}
