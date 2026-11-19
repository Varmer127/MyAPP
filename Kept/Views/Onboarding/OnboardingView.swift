import SwiftUI
import SwiftData

/// The first-launch guide: what Kept is, how it works (with small playable demos) and the user's own setup.
/// Every step can be skipped; the choices are saved only at the end and can all be changed in Settings.
struct OnboardingView: View {
    @Environment(\.modelContext) var context

    @AppStorage(AppAppearance.storageKey) var appearanceRaw = AppAppearance.dark.rawValue

    @State var step: Step = .welcome

    @State var draft = OnboardingDraft()

    @State var newActivity = ""

    @State var notificationsAllowed = false

    @State var shownPoints = 0

    /// Called once the guide is finished and saved.
    let onFinish: () -> Void

    enum Step: Int, CaseIterable {
        case welcome, name, howItWorks, tutorial, activities, minimum, gym, health, diary, lock, tabs, tone, times, points, friends, done
    }

    var isLast: Bool { step == Step.allCases.last }

    /// Kept speaks to the user by name every day, so the guide does not go on without one.
    var needsName: Bool { step == .name && draft.addressName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    @State var showsRegistration = false

    /// The friends step offers the account first; the guide goes on once it exists or the step is skipped.
    var offersAccount: Bool { step == .friends && !AccountService.shared.isSignedIn }

    var primaryTitle: String {
        if isLast { return String(localized: "NAPLÁNOVAT PRVNÍ TÝDEN", bundle: .kept) }
        if step == .welcome { return String(localized: "ZAČÍT", bundle: .kept) }
        if needsName { return String(localized: "NAPIŠ, JAK TI MÁM ŘÍKAT", bundle: .kept) }
        return offersAccount ? String(localized: "VYTVOŘIT ÚČET", bundle: .kept) : String(localized: "POKRAČOVAT", bundle: .kept)
    }

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
            Button(primaryTitle, action: advance)
                .buttonStyle(PrimaryButtonStyle(color: isLast ? Theme.green : Theme.textPrimary,
                                                textColor: Theme.onPrimary))
                .disabled(needsName)
                .animation(.easeOut(duration: 0.2), value: needsName)
                .padding(.horizontal, Theme.screenPadding)
                .padding(.vertical, 12)
        }
        .screenBackground()
        .appAppearance()
        .sensoryFeedback(.selection, trigger: step)
        .sheet(isPresented: $showsRegistration) { RegistrationView(onDone: { go(1) }) }
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


