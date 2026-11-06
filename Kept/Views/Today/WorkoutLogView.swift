import SwiftUI
import SwiftData

/// Asked before a gym task can be marked done: what was actually trained.
struct WorkoutLogView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var tasks: [TaskItem]
    let task: TaskItem

    @State private var selection: String?
    @State private var custom = ""
    @State private var includesAbs = false
    @State private var weightText = ""
    @State private var proof = ProofDraft()
    @State private var exercises: [ExerciseDraft] = []
    /// The logged exercise opened for correcting its sets.
    @State private var editing: PersistentIdentifier?

    private static let plausibleWeight = 30.0...300.0

    /// Accepts both "82,5" and "82.5". Nil when empty or not a plausible body weight.
    private var weight: Double? {
        let value = Double(weightText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
        return value.flatMap { Self.plausibleWeight.contains($0) ? $0 : nil }
    }

    private var weightIsInvalid: Bool {
        !weightText.trimmingCharacters(in: .whitespaces).isEmpty && weight == nil
    }

    private var lastWeight: Double? {
        tasks.filter { $0.bodyWeight != nil }
            .max { ($0.completedAt ?? $0.scheduledDate) < ($1.completedAt ?? $1.scheduledDate) }?.bodyWeight
    }

    private var settings: UserSettings { UserSettings.current(in: context) }
    private var customName: String { custom.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var workout: String? { customName.isEmpty ? selection : customName }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("GYM").labelStyle()
                            Text("Co jsi jel?")
                                .scaledFont(.title, weight: .bold)
                                .foregroundStyle(Theme.textPrimary)
                            Text("Partie i cviky v nabídce si nastavíš podle sebe v sekci Gym → Nastavení.")
                                .scaledFont(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        VStack(spacing: 10) {
                            ForEach(settings.workoutPresets, id: \.self) { preset in
                                option(preset)
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NEBO VLASTNÍMI SLOVY").labelStyle()
                            TextField("Např. kardio a mobilita", text: $custom)
                                .scaledFont(.body)
                                .card()
                            Text("Uloží se jako nová předvolba. Předvolby spravuješ v sekci Gym.")
                                .scaledFont(.caption)
                                .foregroundStyle(Theme.textTertiary)
                        }
                        Toggle("Jel jsem i břicho", isOn: $includesAbs)
                            .tint(Theme.textSecondary)
                            .scaledFont(.body, weight: .medium)
                            .card()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DNEŠNÍ VÁHA (KG)").labelStyle()
                            TextField(lastWeight.map { "Minule \($0.kilogramText)" } ?? "Nepovinné", text: $weightText)
                                .keyboardType(.decimalPad)
                                .scaledFont(.body)
                                .card()
                            if weightIsInvalid {
                                Text("Zadej váhu v kilogramech, např. 82,5.")
                                    .scaledFont(.caption)
                                    .foregroundStyle(Theme.orange)
                            }
                        }
                        if !task.exercises.isEmpty {
                            loggedExercises(proxy)
                        } else if settings.gymMode == .advanced {
                            ExerciseInput(drafts: $exercises, tasks: tasks, settings: settings)
                        }
                        if task.requiresProof {
                            ProofInput(draft: $proof)
                        }
                    }
                    .padding(Theme.screenPadding)
                    .padding(.top, 16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            VStack(spacing: 10) {
                Button("ULOŽIT A SPLNIT", action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(workout == nil || weightIsInvalid || exercises.contains { !$0.isValid } || (task.requiresProof && !proof.isValid))
                Button("ZRUŠIT") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(Theme.screenPadding)
        }
        .screenBackground()
        .appAppearance()
        .onAppear {
            // The live workout already chose what was trained.
            if selection == nil, !task.workoutType.isEmpty {
                if settings.workoutPresets.contains(task.workoutType) { selection = task.workoutType } else { custom = task.workoutType }
            }
        }
        .task {
            // With Apple Health connected, today's weight and workout fill themselves in.
            guard settings.healthEnabled else { return }
            if weightText.isEmpty, let kilograms = await HealthService.weightToday() {
                weightText = kilograms.formatted(.number.precision(.fractionLength(0...1)).locale(.app))
            }
            if task.requiresProof, proof.note.isEmpty, let minutes = await HealthService.gymMinutesToday() {
                proof.note = "Apple Health: trénink \(minutes) min"
            }
        }
    }

    /// What the live workout recorded, set by set. Tapping an exercise opens it for corrections and scrolls to it.
    private func loggedExercises(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ODCVIČENO").labelStyle()
            Text("Klepnutím na cvik opravíš váhu a opakování.")
                .scaledFont(.caption)
                .foregroundStyle(Theme.textTertiary)
            ForEach(task.exercises.sorted { $0.date < $1.date }) { log in
                let isOpen = editing == log.persistentModelID
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            editing = isOpen ? nil : log.persistentModelID
                        }
                        if !isOpen {
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(150))
                                withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(log.persistentModelID, anchor: .top) }
                            }
                        }
                    } label: {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(log.name).scaledFont(.body, weight: .semibold).foregroundStyle(Theme.textPrimary)
                                Text(log.workingSets.map { $0.weight > 0 ? "\($0.weight.kilogramText) × \($0.reps)" : "\($0.reps) opak." }
                                    .joined(separator: " · "))
                                    .scaledFont(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: isOpen ? "chevron.up" : "pencil")
                                .scaledFont(.caption, weight: .semibold)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(isOpen ? "Zavře úpravy" : "Otevře úpravy cviku")
                    if isOpen {
                        LoggedSetsEditor(log: log)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(padding: 12)
                .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(isOpen ? Theme.textPrimary.opacity(0.5) : .clear, lineWidth: 1))
                .id(log.persistentModelID)
            }
        }
    }

    private func option(_ preset: String) -> some View {
        let isSelected = customName.isEmpty && selection == preset
        return Button {
            custom = ""
            selection = preset
        } label: {
            HStack {
                Text(preset)
                    .scaledFont(.body, weight: .medium)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").foregroundStyle(Theme.textPrimary)
                }
            }
            .padding(16)
            .background(isSelected ? Theme.cardRaised : Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Theme.textPrimary.opacity(0.5) : Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func save() {
        guard let workout else { return }
        if !customName.isEmpty, !settings.workoutPresets.contains(customName) {
            settings.workoutPresets.append(customName)
        }
        task.workoutType = workout
        task.workoutAbs = includesAbs
        task.bodyWeight = weight
        for draft in exercises {
            guard let weight = draft.weight else { continue }
            let log = ExerciseLog(name: draft.name, weight: weight, reps: draft.reps, sets: draft.sets)
            log.task = task
            context.insert(log)
        }
        if task.requiresProof {
            proof.apply(to: task)
        }
        task.markDone()
        dismiss()
    }
}

/// Correcting the working sets of a logged exercise: weight and reps of each set, adding or removing a set.
private struct LoggedSetsEditor: View {
    @Environment(\.modelContext) private var context
    @Bindable var log: ExerciseLog

    private var sets: [SetLog] { log.orderedSets.filter { !$0.isWarmup && $0.isDone } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if sets.isEmpty {
                // Older logs keep one summary instead of single sets.
                row(index: 1, weight: $log.weight, reps: $log.reps, onDelete: nil)
                Stepper("Sérií: \(log.sets)", value: $log.sets, in: 1...12)
                    .scaledFont(.body)
                    .foregroundStyle(Theme.textPrimary)
            } else {
                ForEach(Array(sets.enumerated()), id: \.element.persistentModelID) { index, set in
                    row(index: index + 1, weight: Bindable(set).weight, reps: Bindable(set).reps) {
                        context.delete(set)
                        Persistence.save(context)
                    }
                }
                Button {
                    let last = sets.last
                    let set = SetLog(order: (log.orderedSets.last?.order ?? 0) + 1, weight: last?.weight ?? 0,
                                     reps: last?.reps ?? 8, isWarmup: false)
                    set.isDone = true
                    set.log = log
                    context.insert(set)
                    Persistence.save(context)
                } label: {
                    Label("Přidat sérii", systemImage: "plus")
                        .scaledFont(.caption, weight: .semibold)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textPrimary)
            }
        }
    }

    private func row(index: Int, weight: Binding<Double>, reps: Binding<Int>, onDelete: (() -> Void)?) -> some View {
        HStack(spacing: 8) {
            Text("\(index).")
                .scaledFont(.caption, weight: .semibold)
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 22, alignment: .leading)
            TextField("0", value: weight, format: .number.precision(.fractionLength(0...1)).locale(.app))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .scaledFont(.body, weight: .semibold)
                .frame(minHeight: 36)
                .background(Theme.cardRaised)
                .clipShape(RoundedRectangle(cornerRadius: 9))
            Text("kg ×").scaledFont(.caption).foregroundStyle(Theme.textSecondary)
            Picker("Opakování", selection: reps) {
                ForEach(0...100, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(Theme.textPrimary)
            .frame(minWidth: 64, minHeight: 36)
            .background(Theme.cardRaised)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.red)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Smazat sérii \(index)")
            }
        }
    }
}
