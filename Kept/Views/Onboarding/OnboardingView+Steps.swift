import SwiftUI
import SwiftData

extension OnboardingView {
    var nameStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Oslovení, např. Filipe", text: $draft.addressName)
                .scaledFont(.heading, weight: .semibold)
                .textContentType(.givenName)
                .submitLabel(.done)
                .padding(.horizontal, 16)
                .frame(minHeight: 54)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            // Grammatical gender only exists in Czech.
            if AppLanguage.current == .cs {
                Text("V ČEM SE ZA TEBE MLUVÍ").labelStyle().padding(.top, 6)
                ForEach(GrammarGender.allCases) { gender in
                    option(gender.title, gender.example, isOn: draft.grammar == gender) {
                        withAnimation { draft.grammar = gender }
                    }
                }
                note(String(localized: "Slouží jen k tomu, aby věty od Kept seděly. Nikam se neposílá a změníš to v Nastavení."))
            }
        }
    }

    var welcome: some View {
        VStack(alignment: .leading, spacing: 10) {
            // The language is the one iOS keeps for Kept; switching opens Kept in the iPhone settings, where it is chosen.
            option(String(localized: "Čeština"), String(localized: "Celá aplikace i upozornění česky"), isOn: AppLanguage.current == .cs) {
                if AppLanguage.current != .cs { LanguageRow.openSettings() }
            }
            option("English", "The whole app and notifications in English", isOn: AppLanguage.current == .en) {
                if AppLanguage.current != .en { LanguageRow.openSettings() }
            }
            Text("VZHLED").labelStyle().padding(.top, 10)
            HStack(spacing: 8) {
                ForEach(AppAppearance.allCases) { look in
                    let isOn = appearanceRaw == look.rawValue
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { appearanceRaw = look.rawValue }
                    } label: {
                        VStack(spacing: 8) {
                            swatch(look)
                            Text(look.title).scaledFont(.body, weight: .bold)
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
    func swatch(_ look: AppAppearance) -> some View {
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

    var howItWorks: some View {
        VStack(spacing: 10) {
            ForEach(Array([
                (String(localized: "Naplánuj týden"), String(localized: "V neděli si rozvrhneš, co uděláš a kdy. Rychle, na pár klepnutí.")),
                (String(localized: "Zapečeť ho"), String(localized: "Odešleš plánovač a za hodinu se zapečetí. Pak už je to slib.")),
                (String(localized: "Dodrž slovo"), String(localized: "Kept hlídá, připomíná a počítá spolehlivost. Výmluvy si musíš obhájit.")),
            ].enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 14) {
                    Text("\(index + 1)")
                        .scaledFont(.body, weight: .heavy)
                        .foregroundStyle(Theme.onPrimary)
                        .frame(width: 34, height: 34)
                        .background(Theme.textPrimary)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.0).scaledFont(.heading, weight: .bold).foregroundStyle(Theme.textPrimary)
                        Text(item.1).scaledFont(.body).foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .card()
            }
        }
    }

    var activities: some View {
        let name = newActivity.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: 14) {
            FlowLayout(spacing: 8) {
                ForEach(OnboardingDraft.offeredCategories) { category in
                    let isOn = draft.activities.contains(category)
                    chip(category.title, symbol: draft.icon(for: category), isOn: isOn) {
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
                    .scaledFont(.body)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                    .submitLabel(.done)
                    .onSubmit(addActivity)
                Button("Přidat", action: addActivity)
                    .scaledFont(.body, weight: .bold)
                    .foregroundStyle(Theme.onPrimary)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 48)
                    .background(Theme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(name.isEmpty)
                    .opacity(name.isEmpty ? 0.4 : 1)
            }
            if !draft.activityNames.isEmpty { activityIcons }
            note(draft.activityNames.isEmpty
                 ? String(localized: "Vyber aspoň jednu aktivitu, jinak ti Kept nemá co navrhovat.")
                 : String(localized: "Vybráno: \(draft.activityNames.count). Kolikrát týdně je chceš dělat, si nastavíš v Nastavení → Týdenní cíle."))
        }
    }

    /// Every chosen activity with its icon, which a tap changes.
    var activityIcons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("IKONY · KLEPNUTÍM ZMĚNÍŠ").labelStyle()
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                ForEach(OnboardingDraft.offeredCategories.filter { draft.activities.contains($0) }) { category in
                    iconRow(category.title, symbol: draft.icon(for: category)) { draft.categoryIcons[category] = $0 }
                }
                ForEach(draft.customActivities, id: \.self) { name in
                    iconRow(name, symbol: draft.icon(forCustom: name)) { draft.customIcons[name] = $0 }
                }
            }
        }
    }

    func iconRow(_ title: String, symbol: String, onPick: @escaping (String) -> Void) -> some View {
        HStack(spacing: 10) {
            ActivityIconButton(activity: title, symbol: symbol, onPick: onPick)
            Text(title)
                .scaledFont(.body, weight: .semibold)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    func addActivity() {
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

    var minimum: some View {
        let count = draft.minimum
        let caption = count == 0 ? String(localized: "BEZ MINIMA") : (count == 1 ? String(localized: "AKTIVITA TÝDNĚ") : (count <= 4 ? String(localized: "AKTIVITY TÝDNĚ") : String(localized: "AKTIVIT TÝDNĚ")))
        return VStack(alignment: .leading, spacing: 14) {
            stepper("\(count)", caption: caption,
                    minus: { withAnimation { draft.minimum = max(0, count - 1) } },
                    plus: { withAnimation { draft.minimum = min(UserSettings.minimumWeeklyTasksRange.upperBound, count + 1) } })
            note(count == 0 ? String(localized: "Bez minima si plán sestavíš libovolně malý.")
                 : count <= 4 ? String(localized: "Klidný start. Hodí se, když si zvykáš plánovat.")
                 : count <= 9 ? String(localized: "Zhruba jedna aktivita denně. Většině lidí sedí.")
                 : String(localized: "Náročné. Počítej s tím, že tě Kept bude držet zkrátka."))
        }
    }

    var gym: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                option(String(localized: "Chodím"), nil, isOn: draft.doesGym) { draft.activities.insert(.gym) }
                option(String(localized: "Nechodím"), nil, isOn: !draft.doesGym) { draft.activities.remove(.gym) }
            }
            if draft.doesGym {
                VStack(alignment: .leading, spacing: 8) {
                    Text("JAK CHCEŠ GYM ZAPISOVAT").labelStyle()
                    HStack(spacing: 10) {
                        ForEach(GymMode.allCases) { mode in
                            option(mode.title, nil, isOn: draft.gymMode == mode) {
                                withAnimation { draft.gymMode = mode }
                            }
                        }
                    }
                    GymModePreview(mode: draft.gymMode)
                    note(String(localized: "Přepnout můžeš kdykoli v Nastavení gymu. Nic se tím nesmaže, data z pokročilého režimu jen zůstanou schovaná."))
                }
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
                    stepper("\(draft.gymPerWeek)×", caption: String(localized: "ORIENTAČNĚ"),
                            minus: { withAnimation { draft.gymPerWeek = max(1, draft.gymPerWeek - 1) } },
                            plus: { withAnimation { draft.gymPerWeek = min(7, draft.gymPerWeek + 1) } })
                    note(String(localized: "Jen orientační cíl: jeden týden 3×, druhý 6× je v pořádku, žádný postih. Jak ho plníš, se trochu promítá do spolehlivosti a podle něj ti Kept gym navrhuje. Změníš ho v Nastavení gymu."))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("VÝCHOZÍ PAUZA MEZI SÉRIEMI").labelStyle()
                    HStack(spacing: 8) {
                        ForEach(RestPreset.defaults) { preset in
                            let isOn = draft.restName == preset.name
                            Button { draft.restName = preset.name } label: {
                                VStack(spacing: 2) {
                                    Text(preset.name).scaledFont(.body, weight: .bold)
                                    Text(FocusView.clock(TimeInterval(preset.seconds))).scaledFont(.caption).opacity(0.75)
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
                    note(String(localized: "Vlastní pauzy (třeba „Dřep 4:00“) si přidáš později v Nastavení gymu. Ta nahoře v seznamu je ve stopkách výchozí."))
                }
            } else {
                note(String(localized: "Gym se nebude nabízet ani navrhovat. Zapnout ho můžeš kdykoli v Nastavení → Moje aktivity."))
            }
        }
    }

    var ownSplit: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tvoje tréninky").scaledFont(.body, weight: .bold).foregroundStyle(Theme.textPrimary)
            note(String(localized: "Pojmenuj tréninky, které se v týdnu střídají."))
            ForEach(draft.ownWorkouts.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    Text(String(UnicodeScalar(UInt8(65 + index))))
                        .scaledFont(.caption, weight: .heavy)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(Theme.card)
                        .clipShape(Circle())
                    TextField("Např. Hrudník a triceps", text: $draft.ownWorkouts[index])
                        .scaledFont(.body)
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
                .swipeToDelete(String(localized: "Odebrat trénink"), isEnabled: draft.ownWorkouts.count > 1) {
                    withAnimation { _ = draft.ownWorkouts.remove(at: index) }
                }
            }
            if draft.ownWorkouts.count < 7 {
                Button {
                    withAnimation { draft.ownWorkouts.append("") }
                } label: {
                    Label("Přidat trénink", systemImage: "plus")
                        .scaledFont(.body, weight: .bold)
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

    var health: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach([String(localized: "Kroky, aktivní energie a tréninky za posledních 7 dní"),
                         String(localized: "Váha se doplní do zápisu tréninku a do grafu"),
                         String(localized: "Když hodinky uloží silový trénink, Kept ti hned nabídne ho zapsat")], id: \.self) { line in
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(Theme.green).frame(width: 6, height: 6).padding(.top, 7)
                        Text(line).scaledFont(.body).foregroundStyle(Theme.textPrimary)
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
                                                textColor: draft.health ? Theme.onPrimary : Theme.onPrimary))
                .disabled(draft.health)
            } else {
                note(String(localized: "Apple Zdraví na tomto zařízení není dostupné."))
            }
            note(String(localized: "Kept ze Zdraví jen čte a nic nikam neposílá. Propojit to jde i později v Nastavení."))
        }
    }

    var friends: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach([String(localized: "Sdílej svůj týden a drž se s kamarády"),
                         String(localized: "Pošťouchni přítele, když si zapomněl makat"),
                         String(localized: "Sázejte se o body, nikdy o peníze")], id: \.self) { line in
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(Theme.green).frame(width: 6, height: 6).padding(.top, 7)
                        Text(line).scaledFont(.body).foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .card()
            note(String(localized: "Účet je volitelný a Kept funguje i bez něj. Deník, váha, zdraví a fotky zůstanou jen v tvém telefonu a nic se nesdílí, dokud to sám nezapneš. Účet založíš i později v Nastavení."))
            if AccountService.shared.isSignedIn {
                note(String(localized: "Účet máš hotový."))
            } else {
                Button("Přeskočit, bez účtu to zvládnu") { go(1) }
                    .scaledFont(.body, weight: .semibold)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    var diary: some View {
        VStack(alignment: .leading, spacing: 10) {
            toggleRow(String(localized: "Zapnout deník"), String(localized: "Přidá sekci Deník. Kdo nechce psát, nechá vypnuté."), isOn: $draft.diary)
            if draft.diary {
                toggleRow(String(localized: "Zamknout deník Face ID"), String(localized: "Jen deník, zbytek aplikace zůstane otevřený."), isOn: $draft.diaryLock)
            }
            note(String(localized: "Otázka dne, nálada a energie, tři řádky a vděčnost. Za každý den se zápisem \(DiaryService.pointsPerEntry) bodů."))
        }
        .animation(.easeOut(duration: 0.2), value: draft.diary)
    }

    var lock: some View {
        VStack(spacing: 16) {
            Image(systemName: draft.appLock ? "lock.fill" : "lock.open")
                .scaledFont(40)
                .foregroundStyle(draft.appLock ? Theme.onPrimary : Theme.textPrimary)
                .frame(width: 96, height: 96)
                .background(draft.appLock ? Theme.green : Theme.card)
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                .contentTransition(.symbolEffect(.replace))
                .animation(.easeInOut(duration: 0.25), value: draft.appLock)
            toggleRow(String(localized: "Zamknout Kept Face ID"), String(localized: "Při každém otevření aplikace. Kdo vezme telefon, tvoje plány ani deník neuvidí."),
                      isOn: $draft.appLock)
        }
        .frame(maxWidth: .infinity)
    }

    var tabOptions: [(tab: AppTab, title: String, subtitle: String, symbol: String)] {
        var options: [(AppTab, String, String, String)] = [(.stats, String(localized: "Statistiky"), String(localized: "Grafy, kalendář, rekordy"), "chart.bar")]
        if draft.doesGym { options.append((.gym, String(localized: "Gym"), String(localized: "Tréninky a síla"), TaskCategory.gym.symbol)) }
        if HealthService.isAvailable { options.append((.health, String(localized: "Zdraví"), String(localized: "Kroky a váha"), "heart")) }
        if draft.diary { options.append((.diary, String(localized: "Deník"), String(localized: "Večerní reflexe"), "book.closed")) }
        return options
    }

    var tabs: some View {
        let chosen = draft.tabs.filter { tab in tabOptions.contains { $0.tab == tab } }
        let bar: [(String, String)] = [(String(localized: "Dnes"), "sun.max"), (String(localized: "Týden"), "calendar")]
            + tabOptions.filter { chosen.contains($0.tab) }.map { ($0.title, $0.symbol) }
            + [(String(localized: "Nastavení"), "gearshape")]
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 2) {
                ForEach(Array(bar.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 3) {
                        Image(systemName: item.1).scaledFont(.heading)
                        Text(item.0).scaledFont(.caption, weight: .semibold).lineLimit(1).minimumScaleFactor(0.7)
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
                            Image(systemName: item.symbol).scaledFont(.heading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).scaledFont(.body, weight: .bold)
                                Text(item.subtitle).scaledFont(.caption).opacity(0.75).lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
    }

    /// At most two extra tabs: picking a third drops the one picked first.
    func toggleTab(_ tab: AppTab, chosen: [AppTab]) {
        if chosen.contains(tab) {
            draft.tabs = chosen.filter { $0 != tab }
        } else {
            draft.tabs = Array((chosen + [tab]).suffix(UserSettings.maxOptionalTabs))
        }
    }

    var tone: some View {
        let activity = draft.exampleActivity
        let sample: (title: String, body: String, about: String) = switch draft.tone {
        case .normal: (activity.uppercased(), String(localized: "Je 15:00 a \(activity) pořád není hotové."), String(localized: "Věcný a neutrální. Připomene, ale netlačí."))
        case .strict: (activity.uppercased(), String(localized: "Zase to odkládáš. \(activity). Začni."), String(localized: "Přímý a konfrontační. Výchozí volba."))
        case .savage: (String(localized: "GET THE FUCK UP."), String(localized: "Furt meleš o tom, čeho chceš dosáhnout. Tak kde je ta práce? \(activity)."), String(localized: "Tvrdý. Pro ty, kdo potřebují kopanec."))
        }
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ForEach(NotificationTone.allCases) { item in
                    let isOn = draft.tone == item
                    Button { withAnimation { draft.tone = item } } label: {
                        Text(item.title)
                            .scaledFont(.body, weight: .bold)
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
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(sample.title).scaledFont(.body, weight: .bold)
                        Spacer()
                        Text("teď").scaledFont(.caption).foregroundStyle(Theme.textSecondary)
                    }
                    Text(sample.body).scaledFont(.body)
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
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.orange)
                    .padding(12)
                    .background(Theme.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    var times: some View {
        VStack(alignment: .leading, spacing: 10) {
            timeRow(String(localized: "Ranní přehled"), String(localized: "Co tě dnes čeká"), minutes: $draft.morningMinutes, range: 5 * 60...12 * 60)
            timeRow(String(localized: "Večerní bilance"), String(localized: "Jak dnešek dopadl"), minutes: $draft.eveningMinutes, range: 17 * 60...23 * 60 + 30)
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Nedělní plánování").scaledFont(.body, weight: .bold).foregroundStyle(Theme.textPrimary)
                    Text("Připomínky do 21:00").scaledFont(.caption).foregroundStyle(Theme.textSecondary)
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
                                            textColor: notificationsAllowed ? Theme.onPrimary : Theme.onPrimary))
            .disabled(notificationsAllowed)
            note(String(localized: "Bez upozornění Kept nemůže připomínat úkoly ani hlídat sérii. iPhone se zeptá jen jednou."))
        }
        .task {
            notificationsAllowed = await NotificationManager.authorizationStatus() == .authorized
        }
    }

    func timeRow(_ title: String, _ subtitle: String, minutes: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).scaledFont(.body, weight: .bold).foregroundStyle(Theme.textPrimary)
                Text(subtitle).scaledFont(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            compactStepper(String(format: "%02d:%02d", minutes.wrappedValue / 60, minutes.wrappedValue % 60),
                           minus: { minutes.wrappedValue = max(range.lowerBound, minutes.wrappedValue - 30) },
                           plus: { minutes.wrappedValue = min(range.upperBound, minutes.wrappedValue + 30) })
        }
        .card()
    }

    var points: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(shownPoints)")
                        .scaledFont(.hero, weight: .heavy)
                        .monospacedDigit()
                        .foregroundStyle(Theme.green)
                        .contentTransition(.numericText())
                    Text("BODŮ NA START").labelStyle()
                }
                ThinBar(value: Double(shownPoints) / Double(PointsService.passCost), color: Theme.green)
                Text("Do první propustky chybí \(PointsService.passCost - PointsService.startingBalance).")
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .card()
            HStack(alignment: .top, spacing: 10) {
                pointsList(String(localized: "ZÍSKÁŠ"), [("+\(PointsService.perCommitment)", String(localized: "splněný závazek")),
                                     ("+\(PointsService.perSuggestion)", String(localized: "splněný návrh")),
                                     ("+\(DiaryService.pointsPerEntry)", String(localized: "den v deníku")),
                                     ("+50…1 000", String(localized: "milníky série"))], color: Theme.green)
                pointsList(String(localized: "UTRATÍŠ"), [("1 000", "propustka"),
                                      ("\(ShopItem.streakInsurance.cost)", String(localized: "pojistka série")),
                                      ("\(ShopItem.extraPostpone.cost)", String(localized: "odklad navíc")),
                                      ("\(PointsService.streakRepairCost)", String(localized: "vrácení série / den"))], color: Theme.textPrimary)
            }
        }
    }

    func pointsList(_ title: String, _ rows: [(String, String)], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).labelStyle()
            ForEach(rows, id: \.1) { value, label in
                (Text(value).fontWeight(.heavy).foregroundColor(color) + Text(" \(label)").foregroundColor(Theme.textPrimary))
                    .scaledFont(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }

    var summary: some View {
        let split = draft.split == .own
            ? (draft.ownWorkouts.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: " / "))
            : draft.split.title
        let tabNames = tabOptions.filter { draft.tabs.contains($0.tab) }.map(\.title)
        let rows: [(String, String)] = [
            ("Vzhled", (AppAppearance(rawValue: appearanceRaw) ?? .dark).title),
            (String(localized: "Oslovení"), draft.addressName.trimmingCharacters(in: .whitespaces).isEmpty ? String(localized: "bez jména") : draft.addressName),
            ("Aktivity", draft.activityNames.joined(separator: ", ")),
            (String(localized: "Minimum"), draft.minimum == 0 ? String(localized: "bez minima") : String(localized: "\(draft.minimum) týdně")),
            (String(localized: "Gym"), draft.doesGym ? String(localized: "\(draft.gymMode.title) · \(split), asi \(draft.gymPerWeek)× týdně") : String(localized: "ne")),
            (String(localized: "Zdraví"), draft.health ? "propojeno" : String(localized: "později")),
            (String(localized: "Deník"), draft.diary ? (draft.diaryLock ? String(localized: "zapnutý, zamčený") : String(localized: "zapnutý")) : String(localized: "vypnutý")),
            (String(localized: "Zámek aplikace"), draft.appLock ? String(localized: "Face ID") : String(localized: "bez zámku")),
            (String(localized: "Lišta"), ([String(localized: "Dnes"), String(localized: "Týden")] + tabNames + [String(localized: "Nastavení")]).joined(separator: " · ")),
            (String(localized: "Tón"), draft.tone.title),
        ]
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(rows, id: \.0) { key, value in
                HStack(alignment: .top) {
                    Text(key).scaledFont(.body).foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 16)
                    Text(value.isEmpty ? "—" : value)
                        .scaledFont(.body, weight: .bold)
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.trailing)
                }
                .card(padding: 12)
            }
            note(String(localized: "Všechno změníš v Nastavení. Teď si naplánuj první týden a odešli plánovač."))
                .padding(.top, 6)
        }
    }
}
