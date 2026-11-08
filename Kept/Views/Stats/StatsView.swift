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
    @Query private var exerciseLogs: [ExerciseLog]
    @Query private var purchases: [PointsPurchase]
    @State private var showsShop = false
    @State private var period: StatsPeriod = .week

    private static let longTermDays = 90

    private var range: Range<Date> { period.range() }

    /// Today is judged as a whole; longer periods only on tasks whose outcome is final.
    private func scoped(in range: Range<Date>) -> [TaskItem] {
        let now = Date.now
        let inRange = tasks.filter { range.contains($0.scheduledDate) && $0.countsInScores }
        return period == .today ? inRange : inRange.filter { $0.isClosed(now) }
    }

    private var scoped: [TaskItem] { scoped(in: range) }

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
                    LiquidSegmented(options: StatsPeriod.allCases.map { ($0, $0.title) },
                                    selection: $period, accessibilityLabel: "Období")
                }
                Group {
                    scores
                    counts
                    if period != .today {
                        ConsistencySection(tasks: tasks, period: period,
                                           diaryDays: Set(diary.filter(\.hasWriting).map { $0.day.startOfDay }))
                        TrendSection(tasks: tasks, period: period)
                    }
                    recoveryAndExcuses
                    focusAndGym
                    effort
                    WhenYouKeepCard(tasks: scoped, insights: insights)
                    CategorySection(tasks: scoped)
                    GoalsLeftCard(goals: weekGoals)
                    HabitPathCard(tasks: tasks)
                    RecordsSection(tasks: tasks, sessions: sessions)
                    links
                    FriendsEntryCard()
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 32)
            .animation(.easeOut(duration: 0.25), value: period)
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
            if let change = keptChange {
                Text(change >= 0 ? "O \(change) p. b. víc než \(previousName)" : "O \(-change) p. b. míň než \(previousName)")
                    .scaledFont(.caption, weight: .semibold)
                    .foregroundStyle(change >= 0 ? Theme.green : Theme.orange)
                    .padding(.top, -10)
            }
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
        // Nothing was ever closed: one card instead of tiles of zeros.
        if scoped.allSatisfy({ $0.status == .pending && !$0.isRemoved && !$0.isMissed(now) }) {
            return AnyView(newcomerCard)
        }
        return AnyView(OutcomesCard(tasks: scoped))
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

    /// Patterns always look at the last 90 days, whatever period is selected: they need enough history.
    private var insights: [String] {
        let since = Date.now.startOfDay.addingDays(-Self.longTermDays)
        return PatternDetectionService.insights(
            tasks: tasks.filter { $0.scheduledDate >= since }, failures: failures.filter { $0.taskDate >= since },
            plans: plans.filter { $0.weekEnd > since })
    }

    /// Promises kept now against the period before, in percentage points.
    private var keptChange: Int? {
        let now = Date.now
        guard let current = ScoreEngine.promisesKept(scoped, now: now),
              let previous = ScoreEngine.promisesKept(scoped(in: period.previousRange(now: now)), now: now) else { return nil }
        return Int(((current - previous) * 100).rounded())
    }

    private var previousName: LocalizedStringKey {
        switch period {
        case .today: "včera"
        case .week: "minulý týden"
        case .month: "předchozích 30 dní"
        case .year: "loni ve stejnou dobu"
        }
    }

    private var weekGoals: [WeeklyGoal] {
        let settings = settingsList.first
        return SuggestionService.goals(tasks: tasks, weekStart: Date.now.weekStart) {
            settings?.weeklyTarget(for: $0) ?? $0.defaultWeeklyTarget
        }
    }

    @ViewBuilder
    private var recoveryAndExcuses: some View {
        let recovery = StatisticsService.averageRecovery(tasks: tasks, in: range)
        let counts = StatisticsService.excuseCounts(failures.filter { range.contains($0.taskDate) })
        if recovery != nil || !counts.isEmpty {
            HStack(alignment: .top, spacing: 10) {
                if let recovery {
                    StatTile(label: "Návrat", value: Self.daysText(recovery),
                             caption: String(localized: "Tak rychle ses vracel po slabším dni."))
                }
                if let top = counts.first {
                    NavigationLink {
                        ScrollView {
                            ExcuseList(counts: counts)
                                .padding(.horizontal, Theme.screenPadding)
                                .padding(.vertical, 16)
                        }
                        .screenBackground()
                        .navigationTitle("Výmluvy")
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        StatTile(label: "Výmluvy", value: top.reason.title,
                                 caption: String(localized: "\(top.count)× · klepni pro všechny"))
                    }
                    .buttonStyle(.plain)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private static func daysText(_ days: Double) -> String {
        days < 1.5 ? String(localized: "1 den")
            : String(localized: "\(days.formatted(.number.precision(.fractionLength(0...1)).locale(.app))) dne")
    }

    private static func hoursText(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        return minutes < 60 ? String(localized: "\(minutes) min")
            : String(localized: "\(minutes / 60) h \(minutes % 60) min")
    }

    @ViewBuilder
    private var focusAndGym: some View {
        let focus = StatisticsService.focusSeconds(sessions, in: range)
        let gym = tasks.filter { range.contains($0.scheduledDate) && $0.category == .gym && $0.isDone }.count
        let volume = exerciseLogs.filter { range.contains($0.date) }.reduce(0) { $0 + $1.volume }
        if focus > 0 || gym > 0 {
            HStack(alignment: .top, spacing: 10) {
                StatTile(label: "Soustředění", value: Self.hoursText(focus),
                         caption: String(localized: "čistý čas ve focus timeru"))
                StatTile(label: "Gym", value: "\(gym)×",
                         caption: volume > 0
                            ? String(localized: "tréninků · objem \(volume >= 1000 ? "\((volume / 1000).formatted(.number.precision(.fractionLength(0...1)).locale(.app))) t" : "\(Int(volume)) kg")")
                            : String(localized: "tréninků"))
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Planned time of the period against the time measured by the focus timer.
    @ViewBuilder
    private var effort: some View {
        let planned = tasks.filter { range.contains($0.scheduledDate) && !$0.isRemoved }.reduce(0) { $0 + $1.plannedMinutes }
        let focused = StatisticsService.focusSeconds(sessions, in: range) / 60
        if planned > 0 && focused > 0 {
            VStack(spacing: 10) {
                SectionLabel(text: "Plán vs. skutečnost")
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("\(Self.hoursText(focused * 60)) z \(Self.hoursText(Double(planned) * 60))")
                            .scaledFont(.heading, weight: .bold)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text(min(focused / Double(planned), 1).percentText)
                            .scaledFont(.body, weight: .semibold)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    ThinBar(value: min(focused / Double(planned), 1), color: Theme.textPrimary)
                    Text("Počítá se jen čas odměřený focus timerem.")
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                .card()
            }
        }
    }

    private var links: some View {
        VStack(spacing: 0) {
            Button { showsShop = true } label: {
                StatsRowLabel(symbol: "star.fill", title: "Body a obchod",
                              detail: String(localized: "Zůstatek: \(PointsService.balance(tasks, purchases: purchases, diary: diary))"))
            }
            .buttonStyle(.plain)
            Divider().overlay(Theme.border)
            StatsLinkRow(symbol: TaskCategory.gym.symbol, title: "Gym – progres") { GymProgressView() }
            Divider().overlay(Theme.border)
            StatsLinkRow(symbol: "calendar.badge.checkmark", title: "Přehledy týdnů") { ReviewHistoryView(tasks: tasks) }
            Divider().overlay(Theme.border)
            StatsLinkRow(symbol: "book.closed", title: "Sebereflexe týdne",
                         detail: reflections.isEmpty ? "" : String(localized: "Zápisy: \(reflections.count)")) { JournalView() }
        }
        .card(padding: 0)
        .sheet(isPresented: $showsShop) { ShopView() }
    }
}
