import SwiftUI
import SwiftData
import Charts

/// Optional tab: what Apple Health knows — steps, distance, energy, workouts and weight — with a daily goal,
/// ranges to switch between, days to touch for detail, and the badges Health earns.
struct HealthSummaryView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settingsList: [UserSettings]
    @Query private var tasks: [TaskItem]
    @State private var showsGoalSheet = false
    @State private var summary: HealthService.Summary?
    @State private var isLoading = false
    @State private var metric: Metric = .steps
    @State private var range: Range = .week
    @State private var weightRange: WeightRange = .quarter
    @State private var selectedDay: Date?
    @State private var selectedWeight: Date?
    @AppStorage(HealthStats.key) private var statsData = Data()
    #if DEBUG
    @AppStorage("devHealthDemo") private var devDemo = false
    #endif

    /// True when shown inside another screen's navigation (opened from Settings) instead of as a tab.
    var isEmbedded = false

    private var settings: UserSettings? { settingsList.first }
    private var goal: Int { settings?.stepGoal ?? 8000 }

    private var isDemo: Bool {
        #if DEBUG
        return devDemo
        #else
        return false
        #endif
    }

    // MARK: Choices

    private enum Metric: String, CaseIterable, Identifiable {
        case steps, distance, energy
        var id: String { rawValue }

        var title: LocalizedStringKey {
            switch self {
            case .steps: "Kroky"
            case .distance: "Kilometry"
            case .energy: "Energie"
            }
        }

        /// Spoken instead of the picture of the chart.
        var accessibleName: String {
            switch self {
            case .steps: "kroky"
            case .distance: "kilometry"
            case .energy: "aktivní energie"
            }
        }

        func value(_ day: HealthService.DayMetrics) -> Double {
            switch self {
            case .steps: Double(day.steps)
            case .distance: day.km
            case .energy: Double(day.kcal)
            }
        }

        func text(_ value: Double) -> String {
            switch self {
            case .steps: Int(value).formatted(.number.locale(.app))
            case .distance: "\(value.formatted(.number.precision(.fractionLength(0...1)).locale(.app))) km"
            case .energy: "\(Int(value).formatted(.number.locale(.app))) kcal"
            }
        }
    }

    private enum Range: Int, CaseIterable, Identifiable {
        case week = 7, month = 30, quarter = 90
        var id: Int { rawValue }

        var title: LocalizedStringKey {
            switch self {
            case .week: "7 dní"
            case .month: "30 dní"
            case .quarter: "90 dní"
            }
        }
    }

    private enum WeightRange: Int, CaseIterable, Identifiable {
        case month = 30, quarter = 90, year = 365
        var id: Int { rawValue }

        var title: LocalizedStringKey {
            switch self {
            case .month: "30 dní"
            case .quarter: "90 dní"
            case .year: "Rok"
            }
        }
    }

    // MARK: Body

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
                    .scaledFont(.title, weight: .bold)
                    .foregroundStyle(Theme.textPrimary)
                if !HealthService.isAvailable && !isDemo {
                    info("Apple Health na tomto zařízení není dostupné.")
                } else if settings?.healthEnabled != true && !isDemo {
                    connectCard
                    badgesCard
                } else if let summary {
                    if summary.isEmpty {
                        info("Ze Zdraví zatím nepřišla žádná data. Zkontroluj v aplikaci Zdraví → Sdílení → Aplikace → Kept, že má Kept povolené čtení.")
                    } else {
                        todayCard(summary)
                        trendCard(summary)
                        workouts(summary)
                        weight(summary)
                    }
                    badgesCard
                    Text("Kept data ze Zdraví jen čte a nikam je neposílá.")
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.textTertiary)
                } else {
                    info(isLoading ? "Načítám…" : "Žádná data.")
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 32)
        }
        .screenBackground()
        .refreshable {
            // Pulling the screen down always reads Health again.
            #if DEBUG
            if isDemo { summary = HealthService.demoSummary(); return }
            #endif
            guard settings?.healthEnabled == true else { return }
            summary = await HealthService.summary(keptTrainingDays: keptTrainingDays, force: true)
        }
        .privacyShield()
        .toolbarBackground(Theme.background, for: .navigationBar)
        .task(id: "\(scenePhase == .active)-\(settings?.healthEnabled == true)-\(isDemo)") {
            guard scenePhase == .active else { return }
            #if DEBUG
            if isDemo {
                summary = HealthService.demoSummary()
                return
            }
            #endif
            guard settings?.healthEnabled == true else { return }
            isLoading = true
            // Asking again is harmless: the system only shows its sheet for data types it has not asked about yet.
            _ = await HealthService.requestAccess()
            summary = await HealthService.summary(keptTrainingDays: keptTrainingDays)
            isLoading = false
        }
    }

    private var connectCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Propoj Kept s Apple Health a uvidíš tu kroky, kilometry, tréninky a váhu. Kept data jen čte.")
                .scaledFont(.body)
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
            .scaledFont(.body)
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .card()
    }

    // MARK: Workouts from both sources

    private var keptWorkouts: [TaskItem] {
        guard let settings else { return [] }
        return tasks.filter { $0.isDone && settings.isWorkout($0) }
    }

    private var keptTrainingDays: Set<Date> {
        Set(keptWorkouts.map { ($0.completedAt ?? $0.scheduledDate).startOfDay })
    }

    /// Workouts Health recorded, plus the ones done in Kept on days Health has none of: one workout is not listed twice.
    private func allWorkouts(_ summary: HealthService.Summary) -> [(date: Date, name: String, minutes: Int)] {
        let healthDays = Set(summary.workouts.map { $0.date.startOfDay })
        let kept = keptWorkouts
            .map { (date: $0.completedAt ?? $0.scheduledDate, name: $0.title, minutes: $0.plannedMinutes) }
            .filter { !healthDays.contains($0.date.startOfDay) }
        return (summary.workouts + kept).sorted { $0.date > $1.date }
    }

    // MARK: Today

    private func todayCard(_ summary: HealthService.Summary) -> some View {
        let steps = summary.today?.steps ?? 0
        let reached = steps >= goal
        let streak = goalStreak(summary)
        return VStack(spacing: 16) {
            HStack(spacing: 18) {
                ZStack {
                    GoalRing(progress: Double(steps) / Double(max(goal, 1)), reached: reached)
                    VStack(spacing: 0) {
                        Text(steps.formatted(.number.locale(.app)))
                            .scaledFont(.title, weight: .heavy)
                            .foregroundStyle(reached ? Theme.green : Theme.textPrimary)
                            .contentTransition(.numericText())
                        Text("kroků dnes")
                            .scaledFont(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(width: 128, height: 128)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Dnešní kroky")
                .accessibilityValue("\(steps.formatted(.number.locale(.app))) z \(goal.formatted(.number.locale(.app)))")
                VStack(alignment: .leading, spacing: 10) {
                    goalMenu
                    Text(reached ? "Cíl splněn." : "Do cíle zbývá \((goal - steps).formatted(.number.locale(.app))).")
                        .scaledFont(.body, weight: .semibold)
                        .foregroundStyle(reached ? Theme.green : Theme.textPrimary)
                    if streak > 0 {
                        Label("\(String.days(streak)) v řadě nad cílem", systemImage: "flame.fill")
                            .scaledFont(.caption, weight: .semibold)
                            .foregroundStyle(Theme.orange)
                    }
                }
                Spacer(minLength: 0)
            }
            TileRow {
                MetricTile(value: Metric.distance.text(summary.today?.km ?? 0), label: "Dnes ušlo")
                MetricTile(value: Metric.energy.text(Double(summary.today?.kcal ?? 0)), label: "Aktivní energie")
            }
        }
        .animation(.easeOut(duration: 0.6), value: steps)
    }

    /// The goal is changed right on the card, in a small sheet with a slider.
    private var goalMenu: some View {
        Button {
            Haptics.light()
            showsGoalSheet = true
        } label: {
            HStack(spacing: 4) {
                Text("CÍL \(goal.formatted(.number.locale(.app)))")
                Image(systemName: "slider.horizontal.3").scaledFont(.caption, weight: .bold)
            }
            .scaledFont(.caption, weight: .heavy)
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Theme.cardRaised)
            .clipShape(Capsule())
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Cíl kroků \(goal.formatted(.number.locale(.app)))")
        .accessibilityHint("Otevře nastavení cíle")
        .sheet(isPresented: $showsGoalSheet) {
            StepGoalSheet(goal: goal) { settings?.stepGoal = $0 }
                .presentationDetents([.height(430)])
                .presentationDragIndicator(.visible)
        }
    }

    /// Days in a row up to now with at least the goal. Today does not break it while it is still going.
    private func goalStreak(_ summary: HealthService.Summary) -> Int {
        var count = 0
        for day in summary.days.reversed() {
            if day.steps >= goal { count += 1 }
            else if day.day == summary.days.last?.day { continue }
            else { break }
        }
        return count
    }

    // MARK: Trend

    private func trendCard(_ summary: HealthService.Summary) -> some View {
        let shown = Array(summary.days.suffix(range.rawValue))
        let before = Array(summary.days.dropLast(range.rawValue).suffix(range.rawValue))
        let selected = selectedDay.flatMap { picked in shown.first { $0.day == picked.startOfDay } }
        return VStack(spacing: 10) {
            Picker("Veličina", selection: $metric) {
                ForEach(Metric.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    trendHeader(shown: shown, before: before, selected: selected)
                    Spacer(minLength: 8)
                    rangeChips
                }
                trendChart(shown)
                if let selected {
                    dayDetail(selected, workouts: allWorkouts(summary))
                } else {
                    Text("Přejeď prstem po grafu a uvidíš jednotlivé dny.")
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .card()
            insights(shown: shown, before: before)
        }
        .onChange(of: metric) { _, _ in selectedDay = nil }
        .onChange(of: range) { _, _ in selectedDay = nil }
    }

    /// The period sits in the corner of the chart card as three small chips; the quantity above stays the main switch.
    private var rangeChips: some View {
        HStack(spacing: 4) {
            ForEach(Range.allCases) { option in
                Button {
                    Haptics.light()
                    withAnimation(.easeOut(duration: 0.2)) { range = option }
                } label: {
                    Text("\(option.rawValue)")
                        .scaledFont(.caption, weight: .bold)
                        .foregroundStyle(range == option ? Theme.onPrimary : Theme.textSecondary)
                        .frame(minWidth: 30, minHeight: 28)
                        .padding(.horizontal, 4)
                        .background(range == option ? Theme.textPrimary : Theme.cardRaised)
                        .clipShape(Capsule())
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(option.rawValue) dní")
                .accessibilityAddTraits(range == option ? .isSelected : [])
            }
        }
    }

    private func trendHeader(shown: [HealthService.DayMetrics], before: [HealthService.DayMetrics],
                             selected: HealthService.DayMetrics?) -> some View {
        let average = shown.isEmpty ? 0 : shown.map(metric.value).reduce(0, +) / Double(shown.count)
        return VStack(alignment: .leading, spacing: 2) {
            if let selected {
                Text(metric.text(metric.value(selected)))
                    .scaledFont(.title, weight: .heavy)
                    .foregroundStyle(Theme.textPrimary)
                Text(selected.day.longDayText)
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text(metric.text(average))
                    .scaledFont(.title, weight: .heavy)
                    .foregroundStyle(Theme.textPrimary)
                Text(comparison(average: average, before: before))
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    /// "Průměr za den", compared with the period right before it when there is one to compare with.
    private func comparison(average: Double, before: [HealthService.DayMetrics]) -> String {
        let base = before.isEmpty ? 0 : before.map(metric.value).reduce(0, +) / Double(before.count)
        guard base > 0 else { return "Průměr za den" }
        let change = Int(((average - base) / base * 100).rounded())
        if change == 0 { return "Průměr za den, stejně jako předtím" }
        return change > 0 ? "Průměr za den, o \(change) % víc než předtím" : "Průměr za den, o \(-change) % míň než předtím"
    }

    private func trendChart(_ shown: [HealthService.DayMetrics]) -> some View {
        Chart {
            ForEach(shown, id: \.day) { item in
                BarMark(x: .value("Den", item.day, unit: .day), y: .value("Hodnota", metric.value(item)))
                    .foregroundStyle(barColor(item))
                    .cornerRadius(range == .quarter ? 1 : 3)
            }
            if metric == .steps {
                RuleMark(y: .value("Cíl", goal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Theme.textTertiary)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("cíl")
                            .scaledFont(.caption, weight: .semibold)
                            .foregroundStyle(Theme.textTertiary)
                    }
            }
        }
        .chartXSelection(value: $selectedDay)
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) {
                AxisGridLine().foregroundStyle(Theme.border)
                AxisValueLabel().foregroundStyle(Theme.textSecondary)
            }
        }
        .chartXAxis {
            if range == .week {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date.weekdayShortText.uppercased())
                        }
                    }
                    .foregroundStyle(Theme.textSecondary)
                }
            } else {
                AxisMarks(values: .stride(by: .day, count: range == .month ? 7 : 30)) {
                    AxisValueLabel(format: Date.FormatStyle(locale: .app).day().month(.defaultDigits))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .frame(height: 170)
        .sensoryFeedback(.selection, trigger: selectedDay)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Graf: \(metric.accessibleName) za \(range.rawValue) dní")
        .accessibilityValue(chartSummary(shown))
    }

    /// The chart for VoiceOver: the average, the best day and the latest day, since the bars themselves cannot be read.
    private func chartSummary(_ shown: [HealthService.DayMetrics]) -> String {
        guard let best = shown.max(by: { metric.value($0) < metric.value($1) }), let last = shown.last else { return "Žádná data" }
        let average = shown.map(metric.value).reduce(0, +) / Double(shown.count)
        return "Průměr \(metric.text(average)). Nejlepší den \(best.day.longDayText): \(metric.text(metric.value(best))). Dnes \(metric.text(metric.value(last)))."
    }

    /// Steps above the goal are green; the chosen day stands out and the others fade.
    private func barColor(_ item: HealthService.DayMetrics) -> Color {
        let base = metric == .steps && item.steps >= goal ? Theme.green : Theme.textPrimary
        guard let selectedDay else { return base }
        return item.day == selectedDay.startOfDay ? base : base.opacity(0.3)
    }

    private func dayDetail(_ item: HealthService.DayMetrics, workouts: [(date: Date, name: String, minutes: Int)]) -> some View {
        let trained = workouts.filter { $0.date.isSameDay(as: item.day) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 18) {
                detailFigure(Metric.steps.text(Double(item.steps)), "kroků")
                detailFigure(Metric.distance.text(item.km), "ušlo")
                detailFigure(Metric.energy.text(Double(item.kcal)), "energie")
            }
            ForEach(Array(trained.enumerated()), id: \.offset) { _, workout in
                Label("\(workout.name) · \(workout.minutes) min", systemImage: "figure.run")
                    .scaledFont(.caption, weight: .semibold)
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardRaised)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func detailFigure(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).scaledFont(.body, weight: .bold).foregroundStyle(Theme.textPrimary)
            Text(label).scaledFont(.caption).foregroundStyle(Theme.textSecondary)
        }
    }

    private func insights(shown: [HealthService.DayMetrics], before: [HealthService.DayMetrics]) -> some View {
        let best = shown.max { metric.value($0) < metric.value($1) }
        let total = shown.map(metric.value).reduce(0, +)
        let reachedDays = shown.filter { $0.steps >= goal }.count
        return TileRow {
            MetricTile(value: best.map { metric.text(metric.value($0)) } ?? "—", label: "Nejlepší den")
            if metric == .steps {
                MetricTile(value: "\(reachedDays) / \(shown.count)", label: "Dnů nad cílem",
                           color: reachedDays > 0 ? Theme.green : Theme.textPrimary)
            } else {
                MetricTile(value: metric.text(total), label: "Celkem")
            }
        }
    }

    // MARK: Workouts

    @ViewBuilder
    private func workouts(_ summary: HealthService.Summary) -> some View {
        let from = Date.now.startOfDay.addingDays(-(range.rawValue - 1))
        let shown = allWorkouts(summary).filter { $0.date >= from }
        if !shown.isEmpty {
            let minutes = shown.map(\.minutes).reduce(0, +)
            VStack(spacing: 10) {
                SectionLabel(text: "Tréninky za \(range.rawValue) dní · \(shown.count)× · \(minutes / 60) h \(minutes % 60) min")
                VStack(spacing: 0) {
                    ForEach(Array(shown.prefix(8).enumerated()), id: \.offset) { index, workout in
                        if index > 0 {
                            Divider().overlay(Theme.border)
                        }
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(workout.name)
                                    .scaledFont(.body, weight: .semibold)
                                    .foregroundStyle(Theme.textPrimary)
                                Text("\(workout.date.longDayText) · \(workout.date.timeText)")
                                    .scaledFont(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Text("\(workout.minutes) min")
                                .scaledFont(.body, weight: .bold)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                    }
                    if shown.count > 8 {
                        Divider().overlay(Theme.border)
                        Text("A dalších \(shown.count - 8)")
                            .scaledFont(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.vertical, 10)
                    }
                }
                .card(padding: 0)
            }
        }
    }

    // MARK: Weight

    @ViewBuilder
    private func weight(_ summary: HealthService.Summary) -> some View {
        let from = Date.now.startOfDay.addingDays(-weightRange.rawValue)
        let points = summary.weights.filter { $0.date >= from }
        if let first = points.first, let last = points.last {
            let change = last.kilograms - first.kilograms
            let picked = selectedWeight.flatMap { date in points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) } }
            VStack(spacing: 10) {
                HStack {
                    SectionLabel(text: "Váha")
                    Picker("Období váhy", selection: $weightRange) {
                        ForEach(WeightRange.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                    .onChange(of: weightRange) { _, _ in selectedWeight = nil }
                }
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text((picked?.kilograms ?? last.kilograms).kilogramText)
                            .scaledFont(34, weight: .bold)
                            .foregroundStyle(Theme.textPrimary)
                        if let picked {
                            Text(picked.date.longDayText)
                                .scaledFont(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        } else if points.count > 1 {
                            Text("\(change >= 0 ? "+" : "−")\(abs(change).kilogramText) od \(first.date.dayMonthText)")
                                .scaledFont(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    if points.count > 1 {
                        let values = points.map(\.kilograms)
                        Chart {
                            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                                LineMark(x: .value("Den", point.date), y: .value("kg", point.kilograms))
                                    .foregroundStyle(Theme.textPrimary)
                                    .interpolationMethod(.monotone)
                            }
                            if let picked {
                                PointMark(x: .value("Den", picked.date), y: .value("kg", picked.kilograms))
                                    .foregroundStyle(Theme.green)
                                    .symbolSize(90)
                            }
                        }
                        .chartXSelection(value: $selectedWeight)
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

    // MARK: Badges

    private var healthBadges: [Achievement] {
        #if DEBUG
        if isDemo { return BadgeService.healthBadges(.from(summary ?? HealthService.demoSummary())) }
        #endif
        _ = statsData
        return BadgeService.healthBadges(.stored)
    }

    private var badgesCard: some View {
        let badges = healthBadges
        return VStack(spacing: 10) {
            HStack {
                SectionLabel(text: "Odznaky ze Zdraví")
                Spacer()
                Text("\(badges.filter(\.isEarned).count) / \(badges.count)")
                    .scaledFont(.caption, weight: .bold)
                    .foregroundStyle(Theme.textSecondary)
            }
            VStack(spacing: 0) {
                ForEach(Array(badges.enumerated()), id: \.element.id) { index, badge in
                    if index > 0 { Divider().overlay(Theme.border) }
                    badgeRow(badge)
                }
            }
            .card(padding: 0)
        }
    }

    private func badgeRow(_ badge: Achievement) -> some View {
        HStack(spacing: 12) {
            Image(systemName: badge.symbol)
                .scaledFont(.heading, weight: .semibold)
                .foregroundStyle(badge.isEarned ? Theme.onPrimary : Theme.textTertiary)
                .frame(width: 40, height: 40)
                .background(badge.isEarned ? tierColor(badge.tier) : Theme.cardRaised)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(badge.name)
                    .scaledFont(.body, weight: .semibold)
                    .foregroundStyle(badge.isEarned ? Theme.textPrimary : Theme.textSecondary)
                Text(badge.how)
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !badge.isEarned, let progress = badge.progress {
                    ThinBar(value: Double(min(progress.current, progress.target)) / Double(max(progress.target, 1)),
                            color: Theme.textSecondary)
                }
            }
            Spacer(minLength: 0)
            if badge.isEarned {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
            } else if let progress = badge.progress, progress.current > 0 {
                Text("\(min(progress.current, progress.target).formatted(.number.locale(.app))) / \(progress.target.formatted(.number.locale(.app)))")
                    .scaledFont(.caption, weight: .bold)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }

    private func tierColor(_ tier: BadgeTier) -> Color {
        switch tier {
        case .common: Theme.green
        case .rare: Theme.orange
        case .legendary: Theme.red
        }
    }
}

/// A ring that fills as the day's steps approach the goal and turns green once it is reached.
private struct GoalRing: View {
    let progress: Double
    let reached: Bool

    var body: some View {
        ZStack {
            Circle().stroke(Theme.cardRaised, lineWidth: 12)
            Circle()
                .trim(from: 0, to: min(max(progress, 0.005), 1))
                .stroke(reached ? Theme.green : Theme.textPrimary, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}


/// Picking the daily step goal: a slider from 2 000 to 100 000 that moves in small steps where it matters
/// and bigger ones further out, a few quick choices, and a few friendly words about what the number means.
private struct StepGoalSheet: View {
    let onSave: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var index: Double

    private static let values: [Int] =
        Array(stride(from: 2_000, through: 20_000, by: 500))
        + Array(stride(from: 21_000, through: 50_000, by: 1_000))
        + Array(stride(from: 55_000, through: 100_000, by: 5_000))
    private static let quick = [5_000, 8_000, 10_000, 15_000]

    init(goal: Int, onSave: @escaping (Int) -> Void) {
        self.onSave = onSave
        _index = State(initialValue: Double(Self.nearestIndex(to: goal)))
    }

    private static func nearestIndex(to value: Int) -> Int {
        values.indices.min { abs(values[$0] - value) < abs(values[$1] - value) } ?? 0
    }

    private var value: Int { Self.values[min(max(Int(index.rounded()), 0), Self.values.count - 1)] }

    /// About 0.75 m per step.
    private var kilometres: String {
        (Double(value) * 0.00075).formatted(.number.precision(.fractionLength(0...1)).locale(.app))
    }

    private var mood: LocalizedStringKey {
        switch value {
        case ..<4_000: "Lehký začátek. Hlavně se hýbat."
        case ..<7_000: "Příjemný denní pohyb."
        case ..<10_000: "Zdravý základ, na kterém se dá stavět."
        case ..<15_000: "Aktivní den. Tohle se pozná."
        case ..<25_000: "Sportovní výkon."
        case ..<50_000: "Tempo vytrvalce. Dobře se připrav."
        default: "Extrémní výzva. Jen pro odvážné."
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text("Kolik kroků denně?")
                    .scaledFont(.body, weight: .semibold)
                    .foregroundStyle(Theme.textSecondary)
                Text(value.formatted(.number.locale(.app)))
                    .scaledFont(.hero, weight: .heavy)
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
                Text("≈ \(kilometres) km denně")
                    .scaledFont(.body)
                    .foregroundStyle(Theme.textSecondary)
                Text(mood)
                    .scaledFont(.body, weight: .semibold)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 4)
            }
            .animation(.easeOut(duration: 0.2), value: value)

            HStack(spacing: 12) {
                nudge("minus", by: -1)
                Slider(value: $index, in: 0...Double(Self.values.count - 1), step: 1)
                    .tint(Theme.textPrimary)
                nudge("plus", by: 1)
            }
            HStack {
                Text("2 000").scaledFont(.caption).foregroundStyle(Theme.textTertiary)
                Spacer()
                Text("100 000").scaledFont(.caption).foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 44)
            .padding(.top, -10)

            HStack(spacing: 8) {
                ForEach(Self.quick, id: \.self) { option in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { index = Double(Self.nearestIndex(to: option)) }
                    } label: {
                        Text(option.formatted(.number.locale(.app)))
                            .scaledFont(.caption, weight: .bold)
                            .foregroundStyle(value == option ? Theme.onPrimary : Theme.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(value == option ? Theme.textPrimary : Theme.cardRaised)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            Button("NASTAVIT CÍL") {
                Haptics.success()
                onSave(value)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .screenBackground()
        .appAppearance()
        .sensoryFeedback(.selection, trigger: value)
    }

    private func nudge(_ symbol: String, by step: Int) -> some View {
        Button {
            index = min(max(index + Double(step), 0), Double(Self.values.count - 1))
        } label: {
            Image(systemName: symbol)
                .scaledFont(.body, weight: .bold)
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 32, height: 32)
                .background(Theme.cardRaised)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(step < 0 ? "Míň kroků" : "Víc kroků")
    }
}
