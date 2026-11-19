import SwiftUI

/// Read-only record of a closed task: what happened, the proof, focus time and any explanation given.
struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let task: TaskItem
    @State private var confirmsReopen = false

    private var statusText: (text: String, color: Color) { task.outcome() }

    private var finishedSessions: [FocusSession] { task.focusSessions.filter(\.isFinished) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(statusText.text.uppercased()).labelStyle(statusText.color)
                        Text(task.title)
                            .scaledFont(.title, weight: .bold)
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(task.category.title) · \(task.scheduledDate.longDayText) · \(task.plannedMinutes) min")
                            .scaledFont(.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    if task.isDone, AccountService.shared.profile != nil {
                        block(String(localized: "Svědek", bundle: .kept)) {
                            WitnessRow(task: task)
                                .scaledFont(.body, weight: .semibold)
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                    if !task.partialNote.isEmpty {
                        block(String(localized: "Co chybělo", bundle: .kept)) { quote(task.partialNote) }
                    }
                    if !task.notes.isEmpty {
                        block(String(localized: "Poznámka", bundle: .kept)) { quote(task.notes) }
                    }
                    if !task.stake.isEmpty {
                        block(String(localized: "Sázka", bundle: .kept)) {
                            quote(task.stake)
                            if task.stakeOutcome != 0 {
                                Text(task.stakeOutcome == 1 ? "Dodržena" : "Nedodržena")
                                    .scaledFont(.body, weight: .semibold)
                                    .foregroundStyle(task.stakeOutcome == 1 ? Theme.green : Theme.red)
                            }
                        }
                    }
                    if let workout = task.workoutSummary {
                        block(String(localized: "Trénink", bundle: .kept)) { quote(workout) }
                    }
                    if !task.exercises.isEmpty {
                        block(String(localized: "Cviky", bundle: .kept)) {
                            ForEach(task.exercises.sorted { $0.name < $1.name }) { exercise in
                                HStack {
                                    Text(exercise.name.exerciseShown)
                                        .scaledFont(.body, weight: .semibold)
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    Text(exercise.summary)
                                        .scaledFont(.body)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                    }
                    if !finishedSessions.isEmpty {
                        let active = finishedSessions.reduce(0) { $0 + $1.activeSeconds }
                        let paused = finishedSessions.reduce(0) { $0 + $1.pauseSeconds }
                        let pauses = finishedSessions.reduce(0) { $0 + $1.pauseCount }
                        TileRow {
                            MetricTile(value: "\(task.plannedMinutes) min", label: String(localized: "Plán", bundle: .kept))
                            MetricTile(value: FocusView.minutes(active), label: String(localized: "Soustředění", bundle: .kept))
                            MetricTile(value: FocusView.minutes(paused), label: String(localized: "Pauza \(pauses)×", bundle: .kept))
                        }
                    }
                    if !task.proofNote.isEmpty || task.proofPhoto != nil {
                        block(String(localized: "Důkaz", bundle: .kept)) {
                            if let data = task.proofPhoto, let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                                    .accessibilityLabel("Fotka jako důkaz splnění")
                            }
                            if !task.proofNote.isEmpty { quote(task.proofNote) }
                        }
                    }
                    ForEach(task.failures.sorted { $0.date < $1.date }) { record in
                        block(String(localized: "Vysvětlení · \(record.reason.title)", bundle: .kept)) {
                            quote("„\(record.critique)“")
                            if !record.prevention.isEmpty {
                                Text("Příště: \(record.prevention)")
                                    .scaledFont(.body)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    if !task.why.isEmpty {
                        block(String(localized: "Proč na tom záleží", bundle: .kept)) { quote(task.why) }
                    }
                }
                .padding(Theme.screenPadding)
                .padding(.top, 16)
            }
            VStack(spacing: 10) {
                if task.canReopen() {
                    Button("ZMĚNIT ROZHODNUTÍ") { confirmsReopen = true }
                        .buttonStyle(SecondaryButtonStyle(textColor: Theme.orange))
                }
                Button("ZAVŘÍT") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(Theme.screenPadding)
        }
        .screenBackground()
        .appAppearance()
        .confirmationDialog(
            task.isDone ? "Úkol se vrátí mezi otevřené a přestane se počítat jako splněný. Zapsaný trénink, důkaz a procenta se smažou."
                        : "Úkol se vrátí mezi otevřené. Tvoje vysvětlení zůstane v historii.",
            isPresented: $confirmsReopen, titleVisibility: .visible) {
            Button(task.isDone ? "Nesplnil jsem to – vrátit" : "Vrátit mezi otevřené", role: .destructive) {
                task.reopen()
                dismiss()
            }
        }
    }

    private func block(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label.uppercased()).labelStyle()
            content()
        }
    }

    private func quote(_ text: String) -> some View {
        Text(text)
            .scaledFont(.body)
            .foregroundStyle(Theme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
