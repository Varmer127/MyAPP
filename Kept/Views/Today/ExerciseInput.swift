import SwiftUI

/// One exercise being entered in the workout log.
struct ExerciseDraft: Identifiable {
    let name: String
    var weightText = ""
    var reps = 8
    var sets = 3

    var id: String { name }

    private static let plausibleWeight = 0.0...600.0

    /// Empty means bodyweight (0 kg). Nil when the text is not a plausible weight.
    var weight: Double? {
        let trimmed = weightText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return 0 }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
            .flatMap { Self.plausibleWeight.contains($0) ? $0 : nil }
    }

    var isValid: Bool { weight != nil }
}

/// Picks the exercises of a workout from presets and collects weight, reps and sets for each.
struct ExerciseInput: View {
    @Binding var drafts: [ExerciseDraft]
    let tasks: [TaskItem]
    let settings: UserSettings
    @State private var custom = ""

    private static let repsRange = 1...50
    private static let setsRange = 1...12

    private var customName: String { custom.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func lastLog(_ name: String) -> ExerciseLog? {
        tasks.flatMap(\.exercises).filter { $0.name == name }.max { $0.date < $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CVIKY").labelStyle()
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                ForEach(settings.exercisePresets, id: \.self) { name in
                    let isSelected = drafts.contains { $0.name == name }
                    Button {
                        toggle(name)
                    } label: {
                        Text(name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isSelected ? .black : Theme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .padding(.horizontal, 6)
                            .background(isSelected ? Color.white : Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 10) {
                TextField("Jiný cvik", text: $custom)
                    .font(.system(size: 16))
                    .card()
                Button("PŘIDAT") {
                    let name = customName
                    if !settings.exercisePresets.contains(name) {
                        settings.exercisePresets.append(name)
                    }
                    if !drafts.contains(where: { $0.name == name }) {
                        toggle(name)
                    }
                    custom = ""
                }
                .buttonStyle(SecondaryButtonStyle())
                .frame(width: 96)
                .disabled(customName.isEmpty)
            }
            ForEach($drafts) { $draft in
                row($draft)
            }
            Text(drafts.isEmpty
                 ? "Nepovinné. Klepni na cvik a zapiš váhu, opakování a série. Předvolby upravíš v Nastavení."
                 : "Váhu nech prázdnou u cviků s vlastní vahou.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private func row(_ draft: Binding<ExerciseDraft>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(draft.wrappedValue.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    toggle(draft.wrappedValue.name)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            HStack(alignment: .top, spacing: 8) {
                column("KG") {
                    TextField("0", text: draft.weightText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 17, weight: .semibold))
                        .multilineTextAlignment(.center)
                }
                column("OPAKOVÁNÍ") {
                    Picker("Opakování", selection: draft.reps) {
                        ForEach(Self.repsRange, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .tint(.white)
                }
                column("SÉRIE") {
                    Picker("Série", selection: draft.sets) {
                        ForEach(Self.setsRange, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .tint(.white)
                }
            }
            if let last = lastLog(draft.wrappedValue.name) {
                Text("Minule (\(last.date.dayMonthText)): \(last.summary)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            if !draft.wrappedValue.isValid {
                Text("Zadej váhu v kilogramech, např. 82,5.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.orange)
            }
        }
        .card(padding: 12)
    }

    /// One labelled input cell of an exercise row.
    private func column(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.textTertiary)
            content()
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(Theme.cardRaised)
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .frame(maxWidth: .infinity)
    }

    /// Adds the exercise prefilled from last time, or removes it if it is already there.
    private func toggle(_ name: String) {
        if let index = drafts.firstIndex(where: { $0.name == name }) {
            drafts.remove(at: index)
            return
        }
        var draft = ExerciseDraft(name: name)
        if let last = lastLog(name) {
            draft.reps = last.reps
            draft.sets = last.sets
            if last.weight > 0 {
                draft.weightText = last.weight.formatted(.number.precision(.fractionLength(0...1)).locale(.app))
            }
        }
        drafts.append(draft)
    }
}
