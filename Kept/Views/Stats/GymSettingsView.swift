import SwiftUI
import SwiftData

/// Everything that configures the gym part of the app: what gets offered when logging a workout,
/// the weekly target and the default rest between sets.
struct GymSettingsView: View {
    @Query private var settingsList: [UserSettings]
    @State private var newRestName = ""
    @State private var newRestSeconds = 120
    @State private var newPreset = ""
    @State private var newExercise = ""

    var body: some View {
        Form {
            if let settings = settingsList.first {
                Section {
                    let target = settings.weeklyTarget(for: .gym)
                    Stepper(target == 0 ? "Týdenní cíl: bez cíle" : "Týdenní cíl: \(target)× týdně",
                            value: Binding(get: { target }, set: { settings.setWeeklyTarget($0, for: .gym) }),
                            in: UserSettings.weeklyTargetRange)
                } header: {
                    Text("Trénink")
                } footer: {
                    Text(settings.healthEnabled
                         ? "Když Apple Health zaznamená silový trénink, pošle ti Kept upozornění, ze kterého ho rovnou zapíšeš."
                         : "Po propojení s Apple Health (Nastavení → Zdraví) ti Kept pošle upozornění, když Health zaznamená silový trénink.")
                }
                .listRowBackground(Theme.card)

                restSection(settings)
                presetList(title: "Co jsem jel", placeholder: "Nová partie", text: $newPreset,
                           footer: "Nabízí se při zápisu tréninku. Břicho se zaškrtává zvlášť ke každému tréninku.",
                           items: Bindable(settings).workoutPresets)
                presetList(title: "Cviky", placeholder: "Nový cvik", text: $newExercise,
                           footer: "Odebrání cviku ze seznamu nesmaže jeho historii ve statistikách.",
                           items: Bindable(settings).exercisePresets)
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Nastavení gymu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }

    /// Rest lengths offered in the stopwatch. Any of them can be removed, but one always stays.
    private func restSection(_ settings: UserSettings) -> some View {
        let name = newRestName.trimmingCharacters(in: .whitespacesAndNewlines)
        let presets = settings.restPresets
        return Section {
            ForEach(presets) { preset in
                HStack {
                    Text(preset.name)
                    Spacer()
                    Text(FocusView.clock(TimeInterval(preset.seconds)))
                        .foregroundStyle(Theme.textSecondary)
                        .monospacedDigit()
                    Button {
                        settings.restPresets = presets.filter { $0 != preset }
                    } label: {
                        Image(systemName: "minus.circle").foregroundStyle(presets.count > 1 ? Theme.red : Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .disabled(presets.count <= 1)
                }
            }
            TextField("Název vlastní pauzy", text: $newRestName)
            Stepper("Délka: \(FocusView.clock(TimeInterval(newRestSeconds)))", value: $newRestSeconds,
                    in: RestPreset.secondsRange, step: RestPreset.secondsStep)
            Button("Přidat pauzu") {
                settings.restPresets = presets + [RestPreset(name: name, seconds: newRestSeconds)]
                newRestName = ""
            }
            .disabled(name.isEmpty || presets.contains { $0.name == name })
        } header: {
            Text("Pauzy mezi sériemi")
        } footer: {
            Text("Na délce pauz se lidé neshodnou, proto si je nastav podle sebe. Ve stopkách pak vybíráš z tohoto seznamu.")
        }
        .listRowBackground(Theme.card)
    }

    /// An editable list of names with a field to add another.
    private func presetList(title: String, placeholder: String, text: Binding<String>, footer: String,
                            items: Binding<[String]>) -> some View {
        let name = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return Section {
            ForEach(items.wrappedValue, id: \.self) { item in
                HStack {
                    Text(item)
                    Spacer()
                    Button {
                        items.wrappedValue.removeAll { $0 == item }
                    } label: {
                        Image(systemName: "minus.circle").foregroundStyle(Theme.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                TextField(placeholder, text: text)
                Button("Přidat") {
                    if !items.wrappedValue.contains(name) {
                        items.wrappedValue.append(name)
                    }
                    text.wrappedValue = ""
                }
                .disabled(name.isEmpty)
            }
        } header: {
            Text(title)
        } footer: {
            Text(footer)
        }
        .listRowBackground(Theme.card)
    }
}
