import SwiftUI

/// The period the Stats screen looks at. Every card counts over it.
enum StatsPeriod: String, CaseIterable, Identifiable {
    case today, week, month, year
    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .today: "Dnes"
        case .week: "Týden"
        case .month: "Měsíc"
        case .year: "Rok"
        }
    }

    private static let monthDays = 30

    func range(now: Date = .now) -> Range<Date> {
        switch self {
        case .today: return now.startOfDay..<now.endOfDay
        case .week: return now.weekStart..<now.weekStart.addingDays(7)
        case .month: return now.startOfDay.addingDays(-Self.monthDays + 1)..<now.endOfDay
        case .year:
            let start = Calendar.app.dateInterval(of: .year, for: now)?.start ?? now.startOfDay
            return start..<now.endOfDay
        }
    }

    /// The same stretch of time just before, to compare with.
    func previousRange(now: Date = .now) -> Range<Date> {
        let current = range(now: now)
        switch self {
        case .today: return current.lowerBound.addingDays(-1)..<current.lowerBound
        case .week: return current.lowerBound.addingDays(-7)..<current.lowerBound
        case .month: return current.lowerBound.addingDays(-Self.monthDays)..<current.lowerBound
        case .year:
            let start = Calendar.app.date(byAdding: .year, value: -1, to: current.lowerBound) ?? current.lowerBound
            let end = Calendar.app.date(byAdding: .year, value: -1, to: current.upperBound) ?? current.lowerBound
            return start..<end
        }
    }
}

/// How many days you kept your word, coloured by productivity: the week as seven days, a month as a calendar
/// you can page through, the year as twelve months that open into their days. The streaks sit underneath.
struct ConsistencySection: View {
    let tasks: [TaskItem]
    let period: StatsPeriod
    /// Days with a diary entry get a small dot.
    var diaryDays: Set<Date> = []

    /// First day of the month shown in the month view.
    @State private var month = ConsistencySection.monthStart(of: .now)
    @State private var year = Calendar.app.component(.year, from: .now)
    /// The month opened under the year grid.
    @State private var openMonth: Date? = ConsistencySection.monthStart(of: .now)
    @State private var selectedDay: DayRequest?

    private static let weekdayLabels = ["PO", "ÚT", "ST", "ČT", "PÁ", "SO", "NE"]
    private static let daysInWeek = 7

    private static func monthStart(of date: Date) -> Date {
        Calendar.app.dateInterval(of: .month, for: date)?.start ?? date.startOfDay
    }

    private static func color(_ value: Double?) -> Color {
        guard let value else { return Theme.cardRaised }
        if value >= Theme.goodThreshold { return Theme.green.opacity(0.45 + 0.55 * value) }
        if value >= Theme.poorThreshold { return Theme.orange.opacity(0.75) }
        return Theme.red.opacity(0.85 - 0.5 * value)
    }

    private var currentMonth: Date { Self.monthStart(of: .now) }
    private var currentYear: Int { Calendar.app.component(.year, from: .now) }
    /// Browsing back stops at the month of the very first task.
    private var earliest: Date { Self.monthStart(of: tasks.map(\.scheduledDate).min() ?? .now) }

    private static func dayCount(_ month: Date) -> Int {
        Calendar.app.range(of: .day, in: .month, for: month)?.count ?? 30
    }

