import SwiftUI
import SwiftData

/// Wraps a day so it can drive `sheet(item:)`.
struct DayRequest: Identifiable {
    let day: Date
    var id: Date { day }
}

/// Everything that happened on one day: each task, how it ended and every note written about it.
struct DayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var tasks: [TaskItem]
    let day: Date
    @State private var detailTask: TaskItem?

    private var dayTasks: [TaskItem] {
        tasks.filter { $0.scheduledDate.isSameDay(as: day) }
            .sorted { $0.dueDate == $1.dueDate ? $0.priority.rank > $1.priority.rank : $0.dueDate < $1.dueDate }
    }

    var body: some View {
        let now = Date.now
        let items = dayTasks
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DEN").labelStyle()
                        Text(day.longDayText)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    if items.isEmpty {
                        Text("Na tento den nebylo nic v plánu.")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textSecondary)
                            .card()
                    } else {
                        let scored = items.filter { !$0.isRecovery }
                        HStack(spacing: 10) {
                            MetricTile(value: ScoreEngine.productivity(items, now: now).percentText, label: "Produktivita")
                            MetricTile(value: "\(scored.filter(\.isDone).count) / \(scored.count)", label: "Splněno")
                            MetricTile(value: ScoreEngine.promisesKept(items, now: now).percentText, label: "Sliby")
                        }
                        ForEach(items) { task in
                            taskCard(task, now: now)
                        }
                    }
                }
                .padding(Theme.screenPadding)
                .padding(.top, 16)
            }
            Button("ZAVŘÍT") { dismiss() }
                .buttonStyle(SecondaryButtonStyle())
                .padding(Theme.screenPadding)
        }
        .screenBackground()
        .preferredColorScheme(.dark)
        .sheet(item: $detailTask) { TaskDetailView(task: $0) }
    }

    private func taskCard(_ task: TaskItem, now: Date) -> some View {
        let outcome = task.outcome(now: now)
        return VStack(alignment: .leading, spacing: 8) {
            Text(outcome.text.uppercased()).labelStyle(outcome.color)
            Text(task.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 6) {
                Image(systemName: task.category.symbol)
                Text(meta(task))
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.textSecondary)
            ForEach(notes(task), id: \.label) { note in
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.label.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.textTertiary)
                    Text(note.text)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
        }
        .card()
        .contentShape(Rectangle())
        .onTapGesture { detailTask = task }
    }

    private func meta(_ task: TaskItem) -> String {
        var parts = [task.category.title, "\(task.plannedMinutes) min"]
        if let deadline = task.deadline { parts.append("Deadline \(deadline.timeText)") }
        if let completedAt = task.completedAt, task.isDone { parts.append("hotovo \(completedAt.timeText)") }
        if task.isRecovery { parts.append("recovery") }
        return parts.joined(separator: " · ")
    }

    /// Every piece of text the user wrote about this task, in the order it tells the story.
    private func notes(_ task: TaskItem) -> [(label: String, text: String)] {
        var notes: [(String, String)] = []
        if let workout = task.workoutSummary { notes.append(("Trénink", workout)) }
        for exercise in task.exercises.sorted(by: { $0.name < $1.name }) {
            notes.append((exercise.name, exercise.summary))
        }
        if !task.liftName.isEmpty, let weight = task.liftWeight {
            notes.append(("Hlavní cvik", "\(task.liftName) \(weight.kilogramText)\(task.liftReps > 0 ? " × \(task.liftReps)" : "")"))
        }
        if !task.partialNote.isEmpty { notes.append(("Co chybělo", task.partialNote)) }
        if !task.proofNote.isEmpty { notes.append(("Důkaz", task.proofNote)) }
        if task.proofPhoto != nil { notes.append(("Fotka", "Přiložena – klepni pro zobrazení")) }
        for (index, record) in task.failures.sorted(by: { $0.date < $1.date }).enumerated() {
            notes.append(("Důvod\(index > 0 ? " \(index + 1)" : "")", "\(record.reason.title): „\(record.critique)“"))
            if !record.prevention.isEmpty { notes.append(("Příště\(index > 0 ? " \(index + 1)" : "")", record.prevention)) }
        }
        if !task.stake.isEmpty {
            let result = task.stakeOutcome == 1 ? " (dodržena)" : (task.stakeOutcome == 2 ? " (nedodržena)" : "")
            notes.append(("Sázka", task.stake + result))
        }
        if !task.notes.isEmpty { notes.append(("Poznámka", task.notes)) }
        return notes
    }
}
