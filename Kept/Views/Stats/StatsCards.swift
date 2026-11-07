import SwiftUI

/// A small card with a label, a big value and a line under it, two of them side by side.
struct StatTile: View {
    let label: LocalizedStringKey
    let value: String
    var caption: String = ""
    var captionColor: Color = Theme.textSecondary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).labelStyle()
            Text(value)
                .scaledFont(22, weight: .heavy)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            if !caption.isEmpty {
                Text(caption)
                    .scaledFont(.caption)
                    .foregroundStyle(captionColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }
}

/// How the promises of the period ended, in one bar: on time, late, skipped, broken and removed.
struct OutcomesCard: View {
    let tasks: [TaskItem]

    private struct Part: Identifiable {
        let label: LocalizedStringKey
        let count: Int
        let color: Color
        let id: Int
    }

    var body: some View {
        let now = Date.now
        let parts = [
            Part(label: "Včas", count: tasks.filter { $0.status == .completed && !$0.isRemoved }.count, color: Theme.green, id: 0),
            Part(label: "Pozdě", count: tasks.filter { $0.status == .completedLate && !$0.isRemoved }.count, color: Theme.orange, id: 1),
            Part(label: "Přeskočeno", count: tasks.filter { $0.status == .skipped && !$0.isRemoved }.count, color: Theme.textSecondary, id: 2),
            Part(label: "Nesplněno", count: tasks.filter { ($0.status == .failed || $0.isMissed(now)) && !$0.isRemoved }.count, color: Theme.red, id: 3),
            Part(label: "Odstraněno", count: tasks.filter(\.isRemoved).count, color: Theme.red.opacity(0.5), id: 4)
        ]
        let critical = tasks.filter { $0.scoringPriority == .critical }
        VStack(spacing: 10) {
            SectionLabel(text: "Jak dopadly sliby")
            VStack(alignment: .leading, spacing: 12) {
                GeometryReader { proxy in
                    let total = max(parts.reduce(0) { $0 + $1.count }, 1)
                    let shown = parts.filter { $0.count > 0 }
                    let gaps = CGFloat(max(shown.count - 1, 0)) * 2
                    HStack(spacing: 2) {
                        ForEach(shown) { part in
                            Rectangle()
                                .fill(part.color)
                                .frame(width: max(4, (proxy.size.width - gaps) * CGFloat(part.count) / CGFloat(total)))
                        }
                    }
                }
                .frame(height: 14)
                .background(Theme.cardRaised)
                .clipShape(Capsule())
                .accessibilityHidden(true)
                FlowLayout(spacing: 12) {
                    ForEach(parts) { part in
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 2).fill(part.color).frame(width: 9, height: 9)
                            Text(part.label).foregroundStyle(Theme.textSecondary)
                            Text("\(part.count)").fontWeight(.bold).foregroundStyle(Theme.textPrimary)
                        }
                        .scaledFont(.caption)
                        .accessibilityElement(children: .combine)
                    }
                }
                if !critical.isEmpty {
                    Text("Kritické splněno: \(critical.filter(\.isDone).count) z \(critical.count)")
                        .scaledFont(.caption, weight: .semibold)
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .card()
        }
    }
}

/// When in the day promises get kept, the strongest weekday, and the patterns found in the last 90 days.
struct WhenYouKeepCard: View {
    let tasks: [TaskItem]
    let insights: [String]

    private static let slotLabels = ["0:00", "6:00", "12:00", "18:00", "24:00"]

