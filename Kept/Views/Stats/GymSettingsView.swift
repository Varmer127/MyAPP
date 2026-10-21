import SwiftUI
import SwiftData

/// Everything that configures the gym part of the app: what gets offered when logging a workout,
/// the weekly target and the rest lengths between sets.
struct GymSettingsView: View {
    @Query private var settingsList: [UserSettings]
    @State private var newPreset = ""
    @State private var newExercise = ""
    @State private var newRestName = ""
    @State private var newRestSeconds = 120
    @State private var isAddingRest = false
    @State private var isAddingPreset = false
    @State private var isAddingExercise = false

    var body: some View {
        Form {
            if let settings = settingsList.first {
                Section {
                    Picker("Režim", selection: Bindable(settings).gymMode) {
                        ForEach(GymMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    GymModePreview(mode: settings.gymMode)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Režim")
                } footer: {
                    Text("Přepnout můžeš kdykoli. Nic se tím nesmaže: cviky, série a rekordy z pokročilého režimu jen zůstanou schované a po přepnutí zpět je zase uvidíš.")
                }
                .listRowBackground(Theme.card)

                Section {
                    let target = settings.weeklyTarget(for: .gym)
                    Stepper(target == 0 ? "Týdenní cíl: bez cíle" : "Týdenní cíl: asi \(target)× týdně",
                            value: Binding(get: { target }, set: { settings.setWeeklyTarget($0, for: .gym) }),
                            in: UserSettings.weeklyTargetRange)
                } header: {
                    Text("Trénink")
                } footer: {
                    Text("Orientační: jeden týden 3×, druhý 6× je v pořádku, žádný postih. Jak cíl plníš, se z 10 % promítá do spolehlivosti a podle něj ti Kept gym navrhuje. "
                         + (settings.healthEnabled
                            ? "Když Apple Health zaznamená silový trénink, pošle ti Kept upozornění, ze kterého ho rovnou zapíšeš."
                            : "Po propojení s Apple Health (Nastavení → Zdraví) ti Kept pošle upozornění, když Health zaznamená silový trénink."))
                }
                .listRowBackground(Theme.card)

                restSection(settings)
                presetList(title: "Co jsem jel", addLabel: "Přidat partii", placeholder: "Název partie",
                           text: $newPreset, isAdding: $isAddingPreset,
                           footer: "Nabízí se při zápisu tréninku. Břicho se zaškrtává zvlášť ke každému tréninku.",
                           items: Bindable(settings).workoutPresets)
                if settings.gymMode == .advanced {
                    presetList(title: "Cviky", addLabel: "Přidat cvik", placeholder: "Název cviku",
                               text: $newExercise, isAdding: $isAddingExercise,
                               footer: "Odebrání cviku ze seznamu nesmaže jeho historii ve statistikách.",
                               items: Bindable(settings).exercisePresets)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Nastavení gymu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }

    /// The last row of every list: a plus that unfolds the fields for a new entry.
    private func addRow(_ label: String, isAdding: Binding<Bool>) -> some View {
        Button {
            withAnimation { isAdding.wrappedValue.toggle() }
        } label: {
            Label(isAdding.wrappedValue ? "Zrušit" : label, systemImage: isAdding.wrappedValue ? "xmark" : "plus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private func removeButton(enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "minus.circle").foregroundStyle(enabled ? Theme.red : Theme.textTertiary)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    /// Rest lengths offered in the stopwatch. Any of them can be removed, but one always stays.
    private func restSection(_ settings: UserSettings) -> some View {
        let name = newRestName.trimmingCharacters(in: .whitespacesAndNewlines)
        let presets = settings.restPresets
        return Section {
            ForEach(presets) { preset in
                HStack {
                    Text(preset.name)
                    if preset == presets.first {
                        Text("VÝCHOZÍ")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(Theme.green)
                    }
                    Spacer()
                    Text(FocusView.clock(TimeInterval(preset.seconds)))
                        .foregroundStyle(Theme.textSecondary)
                        .monospacedDigit()
                    removeButton(enabled: presets.count > 1) {
                        settings.restPresets = presets.filter { $0 != preset }
                    }
                }
                .listSwipeToDelete(isEnabled: presets.count > 1) {
                    settings.restPresets = presets.filter { $0 != preset }
                }
            }
            .onMove { from, to in
                var reordered = presets
                reordered.move(fromOffsets: from, toOffset: to)
                settings.restPresets = reordered
            }
            addRow("Přidat vlastní pauzu", isAdding: $isAddingRest)
            if isAddingRest {
                TextField("Název pauzy", text: $newRestName)
                Stepper("Délka: \(FocusView.clock(TimeInterval(newRestSeconds)))", value: $newRestSeconds,
                        in: RestPreset.secondsRange, step: RestPreset.secondsStep)
                Button("ULOŽIT PAUZU") {
                    settings.restPresets = presets + [RestPreset(name: name, seconds: newRestSeconds)]
                    newRestName = ""
                    withAnimation { isAddingRest = false }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(name.isEmpty || presets.contains { $0.name == name })
                .listRowInsets(EdgeInsets(top: 10, leading: 14, bottom: 12, trailing: 14))
            }
        } header: {
            Text("Pauzy mezi sériemi")
        } footer: {
            Text("Na délce pauz se lidé neshodnou, proto si je nastav podle sebe. Podrž pauzu a přetáhni ji: ta nahoře se ve stopkách nastaví jako výchozí, ostatní přepneš během tréninku.")
        }
        .listRowBackground(Theme.card)
    }

    /// An editable list of names ending with a row that unfolds a field for a new one.
    private func presetList(title: String, addLabel: String, placeholder: String, text: Binding<String>,
                            isAdding: Binding<Bool>, footer: String, items: Binding<[String]>) -> some View {
        let name = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return Section {
            ForEach(items.wrappedValue, id: \.self) { item in
                HStack {
                    Text(item)
                    Spacer()
                    removeButton { items.wrappedValue.removeAll { $0 == item } }
                }
                .listSwipeToDelete { items.wrappedValue.removeAll { $0 == item } }
            }
            addRow(addLabel, isAdding: isAdding)
            if isAdding.wrappedValue {
                TextField(placeholder, text: text)
                Button("ULOŽIT") {
                    items.wrappedValue.append(name)
                    text.wrappedValue = ""
                    withAnimation { isAdding.wrappedValue = false }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(name.isEmpty || items.wrappedValue.contains(name))
                .listRowInsets(EdgeInsets(top: 10, leading: 14, bottom: 12, trailing: 14))
            }
        } header: {
            Text(title)
        } footer: {
            Text(footer)
        }
        .listRowBackground(Theme.card)
    }
}
