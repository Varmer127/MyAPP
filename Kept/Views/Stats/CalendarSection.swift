import SwiftUI

/// Days coloured by productivity: the current month by default, or the whole calendar year as twelve small months.
struct CalendarSection: View {
    let tasks: [TaskItem]

    private enum Mode: String, CaseIterable, Identifiable {
        case month = "Měsíc", year = "Rok"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .month
    /// First day of the month shown in month mode.
    @State private var month = CalendarSection.monthStart(of: .now)
    @State private var year = Calendar.app.component(.year, from: .now)
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

    var body: some View {
        VStack(spacing: 10) {
            SectionLabel(text: "Kalendář")
            VStack(alignment: .leading, spacing: 14) {
                Picker("Zobrazení", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                switch mode {
                case .month: monthView
                case .year: yearView
                }
                HStack(spacing: 12) {
                    legend(Theme.cardRaised, "bez úkolů")
                    legend(Theme.red.opacity(0.7), "pod 50 %")
                    legend(Theme.orange.opacity(0.75), "50–80 %")
                    legend(Theme.green, "nad 80 %")
                }
            }
            .card()
        }
        .sheet(item: $selectedDay) { DayDetailView(day: $0.day) }
    }

    // MARK: Month

    private var monthView: some View {
        VStack(spacing: 10) {
            stepper(title: month.formatted(Date.FormatStyle(locale: .app).month(.wide).year()).capitalizedFirst,
                    canGoBack: month > earliest, canGoForward: month < currentMonth,
                    back: { shiftMonth(-1) }, forward: { shiftMonth(1) })
            HStack(spacing: 4) {
                ForEach(Self.weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            monthGrid(month, spacing: 4, showsNumbers: true)
            Text("Klepni na den a uvidíš, co jsi ten den udělal.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func shiftMonth(_ delta: Int) {
        month = Calendar.app.date(byAdding: .month, value: delta, to: month) ?? month
    }

    /// One month as a Monday-first grid. Used large with day numbers, and small inside the year view.
    private func monthGrid(_ start: Date, spacing: CGFloat, showsNumbers: Bool) -> some View {
        let dayCount = Calendar.app.range(of: .day, in: .month, for: start)?.count ?? 30
        let scores = StatisticsService.dailyScores(tasks: tasks, from: start, days: dayCount)
        // Calendar weekdays run 1 = Sunday … 7 = Saturday; the grid starts on Monday.
        let leading = (Calendar.app.component(.weekday, from: start) + 5) % Self.daysInWeek
        let today = Date.now.startOfDay
        let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: Self.daysInWeek)
        return LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(0..<leading, id: \.self) { _ in
                Color.clear.aspectRatio(1, contentMode: .fit)
            }
            ForEach(scores) { score in
                let isFuture = score.day > today
                RoundedRectangle(cornerRadius: showsNumbers ? 7 : 2)
                    .fill(isFuture ? Color.clear : Self.color(score.productivity))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        if showsNumbers {
                            Text("\(Calendar.app.component(.day, from: score.day))")
                                .font(.system(size: 13, weight: score.day == today ? .heavy : .medium))
                                .foregroundStyle(isFuture ? Theme.textTertiary : Theme.textPrimary)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: showsNumbers ? 7 : 2)
                            .stroke(score.day == today ? Color.white : (isFuture ? Theme.border : .clear),
                                    lineWidth: score.day == today ? 1.5 : 1)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Only the large month view opens a day; in the year view the whole month is one button.
                        if showsNumbers, !isFuture { selectedDay = DayRequest(day: score.day) }
                    }
                    .allowsHitTesting(showsNumbers)
            }
        }
    }

    // MARK: Year

    private var yearView: some View {
        let firstYear = Calendar.app.component(.year, from: earliest)
        let months = (1...12).compactMap { Calendar.app.date(from: DateComponents(year: year, month: $0, day: 1)) }
        return VStack(spacing: 14) {
            stepper(title: String(year), canGoBack: year > firstYear, canGoForward: year < currentYear,
                    back: { year -= 1 }, forward: { year += 1 })
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: 3), spacing: 16) {
                ForEach(months, id: \.self) { start in
                    // Tapping a month opens it in the month view (future months have nothing to show).
                    Button {
                        guard start <= currentMonth else { return }
                        month = start
                        mode = .month
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(start.formatted(Date.FormatStyle(locale: .app).month(.wide)).capitalizedFirst)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(start == currentMonth ? Theme.textPrimary : Theme.textSecondary)
                            monthGrid(start, spacing: 2, showsNumbers: false)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Shared pieces

    private func stepper(title: String, canGoBack: Bool, canGoForward: Bool,
                         back: @escaping () -> Void, forward: @escaping () -> Void) -> some View {
        HStack {
            arrow("chevron.left", enabled: canGoBack, action: back)
            Spacer()
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            arrow("chevron.right", enabled: canGoForward, action: forward)
        }
    }

    private func arrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(enabled ? Theme.textPrimary : Theme.textTertiary)
                .frame(width: 36, height: 30)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}
