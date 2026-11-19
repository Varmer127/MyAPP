import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Query private var settingsList: [UserSettings]
    @State private var authorization: UNAuthorizationStatus = .notDetermined
    /// The system permission question was just answered with "no".
    @State private var calendarDenied = false
    /// The tab someone just tried to add to a full bar, and how many times each row has shaken.
    @State private var blockedTab: String?
    @State private var tabShakes: [String: Int] = [:]
    @State private var fullBarShakes = 0
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.dark.rawValue

    fileprivate static let multiplierRange = 0.2...1.0
    fileprivate static let multiplierStep = 0.05
    private static let hourRange = 5...23
    private static let overdueOptions = [20, 30, 45, 60, 90]

    /// The settings are split into pages; the first screen only lists them with a line about what is set in each.
    private enum Page: String, Hashable, CaseIterable, Identifiable {
        case tabs, notifications, activities, gym, health, calendar, diary
        var id: String { rawValue }

        var title: LocalizedStringKey {
            switch self {
            case .tabs: "Záložky"
            case .notifications: "Upozornění"
            case .activities: "Aktivity a cíle"
            case .gym: "Gym"
            case .health: "Zdraví"
            case .calendar: "Kalendář iPhonu"
            case .diary: "Deník a soukromí"
            }
        }

        var symbol: String {
            switch self {
            case .tabs: "rectangle.bottomhalf.inset.filled"
            case .notifications: "bell"
            case .activities: "target"
            case .gym: "dumbbell"
            case .health: "heart"
            case .calendar: "calendar"
            case .diary: "book.closed"
            }
        }
    }

    @State private var path: [Page] = []
    @State private var showsRegistration = false

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section {
                    ProfileCard()
                }
                .listRowBackground(Theme.card)
                appearanceSection
                permissionSection
                accountSection
                if let settings = settingsList.first {
                    Section {
                        ForEach(Page.allCases) { page in
                            NavigationLink(value: page) { pageRow(page, settings) }
                        }
                    }
                    .listRowBackground(Theme.card)
                }

                // DEVELOPER VERSION ONLY — remove before real testing (see DeveloperSection.swift).
                #if DEBUG
                DeveloperSection()
                #endif

                LegalSection()

                Section("O aplikaci") {
                    LabeledContent("Verze", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    // With an account the profile and the shared features live on the server, so this names what really stays here.
                    LabeledContent("Úkoly, deník a zdraví", value: String(localized: "Jen v tomto zařízení", bundle: .kept, locale: .kept))
                    LabeledContent("Šablony notifikací", value: "\(NotificationTemplates.totalCount)")
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .sheet(isPresented: $showsRegistration) { RegistrationView() }
            .navigationTitle("Nastavení")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .navigationDestination(for: Page.self) { page in
                if let settings = settingsList.first { pageView(page, settings) }
            }
            .task(id: scenePhase) {
                authorization = await NotificationManager.authorizationStatus()
            }
            // Choosing the Settings tab again, while it is open, goes back to this first screen.
            .onReceive(NotificationCenter.default.publisher(for: .tabReselected)) { note in
                if note.object as? AppTab == .settings { path.removeAll() }
            }
        }
    }

    /// Sign-in is optional; this is the one place in Settings where it is offered and managed.
    @ViewBuilder
    private var accountSection: some View {
        let account = AccountService.shared
        Section {
            switch account.state {
            case .ready(let profile):
                NavigationLink {
                    AccountView()
                } label: {
                    LabeledContent {
                        Text(profile.handle).foregroundStyle(Theme.textSecondary)
                    } label: {
                        Label("Účet", systemImage: "person.crop.circle")
                    }
                }
            case .unavailable:
                Button { Task { await account.reload() } } label: {
                    Label("Účet se nenačetl, zkusit znovu", systemImage: "arrow.clockwise")
                }
            case .needsProfile:
                Button { showsRegistration = true } label: {
                    Label("Dokončit registraci", systemImage: "person.crop.circle.badge.plus")
                }
            case .unknown, .signedOut:
                Button { showsRegistration = true } label: {
                    Label("Registrovat se nebo přihlásit", systemImage: "person.crop.circle.badge.plus")
                }
            }
            NavigationLink {
                FriendsView()
            } label: {
                LabeledContent {
                    if !account.isSignedIn {
                        Image(systemName: "lock.fill").foregroundStyle(Theme.textSecondary)
                    } else if FriendsService.shared.incoming.count + FriendsService.shared.unreadPokes > 0 {
                        Text("\(FriendsService.shared.incoming.count + FriendsService.shared.unreadPokes)")
                            .scaledFont(.caption, weight: .bold)
                            .foregroundStyle(Theme.onPrimary)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Theme.textPrimary).clipShape(Capsule())
                    }
                } label: {
                    Label("Přátelé", systemImage: "person.2")
                }
            }
        } footer: {
            if !account.isSignedIn {
                Text("Volitelné. S účtem můžeš mít přátele. Bez něj Kept funguje jako dosud.")
            }
        }
        .listRowBackground(Theme.card)
    }

    private func pageRow(_ page: Page, _ settings: UserSettings) -> some View {
        HStack(spacing: 12) {
            Image(systemName: page.symbol)
                .scaledFont(.body, weight: .semibold)
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 32, height: 32)
                .background(Theme.cardRaised)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(page.title)
                    .foregroundStyle(Theme.textPrimary)
                Text(summary(of: page, settings))
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
    }

    /// One line on what is set on a page, so most of the time there is no need to open it.
    private func summary(of page: Page, _ settings: UserSettings) -> String {
        switch page {
        case .tabs:
            return String(localized: "Navíc \(settings.optionalTabCount) ze \(UserSettings.maxOptionalTabs)", bundle: .kept, locale: .kept)
        case .notifications:
            guard settings.taskRemindersEnabled || settings.realityCheckEnabled || settings.morningBriefEnabled else { return String(localized: "Vypnuto", bundle: .kept, locale: .kept) }
            let nudges = settings.nudgesPerDay > 0 ? String(localized: "úkoly bez termínu \(settings.nudgesPerDay)× denně", bundle: .kept, locale: .kept) : String(localized: "úkoly bez termínu bez připomínek", bundle: .kept, locale: .kept)
            return "\(settings.tone.title) · \(nudges)"
        case .activities:
            return String(localized: "Aktivit: \(settings.enabledCategories.count - 1 + settings.customActivities.count)", bundle: .kept, locale: .kept)
        case .gym:
            return String(localized: "Partie, cviky, pauzy", bundle: .kept, locale: .kept)
        case .health:
            return settings.healthEnabled ? String(localized: "Propojeno, cíl \(settings.stepGoal.formatted(.number.locale(.app))) kroků", bundle: .kept, locale: .kept) : String(localized: "Nepropojeno", bundle: .kept, locale: .kept)
        case .calendar:
            return settings.calendarEnabled ? String(localized: "Zapnuto", bundle: .kept, locale: .kept) : String(localized: "Vypnuto", bundle: .kept, locale: .kept)
        case .diary:
            let lock = settings.diaryLockEnabled || settings.appLockEnabled ? String(localized: "zámek zapnutý", bundle: .kept, locale: .kept) : String(localized: "bez zámku", bundle: .kept, locale: .kept)
            return (settings.diaryEnabled ? String(localized: "Deník zapnutý", bundle: .kept, locale: .kept) : String(localized: "Deník vypnutý", bundle: .kept, locale: .kept)) + " · " + lock
        }
    }

    @ViewBuilder
    private func pageView(_ page: Page, _ settings: UserSettings) -> some View {
        switch page {
        case .gym:
            GymSettingsView()
        default:
            Form {
                switch page {
                case .tabs:
                    tabsPreviewSection(settings)
                    tabsSection(settings)
                    hiddenScreensSection(settings)
                case .notifications:
                    toneSection(settings)
                    remindersSection(settings)
                    dailySection(settings)
                    sundaySection(settings)
                case .activities:
                    activitiesSection(settings)
                    targetsSection(settings)
                    weightsSection(settings)
                case .health:
                    healthSection(settings)
                case .calendar:
                    calendarSection(settings)
                case .diary:
                    diarySection(settings)
                    privacySection(settings)
                    DataExportSection(settings: settings)
                case .gym:
                    EmptyView()
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(page.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
        }
    }

    /// Light, dark or the system setting, one tap under the name.
    private var appearanceSection: some View {
        Section {
            Picker("Vzhled", selection: $appearanceRaw) {
                ForEach(AppAppearance.allCases) { Text($0.title).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            LanguageRow()
        }
        .listRowBackground(Theme.card)
    }

    private func nameSection(_ settings: UserSettings) -> some View {
        Section {
            TextField("Oslovení, např. Filipe", text: Bindable(settings).addressName)
            // Grammatical gender only exists in Czech.
            if AppLanguage.current == .cs {
                Picker("Mluvit se mnou", selection: Bindable(settings).grammar) {
                    ForEach(GrammarGender.allCases) { Text($0.title).tag($0) }
                }
            }
        } header: {
            Text("Ty")
        } footer: {
            Text("Takhle tě Kept oslovuje ráno a v textech. Napiš oslovení tak, jak ho chceš číst, třeba „Filipe“ nebo „Anežko“.")
        }
        .listRowBackground(Theme.card)
    }

    @ViewBuilder
    private var permissionSection: some View {
        if authorization == .denied {
            Section {
                Text("Notifikace pro Kept jsou v Nastavení iOS vypnuté. Bez nich ti aplikace nemůže nic připomenout.")
                    .scaledFont(.caption)
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
                Picker("Úkoly bez termínu", selection: Bindable(settings).nudgesPerDay) {
                    Text("nepřipomínat").tag(0)
                    ForEach(1...NotificationManager.maxNudgesPerDay, id: \.self) { Text("\($0)× denně").tag($0) }
                }
                if settings.nudgesPerDay > 0 {
                    DatePicker("Připomínat od", selection: timeBinding(Bindable(settings).nudgeFromMinutes),
                               displayedComponents: .hourAndMinute)
                    DatePicker("Připomínat do", selection: timeBinding(Bindable(settings).nudgeToMinutes),
                               displayedComponents: .hourAndMinute)
                }
            }
        } header: {
            Text("Úkoly")
        } footer: {
            Text("Úkol s deadlinem se ohlásí 30 minut před začátkem, při startu a pak znovu, dokud není hotový. Kritické úkoly a opakovaná selhání eskalují rychleji. Úkoly bez termínu, třeba z rychlého plánu, se připomenou souhrnně: jen ve zvoleném čase, nejvýš tolikrát denně, kolik nastavíš, a ne dřív než po pauze 90 minut. Když je všechno hotové, Kept mlčí.")
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

    private func activitiesSection(_ settings: UserSettings) -> some View {
        Section {
            NavigationLink {
                ActivitiesSettingsView()
            } label: {
                LabeledContent {
                    Text("\(settings.enabledCategories.count - 1 + settings.customActivities.count)")
                } label: {
                    Label("Moje aktivity", systemImage: "square.grid.2x2")
                }
            }
        } header: {
            Text("Aktivity")
        } footer: {
            Text("Čemu se věnuješ. Jen tyhle aktivity Kept nabízí při plánování a navrhuje na obrazovce Dnes.")
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
            ForEach(settings.enabledCategories.filter { $0 != .gym && $0 != .other }) { category in
                let target = settings.weeklyTarget(for: category)
                Stepper(target == 0 ? "\(category.title): bez cíle" : "\(category.title): asi \(target)× týdně",
                        value: Binding(get: { target }, set: { settings.setWeeklyTarget($0, for: category) }),
                        in: UserSettings.weeklyTargetRange)
            }
        } header: {
            Text("Týdenní cíle")
        } footer: {
            Text("Odklad přesune úkol na jiný den bez postihu; víc než 3 za měsíc nastavit nejde, jen míň. Plán s méně aktivitami, než je minimum, nejde na nový týden odeslat. Týdenní cíle jsou orientační: když za nimi zaostáváš, Kept ti aktivitu navrhne, a jak je plníš, se z 10 % promítá do spolehlivosti.")
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
        let showsDiary = settings.diaryEnabled && !settings.showsDiaryTab
        if !settings.showsStatsTab || !settings.showsGymTab || showsHealth || showsDiary {
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
                if showsDiary {
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

    /// The bottom bar as it looks with the current choice, so the effect of each switch is seen at once.
    private func tabsPreviewSection(_ settings: UserSettings) -> some View {
        var items: [(title: LocalizedStringKey, symbol: String)] = [("Dnes", "sun.max"), ("Týden", "calendar")]
        if settings.showsStatsTab { items.append(("Statistiky", "chart.bar")) }
        if settings.showsGymTab { items.append(("Gym", TaskCategory.gym.symbol)) }
        if settings.showsHealthTab { items.append(("Zdraví", "heart")) }
        if settings.showsDiaryTab && settings.diaryEnabled { items.append(("Deník", "book.closed")) }
        items.append(("Nastavení", "gearshape"))
        return Section {
            HStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol)
                            .scaledFont(.body)
                            .frame(height: 24)
                        Text(item.title)
                            .scaledFont(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 10)
            .background(Theme.cardRaised)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .listRowInsets(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Spodní lišta")
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.red, lineWidth: 2).opacity(blockedTab == nil ? 0 : 1))
            .modifier(ShakeEffect(amount: 5, animatableData: CGFloat(fullBarShakes)))
        } header: {
            Text("Spodní lišta teď")
        }
        .listRowBackground(Theme.card)
    }

    private func tabsSection(_ settings: UserSettings) -> some View {
        let isFull = settings.optionalTabCount >= UserSettings.maxOptionalTabs
        return Section {
            LabeledContent("Vždy v liště", value: String(localized: "Dnes · Týden · Nastavení", bundle: .kept, locale: .kept))
            tabToggle(String(localized: "Statistiky", bundle: .kept, locale: .kept), "chart.bar", Bindable(settings).showsStatsTab, isFull: isFull)
            tabToggle(String(localized: "Gym", bundle: .kept, locale: .kept), TaskCategory.gym.symbol, Bindable(settings).showsGymTab, isFull: isFull)
            if HealthService.isAvailable {
                tabToggle(String(localized: "Zdraví", bundle: .kept, locale: .kept), "heart", Bindable(settings).showsHealthTab, isFull: isFull)
            }
            if settings.diaryEnabled {
                tabToggle(String(localized: "Deník", bundle: .kept, locale: .kept), "book.closed", Bindable(settings).showsDiaryTab, isFull: isFull)
            }
        } header: {
            Text("Navíc v liště: \(settings.optionalTabCount) ze \(UserSettings.maxOptionalTabs)")
                .foregroundStyle(blockedTab == nil ? Theme.textSecondary : Theme.red)
                .scaleEffect(blockedTab == nil ? 1 : 1.08, anchor: .leading)
        } footer: {
            Text(isFull
                 ? "Navíc můžeš mít nejvýš \(UserSettings.maxOptionalTabs) záložky. Pro další nejdřív jednu vypni. Vypnuté obrazovky otevřeš níž v části Další obrazovky."
                 : "Vyber si, co chceš mít ve spodní liště. Navíc můžeš mít nejvýš \(UserSettings.maxOptionalTabs) záložky a kdykoli to tady změníš. Vypnuté obrazovky zůstanou dostupné níž v části Další obrazovky.")
        }
        .listRowBackground(Theme.card)
    }

    /// A tab that is off cannot be switched on once the limit is reached. Trying anyway shakes the row,
    /// flashes the counter and the bar red and says what to do, instead of a switch that silently does nothing.
    private func tabToggle(_ title: String, _ symbol: String, _ isOn: Binding<Bool>, isFull: Bool) -> some View {
        let isBlocked = isFull && !isOn.wrappedValue
        return VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { isOn.wrappedValue }, set: { turnsOn in
                if turnsOn && isBlocked {
                    refuseTab(title)
                } else {
                    Haptics.light()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isOn.wrappedValue = turnsOn
                        blockedTab = nil
                    }
                }
            })) {
                Label(title, systemImage: symbol)
                    .opacity(isBlocked ? 0.55 : 1)
            }
            .tint(Theme.textSecondary)
            if blockedTab == title {
                Label(String(localized: "Lišta je plná. Nejdřív jednu záložku vypni.", bundle: .kept, locale: .kept), systemImage: "hand.raised.fill")
                    .scaledFont(.caption, weight: .semibold)
                    .foregroundStyle(Theme.red)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .modifier(ShakeEffect(animatableData: CGFloat(tabShakes[title] ?? 0)))
    }

    private func refuseTab(_ title: String) {
        Haptics.warning()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { blockedTab = title }
        withAnimation(.linear(duration: 0.45)) {
            tabShakes[title, default: 0] += 1
            fullBarShakes += 1
        }
        UIAccessibility.post(notification: .announcement,
                             argument: String(localized: "Lišta je plná. Nejdřív jednu záložku vypni.", bundle: .kept, locale: .kept))
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if blockedTab == title {
                withAnimation(.easeOut(duration: 0.3)) { blockedTab = nil }
            }
        }
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
                if settings.healthEnabled {
                    NavigationLink {
                        HealthSummaryView(isEmbedded: true)
                    } label: {
                        Label("Otevřít přehled zdraví", systemImage: "heart.text.square")
                    }
                }
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
                    .scaledFont(.caption)
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

    private func privacySection(_ settings: UserSettings) -> some View {
        Section {
            Toggle("Zamknout Kept Face ID", isOn: Bindable(settings).appLockEnabled)
                .tint(Theme.textSecondary)
        } header: {
            Text("Soukromí")
        } footer: {
            Text("Kept se pak otevře až po Face ID nebo kódu a zamkne se pokaždé, když ho opustíš.")
        }
        .listRowBackground(Theme.card)
    }

    private func diarySection(_ settings: UserSettings) -> some View {
        Section {
            Toggle("Deník", isOn: Bindable(settings).diaryEnabled)
                .tint(Theme.textSecondary)
            if settings.diaryEnabled {
                Toggle("Hlasový zápis", isOn: Bindable(settings).diaryVoiceEnabled)
                    .tint(Theme.textSecondary)
                Toggle("Zamknout deník Face ID", isOn: Bindable(settings).diaryLockEnabled)
                    .tint(Theme.textSecondary)
            }
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