    var topBar: some View {
        VStack(spacing: 14) {
            HStack {
                if step == .welcome {
                    Text("KEPT")
                        .scaledFont(.body, weight: .heavy)
                        .tracking(3)
                        .foregroundStyle(Theme.textPrimary)
                } else {
                    Button { go(-1) } label: {
                        Image(systemName: "chevron.left")
                            .scaledFont(.heading, weight: .semibold)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(Theme.card)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                    }
                    .accessibilityLabel("Zpět")
                }
                Spacer()
                if !isLast, step != .name {
                    Button("Přeskočit") { go(1) }
                        .scaledFont(.body, weight: .semibold)
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

    var heading: some View {
        let text = headingText
        return VStack(alignment: .leading, spacing: 8) {
            Text(text.kicker).labelStyle()
            Text(text.title)
                .scaledFont(.title, weight: .heavy)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(text.subtitle)
                .scaledFont(.body)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var headingText: (kicker: String, title: String, subtitle: String) {
        switch step {
        case .welcome: (String(localized: "VÍTEJ V KEPT", bundle: .kept), String(localized: "Dodrž, co si slíbíš.", bundle: .kept), String(localized: "Nejdřív jazyk a vzhled. Pak tě Kept provede nastavením, zabere to pár minut.", bundle: .kept))
        case .name: (String(localized: "TY", bundle: .kept), String(localized: "Jak ti mám říkat?", bundle: .kept), String(localized: "Kept s tebou mluví každý den. Napiš oslovení tak, jak ho chceš slyšet, třeba „Filipe“ nebo „Anežko“.", bundle: .kept))
        case .howItWorks: (String(localized: "JAK TO FUNGUJE", bundle: .kept), String(localized: "Plán. Pečeť. Slovo.", bundle: .kept), String(localized: "Kept není seznam úkolů. Je to smlouva se sebou samým.", bundle: .kept))
        case .tutorial: (String(localized: "PRŮVODCE", bundle: .kept), String(localized: "Vyzkoušej si Kept.", bundle: .kept), String(localized: "Šest krátkých ukázek. Všechno si můžeš naklikat, nic se neuloží.", bundle: .kept))
        case .activities: (String(localized: "TVOJE AKTIVITY", bundle: .kept), String(localized: "Čemu se chceš věnovat?", bundle: .kept), String(localized: "Vyber z nabídky nebo přidej vlastní. Kept je bude navrhovat a hlídat.", bundle: .kept))
        case .minimum: (String(localized: "TÝDENNÍ MINIMUM", bundle: .kept), String(localized: "Kolik aktivit týdně?", bundle: .kept), String(localized: "Plán s menším počtem aktivit nepůjde odeslat. Začni realisticky, zvednout to můžeš kdykoli.", bundle: .kept))
        case .gym: (String(localized: "GYM", bundle: .kept), String(localized: "Tvoje sekce Gym.", bundle: .kept), String(localized: "Tréninky, cviky, váhy a stopky na pauzy, sestavené podle tebe.", bundle: .kept))
        case .health: (String(localized: "APPLE ZDRAVÍ", bundle: .kept), String(localized: "Propojit se Zdravím?", bundle: .kept), String(localized: "Kroky, tréninky a váha na jednom místě, bez ručního zapisování.", bundle: .kept))
        case .diary: (String(localized: "DENÍK", bundle: .kept), String(localized: "Krátká večerní reflexe.", bundle: .kept), String(localized: "Jedna otázka denně, nálada a tři řádky. Pro ty, kdo chtějí víc než čísla.", bundle: .kept))
        case .lock: (String(localized: "SOUKROMÍ", bundle: .kept), String(localized: "Zamknout celou aplikaci?", bundle: .kept), String(localized: "Kept obsahuje tvoje selhání i deník. Můžeš ho schovat za Face ID.", bundle: .kept))
        case .tabs: (String(localized: "SPODNÍ LIŠTA", bundle: .kept), String(localized: "Co chceš mít po ruce?", bundle: .kept), String(localized: "Dnes, Týden a Nastavení jsou vždy. Navíc si vyber nejvýš dvě záložky, zbytek najdeš v Nastavení.", bundle: .kept))
        case .tone: (String(localized: "TÓN UPOZORNĚNÍ", bundle: .kept), String(localized: "Jak tvrdě tě má Kept honit?", bundle: .kept), String(localized: "Podle toho se píšou připomínky úkolů a série.", bundle: .kept))
        case .times: (String(localized: "ČASY", bundle: .kept), String(localized: "Kdy ti má Kept psát?", bundle: .kept), String(localized: "Ranní přehled, večerní bilance a nedělní připomínky plánu.", bundle: .kept))
        case .points: (String(localized: "BODY", bundle: .kept), String(localized: "Body za dodržené slovo.", bundle: .kept), String(localized: "Za splněné závazky sbíráš body a utrácíš je v obchodě. Na start dostáváš tohle:", bundle: .kept))
        case .friends: (String(localized: "PŘÁTELÉ · VOLITELNÉ", bundle: .kept), String(localized: "Kept s kamarády.", bundle: .kept), String(localized: "Sdílej týden, pošťouchávejte se a sázejte se o body. Nic z toho nemusíš.", bundle: .kept))
        case .done: (String(localized: "HOTOVO", bundle: .kept), String(localized: "Připraveno.", bundle: .kept), String(localized: "Takhle sis Kept nastavil:", bundle: .kept))
        }
    }

    @ViewBuilder
    var content: some View {
        switch step {
        case .welcome: welcome
        case .name: nameStep
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
        case .friends: friends
        case .done: summary
        }
    }

    // MARK: Navigation


    func go(_ delta: Int) {
        guard let next = Step(rawValue: step.rawValue + delta) else { return }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.easeInOut(duration: 0.3)) { step = next }
    }

    func advance() {
        guard !needsName else { return }
        if offersAccount {
            showsRegistration = true
            return
        }
        guard isLast else { return go(1) }
        draft.apply(to: UserSettings.current(in: context))
        Persistence.save(context)
        if draft.health {
            HealthService.startWorkoutObserver()
        }
        onFinish()
    }

    // MARK: Pieces


    func choice<Label: View>(_ isOn: Bool, action: @escaping () -> Void, @ViewBuilder label: () -> Label) -> some View {
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

    // MARK: Steps


}