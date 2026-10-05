import SwiftUI
import SwiftData

/// Asked before a gym task can be marked done: what was actually trained.
struct WorkoutLogView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let task: TaskItem

    @State private var selection: String?
    @State private var custom = ""
    @State private var includesAbs = false

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
                }
                .padding(Theme.screenPadding)
                .padding(.top, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            VStack(spacing: 10) {
                Button("ULOŽIT A SPLNIT", action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(workout == nil)
                Button("ZRUŠIT") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(Theme.screenPadding)
        }
        .screenBackground()
        .preferredColorScheme(.dark)
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
        task.markDone()
        dismiss()
    }
}
