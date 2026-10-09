import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Query private var settingsList: [UserSettings]
    @State private var authorization: UNAuthorizationStatus = .notDetermined
    @State private var newPreset = ""
    @State private var newExercise = ""
    @AppStorage("introEnabled") private var introEnabled = true

    fileprivate static let multiplierRange = 0.2...1.0
    fileprivate static let multiplierStep = 0.05
    private static let hourRange = 5...23
    private static let overdueOptions = [20, 30, 45, 60, 90]

    var body: some View {
        NavigationStack {
            Form {
                if let settings = settingsList.first {
                    permissionSection
                    toneSection(settings)
                    remindersSection(settings)
                    dailySection(settings)
                    sundaySection(settings)
                    targetsSection(settings)
                    presetsSection(settings)
                    exercisesSection(settings)
                    healthSection(settings)
                    weightsSection(settings)
                }
                Section {
                    Toggle("Úvodní video", isOn: $introEnabled)
                        .tint(Theme.textSecondary)
                } footer: {
                    Text("Přehraje se při spuštění aplikace, ve výchozím stavu bez zvuku. Klepnutím ho přeskočíš.")
                }
                .listRowBackground(Theme.card)

                Section("O aplikaci") {
                    LabeledContent("Verze", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    LabeledContent("Data", value: "Jen v tomto zařízení")
                    LabeledContent("Šablony notifikací", value: "\(NotificationTemplates.totalCount)")
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Nastavení")
            .toolbarBackground(Theme.background, for: .navigationBar)
            .task(id: scenePhase) {
                authorization = await NotificationManager.authorizationStatus()
            }
        }
    }

    @ViewBuilder
    private var permissionSection: some View {
        if authorization == .denied {
            Section {
                Text("Notifikace pro Kept jsou v Nastavení iOS vypnuté. Bez nich ti aplikace nemůže nic připomenout.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.red)
                Button("Otevřít Nastavení iOS") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        openURL(url)
                    }
                }
            }
            .listRowBackground(Theme.card)
        } else if authorization == .notDetermined {
            Section {
                Button("Povolit notifikace") {
                    Task {
                        await NotificationManager.requestAuthorization()
                        authorization = await NotificationManager.authorizationStatus()
                    }
                }
            }
            .listRowBackground(Theme.card)
        }
    }

    private func toneSection(_ settings: UserSettings) -> some View {
        Section {
            Picker("Tón", selection: Bindable(settings).toneRaw) {
                ForEach(NotificationTone.allCases) { Text($0.title).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            Button("Poslat ukázku za 5 sekund") {
                Task { await NotificationManager.sendPreview(tone: settings.tone) }
            }
        } header: {
            Text("Tón notifikací")
        } footer: {
            Text(settings.tone.summary)
        }
        .listRowBackground(Theme.card)
    }

    private func remindersSection(_ settings: UserSettings) -> some View {
        Section {
            Toggle("Připomínky úkolů", isOn: Bindable(settings).taskRemindersEnabled)
                .tint(Theme.textSecondary)
            if settings.taskRemindersEnabled {
                Picker("Opakovat po termínu", selection: Bindable(settings).overdueRepeatMinutes) {
                    ForEach(Self.overdueOptions, id: \.self) { Text("každých \($0) min").tag($0) }
                }
            }
        } header: {
            Text("Úkoly")
        } footer: {
            Text("Úkol s deadlinem se ohlásí 30 minut před začátkem, při startu a pak znovu, dokud není hotový. Kritické úkoly a opakovaná selhání eskalují rychleji.")
        }
        .listRowBackground(Theme.card)
    }

    private func dailySection(_ settings: UserSettings) -> some View {
        Section("Denně") {
            Toggle("Ranní přehled", isOn: Bindable(settings).morningBriefEnabled)
                .tint(Theme.textSecondary)
            if settings.morningBriefEnabled {
                DatePicker("Čas přehledu", selection: timeBinding(Bindable(settings).morningBriefMinutes),
                           displayedComponents: .hourAndMinute)
            }
            Toggle("Večerní bilance", isOn: Bindable(settings).realityCheckEnabled)
                .tint(Theme.textSecondary)
            if settings.realityCheckEnabled {
                DatePicker("Čas bilance", selection: timeBinding(Bindable(settings).realityCheckMinutes),
                           displayedComponents: .hourAndMinute)
            }
        }
        .listRowBackground(Theme.card)
    }

    private func sundaySection(_ settings: UserSettings) -> some View {
        Section {
            Toggle("Nedělní připomínky plánování", isOn: Bindable(settings).sundayRemindersEnabled)
                .tint(Theme.textSecondary)
            if settings.sundayRemindersEnabled {
                Stepper("Od \(settings.sundayStartHour):00", value: Bindable(settings).sundayStartHour,
                        in: Self.hourRange.lowerBound...settings.sundayEndHour)
                Stepper("Do \(settings.sundayEndHour):00", value: Bindable(settings).sundayEndHour,
                        in: settings.sundayStartHour...Self.hourRange.upperBound)
            }
        } header: {
            Text("Plánování týdne")
        } footer: {
            Text("Každou hodinu v neděli, dokud se nezavážeš k příštímu týdnu.")
        }
        .listRowBackground(Theme.card)
    }

    private func targetsSection(_ settings: UserSettings) -> some View {
        Section {
            Stepper(settings.postponeLimit == 0 ? "Odklady: vypnuto" : "Odklady: \(settings.postponeLimit)× za měsíc",
                    value: Bindable(settings).postponeLimit, in: UserSettings.postponeLimitRange)
            Stepper(settings.minimumWeeklyTasks == 0 ? "Minimum aktivit: vypnuto" : "Minimum aktivit: \(settings.minimumWeeklyTasks) týdně",
                    value: Bindable(settings).minimumWeeklyTasks, in: UserSettings.minimumWeeklyTasksRange)
            ForEach(TaskCategory.allCases) { category in
                let target = settings.weeklyTarget(for: category)
                Stepper(target == 0 ? "\(category.title): bez cíle" : "\(category.title): \(target)× týdně",
                        value: Binding(get: { target }, set: { settings.setWeeklyTarget($0, for: category) }),
                        in: UserSettings.weeklyTargetRange)
            }
        } header: {
            Text("Týdenní cíle")
        } footer: {
            Text("Odklad přesune úkol na jiný den bez postihu; víc než 3 za měsíc nastavit nejde, jen míň. Plán s méně aktivitami, než je minimum, nejde na nový týden potvrdit. Když za cílem kategorie zaostáváš, aplikace ti úkol sama navrhne na obrazovce Dnes a při plánování týdne upozorní, že ho plán nepokrývá.")
        }
        .listRowBackground(Theme.card)
    }

    private func exercisesSection(_ settings: UserSettings) -> some View {
        Section {
            ForEach(settings.exercisePresets, id: \.self) { preset in
                HStack {
                    Text(preset)
                    Spacer()
                    Button {
                        settings.exercisePresets.removeAll { $0 == preset }
                    } label: {
                        Image(systemName: "minus.circle").foregroundStyle(Theme.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                TextField("Nový cvik", text: $newExercise)
                Button("Přidat") {
                    let name = newExercise.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty, !settings.exercisePresets.contains(name) {
                        settings.exercisePresets.append(name)
                    }
                    newExercise = ""
                }
                .disabled(newExercise.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } header: {
            Text("Gym – cviky")
        } footer: {
            Text("Nabízejí se při zápisu tréninku. Odebrání cviku ze seznamu nesmaže jeho historii ve statistikách.")
        }
        .listRowBackground(Theme.card)
    }

    private func presetsSection(_ settings: UserSettings) -> some View {
        Section {
            ForEach(settings.workoutPresets, id: \.self) { preset in
                HStack {
                    Text(preset)
                    Spacer()
                    Button {
                        settings.workoutPresets.removeAll { $0 == preset }
                    } label: {
                        Image(systemName: "minus.circle").foregroundStyle(Theme.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                TextField("Nová předvolba", text: $newPreset)
                Button("Přidat") {
                    let name = newPreset.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty, !settings.workoutPresets.contains(name) {
                        settings.workoutPresets.append(name)
                    }
                    newPreset = ""
                }
                .disabled(newPreset.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } header: {
            Text("Gym – co jsem jel")
        } footer: {
            Text("Nabízí se při splnění úkolu v kategorii Gym. Břicho se zaškrtává zvlášť ke každému tréninku.")
        }
        .listRowBackground(Theme.card)
    }

    @ViewBuilder
    private func healthSection(_ settings: UserSettings) -> some View {
        if HealthService.isAvailable {
            Section {
                Toggle("Apple Health", isOn: Binding(
                    get: { settings.healthEnabled },
                    set: { enabled in
                        settings.healthEnabled = enabled
                        if enabled {
                            Task { await HealthService.requestAccess() }
                        }
                    }))
                    .tint(Theme.textSecondary)
            } header: {
                Text("Zdraví")
            } footer: {
                Text("Kept jen čte: váhu doplní do zápisu tréninku a do grafu, a když Health zaznamená trénink, nabídne ti rovnou splnění Gymu. Nic do Health nezapisuje. Oprávnění změníš v aplikaci Zdraví.")
            }
            .listRowBackground(Theme.card)
        }
    }

    private func weightsSection(_ settings: UserSettings) -> some View {
        Section {
            ForEach(TaskCategory.allCases) { category in
                CategoryWeightRow(category: category, settings: settings)
            }
            Button("Obnovit výchozí") { settings.resetMultipliers() }
        } header: {
            Text("Váhy kategorií")
        } footer: {
            Text("Výchozí váha nového úkolu jsou body priority (nízká 1, střední 2, vysoká 4, kritická 5) × váha kategorie, zaokrouhleno na 1–5. Existující úkoly si váhu ponechají.")
        }
        .listRowBackground(Theme.card)
    }

    /// Bridges "minutes after midnight" to the Date a DatePicker needs.
    private func timeBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { Date.now.startOfDay.addingTimeInterval(TimeInterval(minutes.wrappedValue * 60)) },
            set: { minutes.wrappedValue = $0.minutesIntoDay }
        )
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
