import SwiftUI

/// How yesterday went, offered once in the inbox the next day. It looks back; the morning brief looks ahead
/// at today, so the two never say the same thing.
struct DayRecap: Identifiable {
    let day: Date
    let tasks: [TaskItem]
    let productivity: Double?
    var id: Date { day }

    var done: Int { tasks.filter(\.isDone).count }
    var total: Int { tasks.count }

    static func make(tasks: [TaskItem], now: Date = .now) -> DayRecap? {
        let yesterday = now.startOfDay.addingDays(-1)
        let day = tasks.filter { !$0.isRemoved && $0.countsInScores && $0.scheduledDate.isSameDay(as: yesterday) }
        guard !day.isEmpty else { return nil }
        return DayRecap(day: yesterday, tasks: day.sorted { $0.dueDate < $1.dueDate },
                        productivity: ScoreEngine.productivity(day, now: now))
    }
}

struct DayRecapView: View {
    let recap: DayRecap
    let streak: Int
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("VČEREJŠEK · \(recap.day.longDayText.uppercased())").labelStyle()
                        Text("Dodrženo \(recap.done) z \(recap.total)")
                            .scaledFont(.title, weight: .heavy)
                            .foregroundStyle(Theme.textPrimary)
                        Text(verdict)
                            .scaledFont(.body)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    TileRow {
                        MetricTile(value: recap.productivity.percentText, label: "Produktivita")
                        MetricTile(value: "\(streak)", label: streak == 1 ? "Den v řadě" : "Dní v řadě")
                    }
                    VStack(spacing: 0) {
                        ForEach(recap.tasks) { task in
                            HStack(spacing: 12) {
                                Image(systemName: symbol(for: task))
                                    .foregroundStyle(color(for: task))
                                    .frame(width: 24)
                                Text(task.title)
                                    .scaledFont(.body)
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(2)
                                Spacer()
                                Text(state(of: task))
                                    .scaledFont(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .padding(.vertical, 10)
                            if task.id != recap.tasks.last?.id { Divider().overlay(Theme.border) }
                        }
                    }
                    .card()
                    Button("HOTOVO") { onClose() }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.vertical, 20)
            }
            .screenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Zavřít") { onClose() } } }
        }
        .appAppearance()
    }

    private var verdict: LocalizedStringKey {
        if recap.done == recap.total { return "Všechno dodrženo. Takhle vypadá slovo, které platí." }
        if recap.done == 0 { return "Včera se nepovedlo nic. Dnes je nový den, začni jedním slibem." }
        return "Něco vyšlo, něco ne. Dnes můžeš navázat na to, co šlo."
    }

    private func symbol(for task: TaskItem) -> String {
        if task.isDone { return "checkmark.circle.fill" }
        return task.status == .pending ? "circle.dashed" : "xmark.circle.fill"
    }

    private func color(for task: TaskItem) -> Color {
        if task.isDone { return Theme.green }
        return task.status == .pending ? Theme.textTertiary : Theme.red
    }

    private func state(of task: TaskItem) -> LocalizedStringKey {
        if task.isDone { return "Splněno" }
        return task.status == .pending ? "Neuzavřeno" : "Nesplněno"
    }
}
