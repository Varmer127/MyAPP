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
    @State private var liftName = ""
    @State private var liftWeightText = ""
    @State private var liftReps = 0

    private static let plausibleLift = 1.0...600.0
    private static let repsRange = 0...50

    private var liftWeight: Double? {
        let value = Double(liftWeightText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
        return value.flatMap { Self.plausibleLift.contains($0) ? $0 : nil }
    }

    private var trimmedLiftName: String { liftName.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// A lift is either left out entirely or given with both a name and a plausible weight.
    private var liftIsInvalid: Bool {
        let hasWeightText = !liftWeightText.trimmingCharacters(in: .whitespaces).isEmpty
        return (hasWeightText && liftWeight == nil) || (hasWeightText && trimmedLiftName.isEmpty)
            || (!trimmedLiftName.isEmpty && liftWeight == nil)
    }

    /// The main lift logged last time this kind of workout was trained.
    private func lastLift(for workout: String?) -> TaskItem? {
        guard let workout else { return nil }
        return tasks.filter { $0.isDone && $0.workoutType == workout && !$0.liftName.isEmpty && $0.liftWeight != nil }
            .max { ($0.completedAt ?? $0.scheduledDate) < ($1.completedAt ?? $1.scheduledDate) }
    }

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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GYM").labelStyle()
                        Text("Co jsi jel?")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    VStack(spacing: 10) {
                        ForEach(settings.workoutPresets, id: \.self) { preset in
                            option(preset)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NEBO VLASTNÍMI SLOVY").labelStyle()
                        TextField("Např. kardio a mobilita", text: $custom)
                            .font(.system(size: 16))
                            .card()
                        Text("Uloží se jako nová předvolba. Předvolby spravuješ v Nastavení.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Toggle("Jel jsem i břicho", isOn: $includesAbs)
                        .tint(Theme.textSecondary)
                        .font(.system(size: 16, weight: .medium))
                        .card()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DNEŠNÍ VÁHA (KG)").labelStyle()
                        TextField(lastWeight.map { "Minule \($0.kilogramText)" } ?? "Nepovinné", text: $weightText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 16))
                            .card()
                        if weightIsInvalid {
                            Text("Zadej váhu v kilogramech, např. 82,5.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.orange)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("HLAVNÍ CVIK").labelStyle()
                        TextField("Např. Bench press (nepovinné)", text: $liftName)
                            .font(.system(size: 16))
                            .card()
                        HStack(spacing: 10) {
                            TextField("Váha na čince (kg)", text: $liftWeightText)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 16))
                                .card()
                            Stepper(liftReps == 0 ? "Opak." : "\(liftReps)×", value: $liftReps, in: Self.repsRange)
                                .font(.system(size: 15))
                                .card(padding: 10)
                        }
                        if let last = lastLift(for: workout), let weight = last.liftWeight {
                            Text("Minule: \(last.liftName) \(weight.kilogramText)\(last.liftReps > 0 ? " × \(last.liftReps)" : "")")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        if liftIsInvalid {
                            Text("Vyplň název cviku i váhu, nebo nech obojí prázdné.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.orange)
                        }
                    }
                    if task.requiresProof {
                        ProofInput(draft: $proof)
                    }
                }
                .padding(Theme.screenPadding)
                .padding(.top, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            VStack(spacing: 10) {
                Button("ULOŽIT A SPLNIT", action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(workout == nil || weightIsInvalid || liftIsInvalid || (task.requiresProof && !proof.isValid))
                Button("ZRUŠIT") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(Theme.screenPadding)
        }
        .screenBackground()
        .preferredColorScheme(.dark)
        .onChange(of: selection) { _, _ in
            // Picking the workout offers last time's main lift, so only the weight needs updating.
            if trimmedLiftName.isEmpty, let last = lastLift(for: workout) {
                liftName = last.liftName
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

    private func option(_ preset: String) -> some View {
        let isSelected = customName.isEmpty && selection == preset
        return Button {
            custom = ""
            selection = preset
        } label: {
            HStack {
                Text(preset)
                    .font(.system(size: 16, weight: .medium))
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
                .stroke(isSelected ? Color.white.opacity(0.5) : Theme.border, lineWidth: 1))
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
        task.liftName = liftWeight == nil ? "" : trimmedLiftName
        task.liftWeight = liftWeight
        task.liftReps = liftWeight == nil ? 0 : liftReps
        if task.requiresProof {
            proof.apply(to: task)
        }
        task.markDone()
        dismiss()
    }
}
