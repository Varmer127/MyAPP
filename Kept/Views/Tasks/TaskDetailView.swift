import SwiftUI

/// Read-only record of a closed task: what happened, the proof, focus time and any explanation given.
struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let task: TaskItem

    private var statusText: (text: String, color: Color) {
        if task.isRemoved { return ("Odstraněno po závazku", Theme.red) }
        switch task.status {
        case .completed: return ("Splněno včas", Theme.green)
        case .completedLate: return ("Splněno pozdě", Theme.orange)
        case .skipped: return ("Přeskočeno", Theme.red)
        case .failed: return ("Nesplněno", Theme.red)
        case .pending: return ("Otevřené", Theme.textSecondary)
        }
    }

    private var finishedSessions: [FocusSession] { task.focusSessions.filter(\.isFinished) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(statusText.text.uppercased()).labelStyle(statusText.color)
                        Text(task.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(task.category.title) · \(task.scheduledDate.longDayText) · \(task.plannedMinutes) min")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    if let workout = task.workoutSummary {
                        block("Trénink") { quote(workout) }
                    }
                    if !finishedSessions.isEmpty {
                        let active = finishedSessions.reduce(0) { $0 + $1.activeSeconds }
                        let paused = finishedSessions.reduce(0) { $0 + $1.pauseSeconds }
                        let pauses = finishedSessions.reduce(0) { $0 + $1.pauseCount }
                        HStack(spacing: 10) {
                            MetricTile(value: "\(task.plannedMinutes) min", label: "Plán")
                            MetricTile(value: FocusView.minutes(active), label: "Soustředění")
                            MetricTile(value: FocusView.minutes(paused), label: "Pauza \(pauses)×")
                        }
                    }
                    if !task.proofNote.isEmpty || task.proofPhoto != nil {
                        block("Důkaz") {
                            if let data = task.proofPhoto, let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                            }
                            if !task.proofNote.isEmpty { quote(task.proofNote) }
                        }
                    }
                    ForEach(task.failures.sorted { $0.date < $1.date }) { record in
                        block("Bez výmluv · \(record.reason.title)") {
                            quote("„\(record.critique)“")
                            if !record.prevention.isEmpty {
                                Text("Příště: \(record.prevention)")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    if !task.why.isEmpty {
                        block("Proč na tom záleží") { quote(task.why) }
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
    }

    private func block(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label.uppercased()).labelStyle()
            content()
        }
    }

    private func quote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16))
            .foregroundStyle(Theme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