    var body: some View {
        VStack(spacing: 10) {
            SectionLabel(text: "Konzistence")
            VStack(alignment: .leading, spacing: 14) {
                switch period {
                case .today: EmptyView()
                case .week: weekView
                case .month: monthView
                case .year: yearView
                }
                streaks
                Text("Jedno zaváhání nic nekazí. Škodí až časté vynechávání, proto tu vidíš, kolik dní, ne jen sérii.")
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .card()
        }
        .sheet(item: $selectedDay) { DayDetailView(day: $0.day) }
    }

    private func headline(_ counts: (kept: Int, judged: Int)) -> some View {
        Group {
            if counts.judged == 0 {
                Text("Zatím tu není žádný den k hodnocení.")
                    .scaledFont(.body)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(counts.kept) / \(counts.judged)")
                        .scaledFont(.title, weight: .heavy)
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())
                    Text("dodržených dní")
                        .scaledFont(.body)
                        .foregroundStyle(Theme.textSecondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var streaks: some View {
        let streak = ScoreEngine.dayStreak(tasks)
        let perfect = StatisticsService.perfectDayStreak(tasks)
        let weeks = StatisticsService.weeklyPromiseStreak(tasks)
        return Text("Série \(String.days(streak)) · perfektní dny v řadě: \(perfect) · týdny nad 80 %: \(weeks)")
            .scaledFont(.caption)
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Week

    private var weekView: some View {
        let start = Date.now.weekStart
        let elapsed = min(Self.daysInWeek, (Calendar.app.dateComponents([.day], from: start, to: Date.now.startOfDay).day ?? 0) + 1)
        return VStack(alignment: .leading, spacing: 10) {
            headline(StatisticsService.keptDays(tasks: tasks, from: start, days: elapsed))
            weekdayHeader
            grid(StatisticsService.dailyScores(tasks: tasks, from: start, days: Self.daysInWeek), leading: 0,
                 spacing: 4, showsNumbers: true)
        }
    }

    // MARK: Month

    private var monthView: some View {
        let days = month == currentMonth
            ? Calendar.app.component(.day, from: .now) : Self.dayCount(month)
        return VStack(spacing: 10) {
            stepper(title: month.formatted(Date.FormatStyle(locale: .app).month(.wide).year()).capitalizedFirst,
                    canGoBack: month > earliest, canGoForward: month < currentMonth,
                    back: { shiftMonth(-1) }, forward: { shiftMonth(1) })
            headline(StatisticsService.keptDays(tasks: tasks, from: month, days: days))
                .frame(maxWidth: .infinity, alignment: .leading)
            weekdayHeader
            monthGrid(month)
            Text("Klepni na den a uvidíš, co jsi ten den udělal.")
                .scaledFont(.caption)
                .foregroundStyle(Theme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func shiftMonth(_ delta: Int) {
        Haptics.light()
        withAnimation(.easeOut(duration: 0.2)) {
            month = Calendar.app.date(byAdding: .month, value: delta, to: month) ?? month
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(Self.weekdayLabels, id: \.self) { label in
                Text(label)
                    .scaledFont(.caption, weight: .semibold)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// One month as a Monday-first grid with day numbers.
    private func monthGrid(_ start: Date) -> some View {
        let scores = StatisticsService.dailyScores(tasks: tasks, from: start, days: Self.dayCount(start))
        // Calendar weekdays run 1 = Sunday … 7 = Saturday; the grid starts on Monday.
        let leading = (Calendar.app.component(.weekday, from: start) + 5) % Self.daysInWeek
        return grid(scores, leading: leading, spacing: 4, showsNumbers: true)
    }

    private func grid(_ scores: [StatisticsService.DayScore], leading: Int, spacing: CGFloat, showsNumbers: Bool) -> some View {
        let today = Date.now.startOfDay
        let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: Self.daysInWeek)
        return LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(0..<leading, id: \.self) { _ in
                Color.clear.aspectRatio(1, contentMode: .fit)
            }
            ForEach(scores) { score in
                let isFuture = score.day > today
                RoundedRectangle(cornerRadius: 7)
                    .fill(isFuture ? Color.clear : Self.color(score.productivity))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Text("\(Calendar.app.component(.day, from: score.day))")
                            .scaledFont(.caption, weight: score.day == today ? .heavy : .medium)
                            .foregroundStyle(isFuture ? Theme.textTertiary : Theme.textPrimary)
                            .overlay(alignment: .bottom) {
                                if diaryDays.contains(score.day) {
                                    Circle().fill(Theme.textPrimary).frame(width: 4, height: 4).offset(y: 7)
                                }
                            }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(score.day == today ? Theme.textPrimary : (isFuture ? Theme.border : .clear),
                                    lineWidth: score.day == today ? 1.5 : 1)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !isFuture { selectedDay = DayRequest(day: score.day) }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(score.day.longDayText)
                    .accessibilityValue(score.productivity.map(\.percentText) ?? "bez úkolů")
                    .accessibilityAddTraits(isFuture ? [] : .isButton)
            }
        }
    }

    // MARK: Year

    private var yearView: some View {
        let firstYear = Calendar.app.component(.year, from: earliest)
        let months = (1...12).compactMap { Calendar.app.date(from: DateComponents(year: year, month: $0, day: 1)) }
        let yearStart = months.first ?? .now
        let judgedDays = year == currentYear
            ? (Calendar.app.dateComponents([.day], from: yearStart, to: Date.now.startOfDay).day ?? 0) + 1
            : (Calendar.app.range(of: .day, in: .year, for: yearStart)?.count ?? 365)
        return VStack(alignment: .leading, spacing: 12) {
            stepper(title: String(year), canGoBack: year > firstYear, canGoForward: year < currentYear,
                    back: { Haptics.light(); year -= 1; openMonth = nil },
                    forward: { Haptics.light(); year += 1; openMonth = nil })
            headline(StatisticsService.keptDays(tasks: tasks, from: yearStart, days: judgedDays))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(months, id: \.self) { start in
                    monthTile(start)
                }
            }
            if let openMonth, months.contains(openMonth) {
                VStack(alignment: .leading, spacing: 10) {
                    Divider().overlay(Theme.border)
                    Text(openMonth.formatted(Date.FormatStyle(locale: .app).month(.wide)).capitalizedFirst)
                        .scaledFont(.heading, weight: .bold)
                        .foregroundStyle(Theme.textPrimary)
                    weekdayHeader
                    monthGrid(openMonth)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text("Klepni na měsíc a rozbalí se jeho dny.")
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private func monthTile(_ start: Date) -> some View {
        let isFuture = start > currentMonth
        let days = start == currentMonth ? Calendar.app.component(.day, from: .now) : Self.dayCount(start)
        let counts = StatisticsService.keptDays(tasks: tasks, from: start, days: days)
        let share = counts.judged == 0 ? nil : Double(counts.kept) / Double(counts.judged)
        let isOpen = openMonth == start
        let name = start.formatted(Date.FormatStyle(locale: .app).month(.abbreviated)).capitalizedFirst
        return Button {
            guard !isFuture else { return }
            Haptics.light()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { openMonth = isOpen ? nil : start }
        } label: {
            VStack(spacing: 2) {
                Text(name)
                    .scaledFont(.caption, weight: .bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(share.map(\.percentText) ?? "–")
                    .scaledFont(.caption)
            }
            .foregroundStyle(isFuture ? Theme.textTertiary : Theme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(share.map { Theme.performanceColor($0).opacity(0.25 + 0.5 * $0) } ?? (isFuture ? Color.clear : Theme.cardRaised))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isOpen ? Theme.textPrimary : (isFuture ? Theme.border : .clear),
                                  style: StrokeStyle(lineWidth: isOpen ? 1.5 : 1, dash: isFuture ? [4, 3] : []))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(start.formatted(Date.FormatStyle(locale: .app).month(.wide)))
        .accessibilityValue(share.map { "dny nad 80 %: \($0.percentText)" } ?? "bez dat")
        .accessibilityAddTraits(isOpen ? .isSelected : [])
    }

    // MARK: Shared pieces

    private func stepper(title: String, canGoBack: Bool, canGoForward: Bool,
                         back: @escaping () -> Void, forward: @escaping () -> Void) -> some View {
        HStack {
            arrow("chevron.left", enabled: canGoBack, label: "Předchozí", action: back)
            Spacer()
            Text(title)
                .scaledFont(.heading, weight: .bold)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            arrow("chevron.right", enabled: canGoForward, label: "Další", action: forward)
        }
    }

    private func arrow(_ symbol: String, enabled: Bool, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .scaledFont(.body, weight: .semibold)
                .foregroundStyle(enabled ? Theme.textPrimary : Theme.textTertiary)
                .frame(width: 44, height: 36)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