    var body: some View {
        let slots = StatisticsService.keptBySlot(tasks)
        let peak = slots.max() ?? 0
        if peak > 0 || !insights.isEmpty {
            VStack(spacing: 10) {
                SectionLabel(text: "Kdy ti to jde")
                VStack(alignment: .leading, spacing: 12) {
                    if peak > 0 {
                        HStack(alignment: .bottom, spacing: 4) {
                            ForEach(slots.indices, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Theme.green.opacity(0.3 + 0.7 * Double(slots[index]) / Double(peak)))
                                    .frame(height: max(4, 64 * CGFloat(slots[index]) / CGFloat(peak)))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 64, alignment: .bottom)
                        .accessibilityHidden(true)
                        HStack {
                            ForEach(Self.slotLabels.indices, id: \.self) { index in
                                Text(Self.slotLabels[index])
                                if index < Self.slotLabels.count - 1 { Spacer() }
                            }
                        }
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .accessibilityHidden(true)
                        if let best = slots.indices.max(by: { slots[$0] < slots[$1] }) {
                            Group {
                                if let strongest = StatisticsService.strongestWeekday(tasks) {
                                    Text("Nejvíc dodržíš: \(weekdayName(strongest.weekday)), mezi \(best * 2):00 a \(best * 2 + 2):00")
                                } else {
                                    Text("Nejvíc dodržíš mezi \(best * 2):00 a \(best * 2 + 2):00")
                                }
                            }
                            .scaledFont(.body, weight: .semibold)
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if !insights.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Zjištěné vzorce").labelStyle()
                            ForEach(insights, id: \.self) { insight in
                                Text(insight)
                                    .scaledFont(.body)
                                    .foregroundStyle(Theme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    Text("Těžké věci plánuj tam, kde ti to jde. Konkrétní „kdy“ zvyšuje šanci, že to uděláš.")
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .card()
            }
        }
    }

    private func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.app.standaloneWeekdaySymbols
        return symbols.indices.contains(weekday - 1) ? symbols[weekday - 1] : ""
    }
}

/// How many more times each weekly goal needs this week. Close to the goal, people push harder,
/// so it says "ještě 2×" rather than a percentage.
struct GoalsLeftCard: View {
    let goals: [WeeklyGoal]

    var body: some View {
        let open = goals.filter { !$0.isMet }
        if !open.isEmpty {
            VStack(spacing: 10) {
                SectionLabel(text: "Do cíle týdne")
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(open) { goal in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(goal.category.title, systemImage: goal.category.icon)
                                    .scaledFont(.body)
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text("ještě \(goal.target - goal.done)×")
                                    .scaledFont(.body, weight: .semibold)
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            ThinBar(value: Double(goal.done) / Double(max(goal.target, 1)), color: Theme.textPrimary)
                        }
                    }
                }
                .card()
            }
        }
    }
}

/// How far the most repeated activity is on the way to a habit. Only a rough guide: people take
/// anywhere from a few weeks to many months, about two months is typical.
struct HabitPathCard: View {
    let tasks: [TaskItem]

    private static let typicalRepetitions = 66

    var body: some View {
        if let habit = StatisticsService.habitInProgress(tasks) {
            VStack(spacing: 10) {
                SectionLabel(text: "Cesta ke zvyku")
                VStack(alignment: .leading, spacing: 10) {
                    Label(habit.category.title, systemImage: habit.category.icon)
                        .scaledFont(.body, weight: .semibold)
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(habit.count)× splněno")
                        .scaledFont(.title, weight: .heavy)
                        .foregroundStyle(Theme.textPrimary)
                    ThinBar(value: min(Double(habit.count) / Double(Self.typicalRepetitions), 1), color: Theme.green)
                    Text("Zvyk se každému tvoří jinak dlouho, typicky kolem dvou měsíců pravidelnosti. Ber to jako orientaci, ne jako cílovou čáru.")
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .card()
            }
        }
    }
}

/// The weekly reviews of every week with tasks, on a screen of their own.
struct ReviewHistoryView: View {
    let tasks: [TaskItem]

    var body: some View {
        ScrollView {
            ReviewHistorySection(tasks: tasks)
                .padding(.horizontal, Theme.screenPadding)
                .padding(.vertical, 16)
        }
        .screenBackground()
        .navigationTitle("Přehledy týdnů")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }
}

/// One row of the links at the bottom of Stats.
struct StatsLinkRow<Destination: View>: View {
    let symbol: String
    let title: LocalizedStringKey
    var detail: String = ""
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .scaledFont(.body, weight: .semibold)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 24)
                Text(title)
                    .scaledFont(.body, weight: .semibold)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if !detail.isEmpty {
                    Text(detail)
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .scaledFont(.caption, weight: .semibold)
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
