import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var settingsList: [UserSettings]

    private static let multiplierRange = 0.2...1.0
    private static let multiplierStep = 0.05

    var body: some View {
        NavigationStack {
            Form {
                if let settings = settingsList.first {
                    Section {
                        ForEach(TaskCategory.allCases) { category in
                            CategoryWeightRow(category: category, settings: settings)
                        }
                        Button("Reset to defaults") { settings.resetMultipliers() }
                    } header: {
                        Text("Category weights")
                    } footer: {
                        Text("A new task's default weight is its priority points (Low 1, Medium 2, High 4, Critical 5) × the category weight, rounded to 1–5. Existing tasks keep their weight.")
                    }
                    .listRowBackground(Theme.card)
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    LabeledContent("Data", value: "On this device only")
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Settings")
            .toolbarBackground(Theme.background, for: .navigationBar)
        }
    }

    private struct CategoryWeightRow: View {
        let category: TaskCategory
        let settings: UserSettings

        var body: some View {
            let value = Binding(
                get: { settings.multiplier(for: category) },
                set: { settings.setMultiplier($0, for: category) }
            )
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(category.title)
                    Spacer()
                    Text("×\(String(format: "%.2f", value.wrappedValue))")
                        .foregroundStyle(Theme.textSecondary)
                        .monospacedDigit()
                }
                Slider(value: value, in: SettingsView.multiplierRange, step: SettingsView.multiplierStep)
                    .tint(.white)
            }
        }
    }
}
