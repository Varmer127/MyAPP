import SwiftUI
import SwiftData

/// Which activities the user does: the built-in categories they pick and their own named ones.
struct ActivitiesSettingsView: View {
    @Query private var settingsList: [UserSettings]
    @State private var newActivity = ""
    @State private var isAdding = false
    @State private var newIsWorkout = false

    var body: some View {
        Form {
            if let settings = settingsList.first {
                Section {
                    ForEach(TaskCategory.allCases.filter { $0 != .other }) { category in
                        HStack(spacing: 12) {
                            ActivityIconButton(activity: category.title, symbol: category.icon) {
                                ActivityIcons.shared.set($0, for: category)
                            }
                            Toggle(category.title, isOn: Binding(get: { settings.isEnabled(category) },
                                                                 set: { settings.setEnabled($0, category) }))
                                .tint(Theme.textSecondary)
                        }
                    }
                } header: {
                    Text("Z nabídky")
                } footer: {
                    Text("Klepnutím na ikonu ji změníš. Vypnutá aktivita se nenabízí při plánování ani v návrzích a nemá týdenní cíl. Úkoly, které už v ní máš, zůstanou.")
                }
                .listRowBackground(Theme.card)

                customSection(settings)
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Moje aktivity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }

    private func customSection(_ settings: UserSettings) -> some View {
        let name = newActivity.trimmingCharacters(in: .whitespacesAndNewlines)
        let custom = settings.customActivities
        return Section {
            ForEach(custom, id: \.self) { item in
                HStack(spacing: 12) {
                    ActivityIconButton(activity: item, symbol: ActivityIcons.shared.symbol(forCustom: item)) {
                        ActivityIcons.shared.set($0, forCustom: item)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item)
                        Toggle("Počítá se jako trénink", isOn: Binding(
                            get: { settings.countsAsWorkout(custom: item) },
                            set: { settings.setCountsAsWorkout($0, custom: item) }))
                            .scaledFont(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .tint(Theme.textSecondary)
                            .controlSize(.mini)
                    }
                    Spacer()
                    Button {
                        settings.customActivities = custom.filter { $0 != item }
                        settings.setCountsAsWorkout(false, custom: item)
                        ActivityIcons.shared.removeCustom(item)
                    } label: {
                        Image(systemName: "minus.circle").foregroundStyle(Theme.red)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Odebrat \(item)")
                }
                .listSwipeToDelete("Odebrat") {
                    settings.customActivities = custom.filter { $0 != item }
                    settings.setCountsAsWorkout(false, custom: item)
                    ActivityIcons.shared.removeCustom(item)
                }
            }
            Button {
                withAnimation { isAdding.toggle() }
            } label: {
                Label(isAdding ? "Zrušit" : "Přidat vlastní aktivitu", systemImage: isAdding ? "xmark" : "plus")
                    .scaledFont(.body, weight: .semibold)
                    .foregroundStyle(Theme.textPrimary)
            }
            if isAdding {
                TextField("Např. Kytara", text: $newActivity)
                Toggle("Počítá se jako trénink", isOn: $newIsWorkout)
                    .tint(Theme.textSecondary)
                Button("ULOŽIT") {
                    settings.customActivities = custom + [name]
                    settings.setCountsAsWorkout(newIsWorkout, custom: name)
                    ActivityIcons.shared.register(custom: [name])
                    newActivity = ""
                    newIsWorkout = false
                    withAnimation { isAdding = false }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(name.isEmpty || custom.contains { $0.activityKey == name.activityKey })
                .listRowInsets(EdgeInsets(top: 10, leading: 14, bottom: 12, trailing: 14))
            }
        } header: {
            Text("Vlastní")
        } footer: {
            Text("Vlastní aktivity se plánují pod kategorií Ostatní a mají svoje jméno. Najdeš je jako zkratky v Rychlém plánování i v novém úkolu. Aktivita označená jako trénink (třeba lezení nebo plavání) se počítá do odznaků a přehledu tréninků ve Zdraví, stejně jako Gym a Sport.")
        }
        .listRowBackground(Theme.card)
    }
}
