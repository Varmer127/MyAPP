import SwiftUI
import SwiftData

/// The first-launch guide: what Kept is, how it works (with small playable demos) and the user's own setup.
/// Every step can be skipped; the choices are saved only at the end and can all be changed in Settings.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.dark.rawValue
    @State private var step: Step = .welcome
    @State private var draft = OnboardingDraft()
    @State private var newActivity = ""
    @State private var notificationsAllowed = false
    @State private var shownPoints = 0
    /// Called once the guide is finished and saved.
    let onFinish: () -> Void

    enum Step: Int, CaseIterable {
        case welcome, howItWorks, tutorial, activities, minimum, gym, health, diary, lock, tabs, tone, times, points, done
    }

    private var isLast: Bool { step == Step.allCases.last }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.bottom, 10)
                .background(Theme.background)
                .zIndex(1)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heading
                    content
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 22)
                .padding(.bottom, 24)
                .id(step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
            }
            .scrollDismissesKeyboard(.interactively)
            Button(isLast ? "NAPLÁNOVAT PRVNÍ TÝDEN" : (step == .welcome ? "ZAČÍT" : "POKRAČOVAT"), action: advance)
                .buttonStyle(PrimaryButtonStyle(color: isLast ? Theme.green : Theme.textPrimary,
                                                textColor: isLast ? Color(hex: 0x000000) : Theme.onPrimary))
                .padding(.horizontal, Theme.screenPadding)
                .padding(.vertical, 12)
        }
        .screenBackground()
        .appAppearance()
        .sensoryFeedback(.selection, trigger: step)
        .task(id: step) {
            guard step == .points else { return }
            shownPoints = 0
            while shownPoints < PointsService.startingBalance {
                try? await Task.sleep(for: .milliseconds(25))
                withAnimation(.linear(duration: 0.025)) {
                    shownPoints = min(PointsService.startingBalance, shownPoints + 25)
                }
            }
        }
    }

    // MARK: Frame

    private var topBar: some View {
        VStack(spacing: 14) {
            HStack {
                if step == .welcome {
                    Text("KEPT")
                        .font(.system(size: 15, weight: .heavy))
                        .tracking(3)
                        .foregroundStyle(Theme.textPrimary)
                } else {
                    Button { go(-1) } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(Theme.card)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                    }
                    .accessibilityLabel("Zpět")
                }
                Spacer()
                if !isLast {
                    Button("Přeskočit") { go(1) }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(minHeight: 44)
                }
            }
            HStack(spacing: 4) {
                ForEach(Step.allCases, id: \.rawValue) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? Theme.textPrimary : Theme.cardRaised)
                        .frame(height: 4)
                }
            }
            .animation(.easeOut(duration: 0.25), value: step)
            .accessibilityElement()
            .accessibilityLabel("Krok \(step.rawValue + 1) z \(Step.allCases.count)")
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 8)
    }

    private var heading: some View {
        let text = headingText
        return VStack(alignment: .leading, spacing: 8) {
            Text(text.kicker).labelStyle()
            Text(text.title)
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(text.subtitle)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var headingText: (kicker: String, title: String, subtitle: String) {
        switch step {
        case .welcome: ("VÍTEJ V KEPT", "Dodrž, co si slíbíš.", "Nejdřív jazyk a vzhled. Pak tě Kept provede nastavením, zabere to pár minut.")
        case .howItWorks: ("JAK TO FUNGUJE", "Plán. Pečeť. Slovo.", "Kept není seznam úkolů. Je to smlouva se sebou samým.")
        case .tutorial: ("PRŮVODCE", "Vyzkoušej si Kept.", "Šest krátkých ukázek. Všechno si můžeš naklikat, nic se neuloží.")
        case .activities: ("TVOJE AKTIVITY", "Čemu se chceš věnovat?", "Vyber z nabídky nebo přidej vlastní. Kept je bude navrhovat a hlídat.")
        case .minimum: ("TÝDENNÍ MINIMUM", "Kolik aktivit týdně?", "Plán s menším počtem aktivit nepůjde odeslat. Začni realisticky, zvednout to můžeš kdykoli.")
        case .gym: ("GYM", "Tvoje sekce Gym.", "Tréninky, cviky, váhy a stopky na pauzy, sestavené podle tebe.")
        case .health: ("APPLE ZDRAVÍ", "Propojit se Zdravím?", "Kroky, tréninky a váha na jednom místě, bez ručního zapisování.")
        case .diary: ("DENÍK", "Krátká večerní reflexe.", "Jedna otázka denně, nálada a tři řádky. Pro ty, kdo chtějí víc než čísla.")
        case .lock: ("SOUKROMÍ", "Zamknout celou aplikaci?", "Kept obsahuje tvoje selhání i deník. Můžeš ho schovat za Face ID.")
        case .tabs: ("SPODNÍ LIŠTA", "Co chceš mít po ruce?", "Dnes, Týden a Nastavení jsou vždy. Navíc si vyber nejvýš dvě záložky, zbytek najdeš v Nastavení.")
        case .tone: ("TÓN UPOZORNĚNÍ", "Jak tvrdě tě má Kept honit?", "Podle toho se píšou připomínky úkolů a série.")
        case .times: ("ČASY", "Kdy ti má Kept psát?", "Ranní přehled, večerní bilance a nedělní připomínky plánu.")
        case .points: ("BODY", "Body za dodržené slovo.", "Za splněné závazky sbíráš body a utrácíš je v obchodě. Na start dostáváš tohle:")
        case .done: ("HOTOVO", "Připraveno.", "Takhle sis Kept nastavil:")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: welcome
        case .howItWorks: howItWorks
        case .tutorial: OnboardingTutorial(activity: draft.exampleActivity, secondActivity: draft.secondExampleActivity) { go(1) }
        case .activities: activities
        case .minimum: minimum
        case .gym: gym
        case .health: health
        case .diary: diary
        case .lock: lock
        case .tabs: tabs
        case .tone: tone
        case .times: times
        case .points: points
        case .done: summary
        }
    }

    // MARK: Navigation

    private func go(_ delta: Int) {
        guard let next = Step(rawValue: step.rawValue + delta) else { return }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.easeInOut(duration: 0.3)) { step = next }
    }

    private func advance() {
        guard isLast else { return go(1) }
        draft.apply(to: UserSettings.current(in: context))
        try? context.save()
        if draft.health {
            HealthService.startWorkoutObserver()
        }
        onFinish()
    }

    // MARK: Pieces

    private func choice<Label: View>(_ isOn: Bool, action: @escaping () -> Void, @ViewBuilder label: () -> Label) -> some View {
        Button(action: action) {
            label()
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .foregroundStyle(isOn ? Theme.onPrimary : Theme.textPrimary)
                .background(isOn ? Theme.textPrimary : Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(isOn ? Theme.textPrimary : Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isOn)
    }

    private func option(_ title: String, _ subtitle: String?, isOn: Bool, action: @escaping () -> Void) -> some View {
        choice(isOn, action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .bold))
                if let subtitle {
                    Text(subtitle).font(.system(size: 13)).opacity(isOn ? 0.75 : 1)
                        .foregroundStyle(isOn ? Theme.onPrimary : Theme.textSecondary)
                }
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func toggleRow(_ title: String, _ subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.textPrimary)
                Text(subtitle).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
            }
        }
        .tint(Theme.green)
        .card()
    }

    private func stepper(_ value: String, caption: String? = nil, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack {
            roundButton("minus", label: "Méně", action: minus)
            Spacer()
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 48, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
                if let caption { Text(caption).labelStyle() }
            }
            Spacer()
            roundButton("plus", label: "Více", action: plus)
        }
        .card()
    }

    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 48, height: 48)
                .background(Theme.cardRaised)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 10) {
            option("Čeština", "Celá aplikace i upozornění česky", isOn: true) {}
            option("English", "Připravujeme", isOn: false) {}
                .disabled(true)
                .opacity(0.5)
            Text("VZHLED").labelStyle().padding(.top, 10)
            HStack(spacing: 8) {
                ForEach(AppAppearance.allCases) { look in
                    let isOn = appearanceRaw == look.rawValue
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { appearanceRaw = look.rawValue }
                    } label: {
                        VStack(spacing: 8) {
                            swatch(look)
                            Text(look.title).font(.system(size: 14, weight: .bold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 92)
                        .foregroundStyle(isOn ? Theme.onPrimary : Theme.textPrimary)
                        .background(isOn ? Theme.textPrimary : Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// A tiny screen in the look's colours. "Automaticky" is half dark, half light, with a two-tone line across.
    private func swatch(_ look: AppAppearance) -> some View {
        let dark = Color(hex: 0x0A0A0A)
        let light = Color(hex: 0xF4F4F6)
        return RoundedRectangle(cornerRadius: 7)
            .fill(look == .system
                  ? AnyShapeStyle(LinearGradient(stops: [.init(color: dark, location: 0.5), .init(color: light, location: 0.5)],
                                                 startPoint: .leading, endPoint: .trailing))
                  : AnyShapeStyle(look == .dark ? dark : light))
            .frame(width: 44, height: 30)
            .overlay(alignment: look == .system ? .bottom : .bottomLeading) {
                Capsule()
                    .fill(look == .system
                          ? AnyShapeStyle(LinearGradient(stops: [.init(color: light, location: 0.5), .init(color: dark, location: 0.5)],
                                                         startPoint: .leading, endPoint: .trailing))
                          : AnyShapeStyle(look == .dark ? light : dark))
                    .frame(width: look == .system ? 30 : 24, height: 4)
                    .padding(6)
            }
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.gray.opacity(0.45), lineWidth: 1))
    }

    private var howItWorks: some View {
        VStack(spacing: 10) {
            ForEach(Array([
                ("Naplánuj týden", "V neděli si rozvrhneš, co uděláš a kdy. Rychle, na pár klepnutí."),
                ("Zapečeť ho", "Odešleš plánovač a za hodinu se zapečetí. Pak už je to slib."),
                ("Dodrž slovo", "Kept hlídá, připomíná a počítá spolehlivost. Výmluvy si musíš obhájit."),
            ].enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 14) {
                    Text("\(index + 1)")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Theme.onPrimary)
                        .frame(width: 34, height: 34)
                        .background(Theme.textPrimary)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.0).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.textPrimary)
                        Text(item.1).font(.system(size: 14)).foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .card()
            }
        }
    }

    private var activities: some View {
        let name = newActivity.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: 14) {
            FlowLayout(spacing: 8) {
                ForEach(OnboardingDraft.offeredCategories) { category in
                    let isOn = draft.activities.contains(category)
                    chip(category.title, symbol: category.symbol, isOn: isOn) {
                        if isOn { draft.activities.remove(category) } else { draft.activities.insert(category) }
                    }
                }
                ForEach(draft.customActivities, id: \.self) { item in
                    chip(item, symbol: "xmark", isOn: true) {
                        draft.customActivities.removeAll { $0 == item }
                    }
                    .accessibilityLabel("Odebrat \(item)")
                }
            }
            HStack(spacing: 8) {
                TextField("Vlastní, např. Kytara", text: $newActivity)
                    .font(.system(size: 15))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                    .submitLabel(.done)
                    .onSubmit(addActivity)
                Button("Přidat", action: addActivity)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.onPrimary)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 48)
                    .background(Theme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(name.isEmpty)
                    .opacity(name.isEmpty ? 0.4 : 1)
            }
            note(draft.activityNames.isEmpty
                 ? "Vyber aspoň jednu aktivitu, jinak ti Kept nemá co navrhovat."
                 : "Vybráno: \(draft.activityNames.count). Kolikrát týdně je chceš dělat, si nastavíš v Nastavení → Týdenní cíle.")
        }
    }

    private func addActivity() {
        let name = newActivity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              !draft.customActivities.contains(where: { $0.activityKey == name.activityKey }),
              !TaskCategory.allCases.contains(where: { $0.title.activityKey == name.activityKey }) else {
            newActivity = ""
            return
        }
        withAnimation { draft.customActivities.append(name) }
        newActivity = ""
    }

    private func chip(_ title: String, symbol: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isOn ? Theme.onPrimary : Theme.textPrimary)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(isOn ? Theme.textPrimary : Theme.card)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isOn ? Theme.textPrimary : Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isOn)
    }

    private var minimum: some View {
        let count = draft.minimum
        let caption = count == 0 ? "BEZ MINIMA" : (count == 1 ? "AKTIVITA TÝDNĚ" : (count <= 4 ? "AKTIVITY TÝDNĚ" : "AKTIVIT TÝDNĚ"))
        return VStack(alignment: .leading, spacing: 14) {
            stepper("\(count)", caption: caption,
                    minus: { withAnimation { draft.minimum = max(0, count - 1) } },
                    plus: { withAnimation { draft.minimum = min(UserSettings.minimumWeeklyTasksRange.upperBound, count + 1) } })
            note(count == 0 ? "Bez minima si plán sestavíš libovolně malý."
                 : count <= 4 ? "Klidný start. Hodí se, když si zvykáš plánovat."
                 : count <= 9 ? "Zhruba jedna aktivita denně. Většině lidí sedí."
                 : "Náročné. Počítej s tím, že tě Kept bude držet zkrátka.")
        }
    }

    private var gym: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                option("Chodím", nil, isOn: draft.doesGym) { draft.activities.insert(.gym) }
                option("Nechodím", nil, isOn: !draft.doesGym) { draft.activities.remove(.gym) }
            }
            if draft.doesGym {
                VStack(alignment: .leading, spacing: 8) {
                    Text("JAKÝ SPLIT JEDEŠ").labelStyle()
                    ForEach(OnboardingDraft.Split.allCases) { split in
                        option(split.title, split.summary, isOn: draft.split == split) {
                            withAnimation { draft.split = split }
                        }
                    }
                    if draft.split == .own { ownSplit }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("KOLIKRÁT TÝDNĚ ZHRUBA").labelStyle()
                    stepper("\(draft.gymPerWeek)×", caption: "ORIENTAČNĚ",
                            minus: { withAnimation { draft.gymPerWeek = max(1, draft.gymPerWeek - 1) } },
                            plus: { withAnimation { draft.gymPerWeek = min(7, draft.gymPerWeek + 1) } })
                    note("Jen orientační cíl: jeden týden 3×, druhý 6× je v pořádku, žádný postih. Jak ho plníš, se trochu promítá do spolehlivosti a podle něj ti Kept gym navrhuje. Změníš ho v Nastavení gymu.")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("VÝCHOZÍ PAUZA MEZI SÉRIEMI").labelStyle()
                    HStack(spacing: 8) {
                        ForEach(RestPreset.defaults) { preset in
                            let isOn = draft.restName == preset.name
                            Button { draft.restName = preset.name } label: {
                                VStack(spacing: 2) {
                                    Text(preset.name).font(.system(size: 15, weight: .bold))
                                    Text(FocusView.clock(TimeInterval(preset.seconds))).font(.system(size: 13)).opacity(0.75)
                                }
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .foregroundStyle(isOn ? Theme.onPrimary : Theme.textPrimary)
                                .background(isOn ? Theme.textPrimary : Theme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    note("Vlastní pauzy (třeba „Dřep 4:00“) si přidáš později v Nastavení gymu. Ta nahoře v seznamu je ve stopkách výchozí.")
                }
            } else {
                note("Gym se nebude nabízet ani navrhovat. Zapnout ho můžeš kdykoli v Nastavení → Moje aktivity.")
            }
        }
    }

    private var ownSplit: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tvoje tréninky").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.textPrimary)
            note("Pojmenuj tréninky, které se v týdnu střídají.")
            ForEach(draft.ownWorkouts.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    Text(String(UnicodeScalar(UInt8(65 + index))))
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(Theme.card)
                        .clipShape(Circle())
                    TextField("Např. Hrudník a triceps", text: $draft.ownWorkouts[index])
                        .font(.system(size: 15))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Button {
                        withAnimation { _ = draft.ownWorkouts.remove(at: index) }
                    } label: {
                        Image(systemName: "minus.circle").foregroundStyle(Theme.red).frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(draft.ownWorkouts.count <= 1)
                    .accessibilityLabel("Odebrat trénink")
                }
            }
            if draft.ownWorkouts.count < 7 {
                Button {
                    withAnimation { draft.ownWorkouts.append("") }
                } label: {
                    Label("Přidat trénink", systemImage: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Theme.cardRaised)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var health: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(["Kroky, aktivní energie a tréninky za posledních 7 dní",
                         "Váha se doplní do zápisu tréninku a do grafu",
                         "Když hodinky uloží silový trénink, Kept ti hned nabídne ho zapsat"], id: \.self) { line in
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(Theme.green).frame(width: 6, height: 6).padding(.top, 7)
                        Text(line).font(.system(size: 14)).foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .card()
            if HealthService.isAvailable {
                Button(draft.health ? "PROPOJENO SE ZDRAVÍM" : "PROPOJIT SE ZDRAVÍM") {
                    Task {
                        await HealthService.requestAccess()
                        withAnimation { draft.health = true }
                    }
                }
                .buttonStyle(PrimaryButtonStyle(color: draft.health ? Theme.green : Theme.textPrimary,
                                                textColor: draft.health ? Color(hex: 0x000000) : Theme.onPrimary))
                .disabled(draft.health)
            } else {
                note("Apple Zdraví na tomto zařízení není dostupné.")
            }
            note("Kept ze Zdraví jen čte a nic nikam neposílá. Propojit to jde i později v Nastavení.")
        }
    }

    private var diary: some View {
        VStack(alignment: .leading, spacing: 10) {
            toggleRow("Zapnout deník", "Přidá sekci Deník. Kdo nechce psát, nechá vypnuté.", isOn: $draft.diary)
            if draft.diary {
                toggleRow("Zamknout deník Face ID", "Jen deník, zbytek aplikace zůstane otevřený.", isOn: $draft.diaryLock)
            }
            note("Otázka dne, nálada a energie, tři řádky a vděčnost. Za každý den se zápisem \(DiaryService.pointsPerEntry) bodů.")
        }
        .animation(.easeOut(duration: 0.2), value: draft.diary)
    }

    private var lock: some View {
        VStack(spacing: 16) {
            Image(systemName: draft.appLock ? "lock.fill" : "lock.open")
                .font(.system(size: 40))
                .foregroundStyle(draft.appLock ? Color(hex: 0x000000) : Theme.textPrimary)
                .frame(width: 96, height: 96)
                .background(draft.appLock ? Theme.green : Theme.card)
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                .contentTransition(.symbolEffect(.replace))
                .animation(.easeInOut(duration: 0.25), value: draft.appLock)
            toggleRow("Zamknout Kept Face ID", "Při každém otevření aplikace. Kdo vezme telefon, tvoje plány ani deník neuvidí.",
                      isOn: $draft.appLock)
        }
        .frame(maxWidth: .infinity)
    }

    private var tabOptions: [(tab: AppTab, title: String, subtitle: String, symbol: String)] {
        var options: [(AppTab, String, String, String)] = [(.stats, "Statistiky", "Grafy, kalendář, rekordy", "chart.bar")]
        if draft.doesGym { options.append((.gym, "Gym", "Tréninky a síla", TaskCategory.gym.symbol)) }
        if HealthService.isAvailable { options.append((.health, "Zdraví", "Kroky a váha", "heart")) }
        if draft.diary { options.append((.diary, "Deník", "Večerní reflexe", "book.closed")) }
        return options
    }

    private var tabs: some View {
        let chosen = draft.tabs.filter { tab in tabOptions.contains { $0.tab == tab } }
        let bar: [(String, String)] = [("Dnes", "sun.max"), ("Týden", "calendar")]
            + tabOptions.filter { chosen.contains($0.tab) }.map { ($0.title, $0.symbol) }
            + [("Nastavení", "gearshape")]
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 2) {
                ForEach(Array(bar.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 3) {
                        Image(systemName: item.1).font(.system(size: 18))
                        Text(item.0).font(.system(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(index == 0 ? Theme.textPrimary : Theme.textSecondary)
                    .background(index == 0 ? Theme.cardRaised : Color.clear)
                    .clipShape(Capsule())
                }
            }
            .padding(6)
            .background(Theme.card)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
            .animation(.easeOut(duration: 0.2), value: chosen)
            Text("NAVÍC VYBRÁNO \(chosen.count) ZE \(UserSettings.maxOptionalTabs)").labelStyle()
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(tabOptions, id: \.tab) { item in
                    choice(chosen.contains(item.tab), action: { toggleTab(item.tab, chosen: chosen) }) {
                        HStack(spacing: 10) {
                            Image(systemName: item.symbol).font(.system(size: 18))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.system(size: 15, weight: .bold))
                                Text(item.subtitle).font(.system(size: 12)).opacity(0.75).lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
    }

    /// At most two extra tabs: picking a third drops the one picked first.
    private func toggleTab(_ tab: AppTab, chosen: [AppTab]) {
        if chosen.contains(tab) {
            draft.tabs = chosen.filter { $0 != tab }
        } else {
            draft.tabs = Array((chosen + [tab]).suffix(UserSettings.maxOptionalTabs))
        }
    }

    private var tone: some View {
        let activity = draft.exampleActivity
        let sample: (title: String, body: String, about: String) = switch draft.tone {
        case .normal: (activity.uppercased(), "Je 15:00 a \(activity) pořád není hotové.", "Věcný a neutrální. Připomene, ale netlačí.")
        case .strict: (activity.uppercased(), "Zase to odkládáš. \(activity). Začni.", "Přímý a konfrontační. Výchozí volba.")
        case .savage: ("GET THE FUCK UP.", "Furt meleš o tom, čeho chceš dosáhnout. Tak kde je ta práce? \(activity).", "Tvrdý. Pro ty, kdo potřebují kopanec.")
        }
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ForEach(NotificationTone.allCases) { item in
                    let isOn = draft.tone == item
                    Button { withAnimation { draft.tone = item } } label: {
                        Text(item.title)
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .foregroundStyle(isOn ? Theme.onPrimary : Theme.textPrimary)
                            .background(isOn ? Theme.textPrimary : Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(alignment: .top, spacing: 12) {
                // The real app icon, as it appears on a notification.
                Image("KeptLogo")
                    .resizable()
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(sample.title).font(.system(size: 14, weight: .bold))
                        Spacer()
                        Text("teď").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    }
                    Text(sample.body).font(.system(size: 14))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Theme.textPrimary)
            }
            .padding(14)
            .background(Theme.cardRaised)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .id(draft.tone)
            .transition(.opacity)
            note(sample.about)
            if draft.tone == .savage {
                Text("Drsný tón obsahuje hrubý jazyk a míří na tvoje chování, nikdy na tebe jako člověka. Zapni ho jen vědomě.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.orange)
                    .padding(12)
                    .background(Theme.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var times: some View {
        VStack(alignment: .leading, spacing: 10) {
            timeRow("Ranní přehled", "Co tě dnes čeká", minutes: $draft.morningMinutes, range: 5 * 60...12 * 60)
            timeRow("Večerní bilance", "Jak dnešek dopadl", minutes: $draft.eveningMinutes, range: 17 * 60...23 * 60 + 30)
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Nedělní plánování").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.textPrimary)
                    Text("Připomínky do 21:00").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                compactStepper("od \(draft.sundayStartHour):00",
                               minus: { draft.sundayStartHour = max(6, draft.sundayStartHour - 1) },
                               plus: { draft.sundayStartHour = min(20, draft.sundayStartHour + 1) })
            }
            .card()
            Button(notificationsAllowed ? "UPOZORNĚNÍ POVOLENA" : "POVOLIT UPOZORNĚNÍ") {
                Task {
                    let granted = await NotificationManager.requestAuthorization()
                    withAnimation { notificationsAllowed = granted }
                }
            }
            .buttonStyle(PrimaryButtonStyle(color: notificationsAllowed ? Theme.green : Theme.textPrimary,
                                            textColor: notificationsAllowed ? Color(hex: 0x000000) : Theme.onPrimary))
            .disabled(notificationsAllowed)
            note("Bez upozornění Kept nemůže připomínat úkoly ani hlídat sérii. iPhone se zeptá jen jednou.")
        }
        .task {
            notificationsAllowed = await NotificationManager.authorizationStatus() == .authorized
        }
    }

    private func timeRow(_ title: String, _ subtitle: String, minutes: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.textPrimary)
                Text(subtitle).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            compactStepper(String(format: "%02d:%02d", minutes.wrappedValue / 60, minutes.wrappedValue % 60),
                           minus: { minutes.wrappedValue = max(range.lowerBound, minutes.wrappedValue - 30) },
                           plus: { minutes.wrappedValue = min(range.upperBound, minutes.wrappedValue + 30) })
        }
        .card()
    }

    private func compactStepper(_ value: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            smallRound("minus", label: "Dřív", action: minus)
            Text(value)
                .font(.system(size: 17, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .frame(minWidth: 62)
            smallRound("plus", label: "Později", action: plus)
        }
    }

    private func smallRound(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 44, height: 44)
                .background(Theme.cardRaised)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var points: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(shownPoints)")
                        .font(.system(size: 60, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Theme.green)
                        .contentTransition(.numericText())
                    Text("BODŮ NA START").labelStyle()
                }
                ThinBar(value: Double(shownPoints) / Double(PointsService.passCost), color: Theme.green)
                Text("Do první propustky chybí \(PointsService.passCost - PointsService.startingBalance).")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            .card()
            HStack(alignment: .top, spacing: 10) {
                pointsList("ZÍSKÁŠ", [("+\(PointsService.perCommitment)", "splněný závazek"),
                                     ("+\(PointsService.perSuggestion)", "splněný návrh"),
                                     ("+\(DiaryService.pointsPerEntry)", "den v deníku"),
                                     ("+50…1 000", "milníky série")], color: Theme.green)
                pointsList("UTRATÍŠ", [("1 000", "propustka"),
                                      ("\(ShopItem.streakInsurance.cost)", "pojistka série"),
                                      ("\(ShopItem.extraPostpone.cost)", "odklad navíc"),
                                      ("\(PointsService.streakRepairCost)", "vrácení série / den")], color: Theme.textPrimary)
            }
        }
    }

    private func pointsList(_ title: String, _ rows: [(String, String)], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).labelStyle()
            ForEach(rows, id: \.1) { value, label in
                (Text(value).fontWeight(.heavy).foregroundColor(color) + Text(" \(label)").foregroundColor(Theme.textPrimary))
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }

    private var summary: some View {
        let split = draft.split == .own
            ? (draft.ownWorkouts.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: " / "))
            : draft.split.title
        let tabNames = tabOptions.filter { draft.tabs.contains($0.tab) }.map(\.title)
        let rows: [(String, String)] = [
            ("Vzhled", (AppAppearance(rawValue: appearanceRaw) ?? .dark).title),
            ("Aktivity", draft.activityNames.joined(separator: ", ")),
            ("Minimum", draft.minimum == 0 ? "bez minima" : "\(draft.minimum) týdně"),
            ("Gym", draft.doesGym ? "\(split), asi \(draft.gymPerWeek)× týdně" : "ne"),
            ("Zdraví", draft.health ? "propojeno" : "později"),
            ("Deník", draft.diary ? (draft.diaryLock ? "zapnutý, zamčený" : "zapnutý") : "vypnutý"),
            ("Zámek aplikace", draft.appLock ? "Face ID" : "bez zámku"),
            ("Lišta", (["Dnes", "Týden"] + tabNames + ["Nastavení"]).joined(separator: " · ")),
            ("Tón", draft.tone.title),
        ]
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(rows, id: \.0) { key, value in
                HStack(alignment: .top) {
                    Text(key).font(.system(size: 14)).foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 16)
                    Text(value.isEmpty ? "—" : value)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.trailing)
                }
                .card(padding: 12)
            }
            note("Všechno změníš v Nastavení. Teď si naplánuj první týden a odešli plánovač.")
                .padding(.top, 6)
        }
    }
}

/// Lays chips out in rows, wrapping to the next row when one is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal: proposal, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(proposal: proposal, subviews: subviews) {
            for item in row.items {
                subviews[item.index].place(at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y),
                                           proposal: ProposedViewSize(item.size))
            }
        }
    }

    private struct Row {
        var y: CGFloat
        var height: CGFloat = 0
        var items: [(index: Int, x: CGFloat, size: CGSize)] = []
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let width = proposal.width ?? .infinity
        var rows = [Row(y: 0)]
        var x: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                let last = rows[rows.count - 1]
                rows.append(Row(y: last.y + last.height + spacing))
                x = 0
            }
            rows[rows.count - 1].items.append((index, x, size))
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
            x += size.width + spacing
        }
        return rows
    }
}
