import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Query private var settingsList: [UserSettings]
    @State private var authorization: UNAuthorizationStatus = .notDetermined
    @AppStorage("introVideoEnabled") private var introEnabled = false
    /// The system permission question was just answered with "no".
    @State private var calendarDenied = false
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.dark.rawValue

    fileprivate static let multiplierRange = 0.2...1.0
    fileprivate static let multiplierStep = 0.05
    private static let hourRange = 5...23
    private static let overdueOptions = [20, 30, 45, 60, 90]

    var body: some View {
        NavigationStack {
            Form {
                Section("Vzhled") {
                    Picker("Vzhled", selection: $appearanceRaw) {
                        ForEach(AppAppearance.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Theme.card)
                if let settings = settingsList.first {
                    tabsSection(settings)
                    hiddenScreensSection(settings)
                    permissionSection
                    toneSection(settings)
                    remindersSection(settings)
                    dailySection(settings)
                    sundaySection(settings)
                    targetsSection(settings)
                    gymSection
                    healthSection(settings)
                    calendarSection(settings)
                    diarySection(settings)
                    weightsSection(settings)
                }
                Section {
                    Toggle("Úvodní video", isOn: $introEnabled)
                        .tint(Theme.textSecondary)
                } footer: {
                    Text("Přehraje se při spuštění aplikace, ve výchozím stavu bez zvuku. Klepnutím ho přeskočíš.")
                }
                .listRowBackground(Theme.card)

                // DEVELOPER VERSION ONLY — remove before real testing (see DeveloperSection.swift).
                #if DEBUG
                DeveloperSection()
                #endif

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
            Button {
                Task { await NotificationManager.sendPreview(tone: settings.tone) }
            } label: {
                Label("POSLAT UKÁZKU ZA 5 SEKUND", systemImage: "bell.badge")
            }
            .buttonStyle(SecondaryButtonStyle())
            .listRowInsets(EdgeInsets(top: 10, leading: 14, bottom: 12, trailing: 14))
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
        Section {
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
            Toggle("Hlídání série", isOn: Bindable(settings).streakRemindersEnabled)
                .tint(Theme.textSecondary)
        } header: {
            Text("Denně")
        } footer: {
            Text("Hlídání série tě večer upozorní, že plamínek o půlnoci zhasne. Když zhasne, připomíná se Kept sám ještě týden, čím dál řidčeji, i když aplikaci neotevřeš.")
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
            Text("Každou hodinu v neděli, dokud neodešleš plánovač na příští týden.")
        }
        .listRowBackground(Theme.card)
    }

    private func targetsSection(_ settings: UserSettings) -> some View {
        Section {
            Stepper(settings.postponeLimit == 0 ? "Odklady: vypnuto" : "Odklady: \(settings.postponeLimit)× za měsíc",
                    value: Bindable(settings).postponeLimit, in: UserSettings.postponeLimitRange)
            Stepper(settings.minimumWeeklyTasks == 0 ? "Minimum aktivit: vypnuto" : "Minimum aktivit: \(settings.minimumWeeklyTasks) týdně",
                    value: Bindable(settings).minimumWeeklyTasks, in: UserSettings.minimumWeeklyTasksRange)
            // The gym target is set in the gym settings.
            ForEach(TaskCategory.allCases.filter { $0 != .gym }) { category in
                let target = settings.weeklyTarget(for: category)
                Stepper(target == 0 ? "\(category.title): bez cíle" : "\(category.title): \(target)× týdně",
                        value: Binding(get: { target }, set: { settings.setWeeklyTarget($0, for: category) }),
                        in: UserSettings.weeklyTargetRange)
            }
        } header: {
            Text("Týdenní cíle")
        } footer: {
            Text("Odklad přesune úkol na jiný den bez postihu; víc než 3 za měsíc nastavit nejde, jen míň. Plán s méně aktivitami, než je minimum, nejde na nový týden odeslat. Když za cílem kategorie zaostáváš, aplikace ti úkol sama navrhne na obrazovce Dnes a při plánování týdne upozorní, že ho plán nepokrývá.")
        }
        .listRowBackground(Theme.card)
    }

    private var gymSection: some View {
        Section {
            NavigationLink {
                GymSettingsView()
            } label: {
                Label("Nastavení gymu", systemImage: TaskCategory.gym.symbol)
            }
        } header: {
            Text("Gym")
        } footer: {
            Text("Partie, cviky, týdenní cíl a pauzy. Najdeš je i přímo v sekci Gym.")
        }
        .listRowBackground(Theme.card)
    }

    /// Screens whose tab is switched off stay reachable from here.
    @ViewBuilder
    private func hiddenScreensSection(_ settings: UserSettings) -> some View {
        let showsHealth = HealthService.isAvailable && !settings.showsHealthTab
        if !settings.showsStatsTab || !settings.showsGymTab || showsHealth || !settings.showsDiaryTab {
            Section {
                if !settings.showsStatsTab {
                    NavigationLink { StatsView(isEmbedded: true) } label: { Label("Statistiky", systemImage: "chart.bar") }
                }
                if !settings.showsGymTab {
                    NavigationLink { GymProgressView() } label: { Label("Gym", systemImage: TaskCategory.gym.symbol) }
                }
                if showsHealth {
                    NavigationLink { HealthSummaryView(isEmbedded: true) } label: { Label("Zdraví", systemImage: "heart") }
                }
                if !settings.showsDiaryTab {
                    NavigationLink { DiaryView(isEmbedded: true) } label: { Label("Deník", systemImage: "book.closed") }
                }
            } header: {
                Text("Další obrazovky")
            } footer: {
                Text("Co nemáš ve spodní liště, otevřeš odtud.")
            }
            .listRowBackground(Theme.card)
        }
    }

    private func tabsSection(_ settings: UserSettings) -> some View {
        let isFull = settings.optionalTabCount >= UserSettings.maxOptionalTabs
        return Section {
            LabeledContent("Vždy zobrazené", value: "Dnes · Týden · Nastavení")
            tabToggle("Statistiky", "chart.bar", Bindable(settings).showsStatsTab, isFull: isFull)
            tabToggle("Gym", TaskCategory.gym.symbol, Bindable(settings).showsGymTab, isFull: isFull)
            if HealthService.isAvailable {
                tabToggle("Zdraví", "heart", Bindable(settings).showsHealthTab, isFull: isFull)
            }
            tabToggle("Deník", "book.closed", Bindable(settings).showsDiaryTab, isFull: isFull)
        } header: {
            Text("Záložky")
        } footer: {
            Text(isFull
                 ? "Navíc můžeš mít nejvýš \(UserSettings.maxOptionalTabs) záložky. Pro další nejdřív jednu vypni. Vypnuté obrazovky otevřeš níž v části Další obrazovky."
                 : "Vyber si, co chceš mít ve spodní liště. Navíc můžeš mít nejvýš \(UserSettings.maxOptionalTabs) záložky a kdykoli to tady změníš. Vypnuté obrazovky zůstanou dostupné níž v části Další obrazovky.")
        }
        .listRowBackground(Theme.card)
    }

    /// A tab that is off cannot be switched on once the limit is reached.
    private func tabToggle(_ title: String, _ symbol: String, _ isOn: Binding<Bool>, isFull: Bool) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: symbol)
        }
        .tint(Theme.textSecondary)
        .disabled(isFull && !isOn.wrappedValue)
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

    private func calendarSection(_ settings: UserSettings) -> some View {
        Section {
            Toggle("Kalendář iPhonu", isOn: Binding(
                get: { settings.calendarEnabled && CalendarService.isAuthorized },
                set: { enabled in
                    guard enabled else {
                        settings.calendarEnabled = false
                        return
                    }
                    Task {
                        // Stays off when the permission is refused.
                        settings.calendarEnabled = await CalendarService.requestAccess()
                        calendarDenied = !settings.calendarEnabled
                    }
                }))
                .tint(Theme.textSecondary)
            if calendarDenied || (settings.calendarEnabled && CalendarService.isDenied) {
                Text("Kept nemá ke kalendáři přístup. Povol ho v Nastavení iPhonu → Aplikace → Kept → Kalendáře (úplný přístup).")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.orange)
                Button("Otevřít Nastavení iPhonu") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        } header: {
            Text("Kalendář")
        } footer: {
            Text("Při plánování týdne uvidíš u každého dne, co už máš v kalendáři, a editor úkolu upozorní, když se úkol s něčím kryje. Kept kalendář jen čte, nic do něj nezapisuje a události si neukládá.")
        }
        .listRowBackground(Theme.card)
    }

    private func diarySection(_ settings: UserSettings) -> some View {
        Section {
            Toggle("Hlasový zápis", isOn: Bindable(settings).diaryVoiceEnabled)
                .tint(Theme.textSecondary)
            Toggle("Zamknout deník Face ID", isOn: Bindable(settings).diaryLockEnabled)
                .tint(Theme.textSecondary)
        } header: {
            Text("Deník")
        } footer: {
            Text("Hlasový zápis přidá k polím deníku mikrofon; iPhone se poprvé zeptá na přístup k mikrofonu a rozpoznávání řeči. Zámek schová deník za Face ID nebo kód a zamkne ho pokaždé, když aplikaci opustíš. Za každý den se zápisem dostaneš \(DiaryService.pointsPerEntry) bodů.")
        }
        .listRowBackground(Theme.card)
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
                    .tint(Theme.textPrimary)
            }
        }
    }
}
