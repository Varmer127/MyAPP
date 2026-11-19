import SwiftUI
import SwiftData

/// Adds the user's own activity with its icon straight from planning. It can be kept among the user's activities
/// for good (the same as Settings → Activities) or used just this once, for the plan being made.
struct NewActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var settingsList: [UserSettings]
    /// Called with the new activity's name, and whether it was kept for good, once it is added.
    let onAdd: (_ name: String, _ isPermanent: Bool) -> Void

    @State private var name = ""
    @State private var symbol = ActivityIcons.customDefault
    @State private var isWorkout = false
    @State private var isPermanent = true
    @State private var picksIcon = false
    @FocusState private var nameFocused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var exists: Bool {
        (settingsList.first?.customActivities ?? []).contains { $0.activityKey == trimmed.activityKey }
            || TaskCategory.allCases.contains { $0.title.activityKey == trimmed.activityKey }
    }
    private var canSave: Bool { !trimmed.isEmpty && !exists }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        Button { picksIcon = true } label: {
                            Image(systemName: symbol)
                                .scaledFont(.title)
                                .foregroundStyle(Theme.onPrimary)
                                .frame(width: 72, height: 72)
                                .background(Theme.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .overlay(alignment: .bottomTrailing) {
                                    Image(systemName: "pencil.circle.fill")
                                        .scaledFont(.heading)
                                        .foregroundStyle(Theme.textPrimary, Theme.card)
                                        .offset(x: 6, y: 6)
                                }
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(PillPressStyle())
                        .accessibilityLabel("Vybrat ikonu")
                        TextField("Např. Kytara", text: $name)
                            .scaledFont(.heading, weight: .semibold)
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .onSubmit(save)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 54)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
                    }
                    if exists {
                        Text("Aktivitu „\(trimmed)“ už máš. Najdeš ji mezi ostatními.")
                            .scaledFont(.caption)
                            .foregroundStyle(Theme.orange)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NA JAK DLOUHO").labelStyle()
                        keepOption(true, title: "Natrvalo", detail: "Přidá se mezi tvoje aktivity a najdeš ji při každém plánování.",
                                   symbol: "pin.fill")
                        keepOption(false, title: "Jen tentokrát", detail: "Použije se jen v tomhle plánu. Mezi aktivitami se neobjeví.",
                                   symbol: "1.circle")
                    }
                    Toggle(isOn: $isWorkout) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Počítá se jako trénink")
                                .scaledFont(.body, weight: .semibold)
                                .foregroundStyle(Theme.textPrimary)
                            Text("Třeba lezení nebo plavání: počítá se do odznaků a tréninků ve Zdraví.")
                                .scaledFont(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .tint(Theme.green)
                    .card()
                    if isPermanent {
                        Text("Ikonu i název změníš kdykoli v Nastavení → Aktivity a cíle.")
                            .scaledFont(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(Theme.screenPadding)
            }
            .safeAreaInset(edge: .bottom) {
                Button(isPermanent ? "PŘIDAT NATRVALO" : "POUŽÍT JEN TEĎ", action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave)
                    .padding(Theme.screenPadding)
                    .background(Theme.background)
            }
            .screenBackground()
            .navigationTitle("Vlastní aktivita")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Zavřít") { dismiss() } } }
            .sheet(isPresented: $picksIcon) {
                ActivityIconPicker(activity: trimmed.isEmpty ? String(localized: "nová aktivita", bundle: .kept, locale: .kept) : trimmed, selected: symbol) { picked in
                    withAnimation { symbol = picked }
                    Haptics.light()
                }
            }
            .sensoryFeedback(.selection, trigger: isWorkout)
            .sensoryFeedback(.selection, trigger: isPermanent)
            .onAppear { nameFocused = true }
        }
        .appAppearance()
        .presentationDetents([.large])
    }

    private func keepOption(_ value: Bool, title: LocalizedStringKey, detail: LocalizedStringKey, symbol: String) -> some View {
        let isOn = isPermanent == value
        return Button {
            withAnimation(.spring(duration: 0.25)) { isPermanent = value }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .scaledFont(.body, weight: .semibold)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).scaledFont(.body, weight: .bold)
                    Text(detail)
                        .scaledFont(.caption)
                        .opacity(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .scaledFont(.heading)
                    .contentTransition(.symbolEffect(.replace))
            }
            .foregroundStyle(isOn ? Theme.onPrimary : Theme.textPrimary)
            .padding(14)
            .background(isOn ? Theme.textPrimary : Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isOn ? Theme.textPrimary : Theme.border, lineWidth: 1))
        }
        .buttonStyle(PillPressStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func save() {
        guard canSave else { return }
        let settings = UserSettings.current(in: context)
        if isPermanent {
            settings.customActivities = settings.customActivities + [trimmed]
        }
        // The icon and the workout mark belong to the name, so a one-off task shows its icon and counts as a workout too.
        settings.setCountsAsWorkout(isWorkout, custom: trimmed)
        ActivityIcons.shared.set(symbol, forCustom: trimmed)
        Persistence.save(context)
        Haptics.success()
        onAdd(trimmed, isPermanent)
        dismiss()
    }
}
