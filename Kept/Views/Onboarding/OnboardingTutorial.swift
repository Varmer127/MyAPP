import SwiftUI

/// Five small playable demos of how Kept works. Nothing here touches real data.
struct OnboardingTutorial: View {
    /// Activities from the user's own choice, so the examples speak about their life.
    let activity: String
    let secondActivity: String
    /// Called from the last demo's button.
    let onDone: () -> Void

    private enum Demo: Int, CaseIterable, Identifiable {
        case task, planning, planner, streak, missed, score
        var id: Int { rawValue }

        var title: String {
            switch self {
            case .task: "Úkol"
            case .planning: "Plánování"
            case .planner: "Plánovač"
            case .streak: "Série"
            case .missed: "Nesplnil jsem"
            case .score: "Spolehlivost"
            }
        }

        var text: String {
            switch self {
            case .task: "Každý den máš na obrazovce Dnes svoje úkoly. Hotovo, částečně, nebo přeskočit. Za splněný závazek dostaneš 100 bodů, za částečný jen jeho díl."
            case .planning: "Týden si skládáš na obrazovce Týden. Rychlé plánování dá jednu aktivitu na víc dní najednou, zkopírování vezme minulý týden a jeden úkol přidáš plusem u dne. Vyzkoušej všechny tři."
            case .planner: "Týden naplánuješ a odešleš plánovač. Hodinu ho můžeš měnit bez postihu, pak se sám zapečetí. Od té chvíle je každý úkol slib a každá změna se zaznamená."
            case .streak: "Den, kdy splníš aspoň 80 % úkolů, rozdmýchá plamínek. Jeden špatný den ho zhasne. Kept tě večer varuje a po přerušení ještě týden připomíná."
            case .missed: "Nesplněný úkol nezmizí. Buď ho dodáš pozdě, nebo napíšeš proč a co uděláš příště. Kept si to pamatuje a připomene, až se to bude opakovat."
            case .score: "Velké číslo na obrazovce Dnes je tvoje spolehlivost za posledních 30 dní. Klepni na jednotlivé části a uvidíš, z čeho se skládá."
            }
        }
    }

    @State private var demo: Demo = .task

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Demo.allCases) { item in
                        let isOn = demo == item
                        Button { withAnimation(.easeOut(duration: 0.2)) { demo = item } } label: {
                            Text(item.title)
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 12)
                                .frame(minHeight: 36)
                                .foregroundStyle(isOn ? Theme.onPrimary : Theme.textSecondary)
                                .background(isOn ? Theme.textPrimary : Color.clear)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(isOn ? Theme.textPrimary : Theme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Text(demo.text)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .id(demo)
            VStack(alignment: .leading, spacing: 12) {
                Text("VYZKOUŠEJ SI TO").font(.system(size: 10, weight: .heavy)).tracking(1.4).foregroundStyle(Theme.orange)
                switch demo {
                case .task: TaskDemo(activity: activity)
                case .planning: PlanningDemo(activity: activity, secondActivity: secondActivity)
                case .planner: PlannerDemo()
                case .streak: StreakDemo()
                case .missed: MissedDemo(activity: secondActivity)
                case .score: ScoreDemo()
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.textSecondary, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            Button {
                if let next = Demo(rawValue: demo.rawValue + 1) {
                    withAnimation(.easeOut(duration: 0.2)) { demo = next }
                } else {
                    onDone()
                }
            } label: {
                Text(Demo(rawValue: demo.rawValue + 1).map { "Další ukázka: \($0.title)" } ?? "Rozumím, pokračovat")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }
}

// MARK: Demos

private func demoButton(_ title: String, fill: Color, text: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.system(size: 13, weight: .heavy))
            .tracking(0.4)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 6)
            .foregroundStyle(text)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
}

private func resultText(_ text: String, color: Color) -> some View {
    Text(text)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(color)
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardRaised)
        .clipShape(RoundedRectangle(cornerRadius: 12))
}

private struct TaskDemo: View {
    let activity: String

    private enum Phase: Equatable { case open, confirm, partial, skip, done, partialDone(Int), postponed, skipped }
    @State private var phase: Phase = .open

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(activity).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.textPrimary)
                    Text("dnes · 45 min").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Badge(text: badge.text, color: badge.color)
            }
            switch phase {
            case .open:
                HStack(spacing: 8) {
                    demoButton("HOTOVO", fill: Theme.green, text: Color(hex: 0x000000)) { set(.confirm) }
                    demoButton("ČÁSTEČNĚ", fill: Theme.cardRaised, text: Theme.orange) { set(.partial) }
                    demoButton("PŘESKOČIT", fill: Theme.cardRaised, text: Theme.red) { set(.skip) }
                }
            case .confirm:
                inner {
                    Text("Opravdu jsi to splnil podle plánu?").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.textPrimary)
                    Text("Kept se ptá pokaždé. Chvilka upřímnosti, než se něco započítá.")
                        .font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                    HStack(spacing: 8) {
                        demoButton("Ještě ne", fill: Theme.card, text: Theme.textPrimary) { set(.open) }
                        demoButton("Ano, splnil", fill: Theme.green, text: Color(hex: 0x000000)) { set(.done) }
                    }
                }
            case .partial:
                inner {
                    Text("Kolik jsi toho udělal?").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.textPrimary)
                    HStack(spacing: 6) {
                        ForEach([25, 50, 75, 90], id: \.self) { share in
                            demoButton("\(share) %", fill: Theme.card, text: Theme.textPrimary) { set(.partialDone(share)) }
                        }
                    }
                }
            case .skip:
                inner {
                    Text("Co s tím úkolem?").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.textPrimary)
                    demoButton("Odložit bez postihu (zbývá 3 ze 3)", fill: Theme.card, text: Theme.textPrimary) { set(.postponed) }
                    demoButton("Přeskočit a vysvětlit", fill: Theme.red, text: Color(hex: 0xFFFFFF)) { set(.skipped) }
                }
            case .done:
                finished("+100 bodů. Závazek dodržen, plamínek se přiblížil.", color: Theme.green)
            case .partialDone(let share):
                finished("+\(share) bodů. Částečně splněno na \(share) %, do spolehlivosti se počítá jen tenhle díl.", color: Theme.orange)
            case .postponed:
                finished("Úkol se přesunul na jiný den bez postihu. Takové odklady máš tři za měsíc.", color: Theme.orange)
            case .skipped:
                finished("Přeskočeno. Teď napíšeš, proč to nevyšlo a co uděláš příště. Počítá se to jako porušený slib.", color: Theme.red)
            }
        }
        .sensoryFeedback(.success, trigger: phase) { _, new in new == .done }
    }

    private var badge: (text: String, color: Color) {
        switch phase {
        case .done: ("Hotovo", Theme.green)
        case .partialDone: ("Částečně", Theme.orange)
        case .postponed: ("Odloženo", Theme.orange)
        case .skipped: ("Přeskočeno", Theme.red)
        default: ("Otevřeno", Theme.textSecondary)
        }
    }

    private func set(_ new: Phase) { withAnimation(.easeOut(duration: 0.2)) { phase = new } }

    private func inner(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardRaised)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func finished(_ text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            resultText(text, color: color)
            Button("Zkusit znovu") { set(.open) }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .frame(minHeight: 44)
        }
    }
}

private struct PlanningDemo: View {
    let activity: String
    let secondActivity: String

    private enum Mode: String, CaseIterable, Identifiable {
        case quick = "Rychle", copy = "Kopie týdne", single = "Jeden úkol"
        var id: String { rawValue }
    }

    private static let dayNames = ["PO", "ÚT", "ST", "ČT", "PÁ", "SO", "NE"]

    @State private var mode: Mode = .quick
    @State private var items: [(day: Int, title: String)] = []
    @State private var quickTitle: String?
    @State private var quickDays: Set<Int> = [0, 2, 4]
    @State private var singleDay = 1

    private var activities: [String] { Array(Set([TaskCategory.gym.title, activity, secondActivity])).sorted() }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                ForEach(Mode.allCases) { item in
                    let isOn = mode == item
                    Button { withAnimation(.easeOut(duration: 0.2)) { mode = item } } label: {
                        Text(item.rawValue)
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .foregroundStyle(isOn ? Theme.onPrimary : Theme.textPrimary)
                            .background(isOn ? Theme.textPrimary : Theme.cardRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(explanation)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            controls
            week
        }
    }

    private var explanation: String {
        switch mode {
        case .quick: "Vyber aktivitu a dny, jedním klepnutím ji přidáš na všechny. Ideální na gym nebo čtení několikrát týdně."
        case .copy: "Když se ti minulý týden osvědčil, vezmeš ho celý. Co už v plánu máš, se nezdvojí."
        case .single: "Plusem u dne přidáš jeden úkol s vlastním časem, délkou a prioritou."
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch mode {
        case .quick:
            let title = quickTitle ?? activities[0]
            FlowLayout(spacing: 6) {
                ForEach(activities, id: \.self) { name in
                    pill(name, isOn: name == title) { quickTitle = name }
                }
            }
            dayPicker(isOn: { quickDays.contains($0) }) { day in
                if quickDays.contains(day) { quickDays.remove(day) } else { quickDays.insert(day) }
            }
            demoButton(quickDays.isEmpty ? "VYBER DNY" : "PŘIDAT \(quickDays.count)×", fill: Theme.textPrimary, text: Theme.onPrimary) {
                add(quickDays.sorted().map { ($0, title) })
            }
            .disabled(quickDays.isEmpty)
        case .copy:
            Text("Minulý týden: \(TaskCategory.gym.title) 3×, \(activity) 2×, \(secondActivity) 1×")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            demoButton("ZKOPÍROVAT MINULÝ TÝDEN", fill: Theme.textPrimary, text: Theme.onPrimary) {
                add([(0, TaskCategory.gym.title), (2, TaskCategory.gym.title), (4, TaskCategory.gym.title),
                     (1, activity), (3, activity), (5, secondActivity)])
            }
        case .single:
            dayPicker(isOn: { $0 == singleDay }) { singleDay = $0 }
            demoButton("+ PŘIDAT ÚKOL NA \(Self.dayNames[singleDay])", fill: Theme.textPrimary, text: Theme.onPrimary) {
                add([(singleDay, secondActivity)])
            }
        }
    }

    private var week: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TVŮJ TÝDEN · V PLÁNU \(items.count)").labelStyle()
                Spacer()
                if !items.isEmpty {
                    Button("Vymazat") { withAnimation { items = [] } }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(minHeight: 32)
                }
            }
            HStack(alignment: .top, spacing: 6) {
                ForEach(0..<7, id: \.self) { day in
                    let titles = items.filter { $0.day == day }.map(\.title)
                    VStack(spacing: 4) {
                        Text(Self.dayNames[day]).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textSecondary)
                        VStack(spacing: 3) {
                            ForEach(Array(titles.enumerated()), id: \.offset) { _, title in
                                Capsule()
                                    .fill(title == TaskCategory.gym.title ? Theme.orange : Theme.textPrimary)
                                    .frame(height: 6)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .top)
                        .padding(5)
                        .background(Theme.cardRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        Text(titles.isEmpty ? " " : "\(titles.count)×").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            if let duplicate {
                Text(duplicate)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The real app asks before adding the same activity to the same day twice; here it just says so.
    @State private var duplicate: String?

    private func add(_ new: [(Int, String)]) {
        let clashes = new.filter { entry in items.contains { $0.day == entry.0 && $0.title == entry.1 } }
        duplicate = clashes.isEmpty ? nil
            : "„\(clashes[0].1)“ už na \(Self.dayNames[clashes[0].0]) máš. V aplikaci se tě Kept zeptá, jestli ho tam chceš podruhé."
        withAnimation(.spring(duration: 0.35)) {
            items += new.filter { entry in !items.contains { $0.day == entry.0 && $0.title == entry.1 } }.map { (day: $0.0, title: $0.1) }
        }
    }

    private func pill(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .foregroundStyle(isOn ? Theme.onPrimary : Theme.textPrimary)
                .background(isOn ? Theme.textPrimary : Theme.cardRaised)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func dayPicker(isOn: @escaping (Int) -> Bool, toggle: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<7, id: \.self) { day in
                let on = isOn(day)
                Button { toggle(day) } label: {
                    Text(Self.dayNames[day])
                        .font(.system(size: 12, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .foregroundStyle(on ? Theme.onPrimary : Theme.textPrimary)
                        .background(on ? Theme.textPrimary : Theme.cardRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct PlannerDemo: View {
    private enum Phase { case draft, sealing, sealed }
    @State private var phase: Phase = .draft
    @State private var secondsLeft = 3600

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().stroke(Theme.cardRaised, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: phase == .draft ? 1 : Double(secondsLeft) / 3600)
                    .stroke(phase == .sealed ? Theme.green : Theme.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    if phase == .sealed {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 30)).foregroundStyle(Theme.green)
                    } else {
                        Text(FocusView.clock(TimeInterval(secondsLeft)))
                            .font(.system(size: 26, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Text(phase == .draft ? "NÁVRH" : (phase == .sealed ? "ZAPEČETĚNO" : "DO ZAPEČETĚNÍ"))
                        .font(.system(size: 9, weight: .bold)).tracking(0.8).foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: 132, height: 132)
            Text(phase == .draft ? "Týden je naplánovaný, ale zatím je to jen návrh."
                 : (phase == .sealed ? "Zapečetěno. Teď je každý úkol slib. Smazání nebo přesun sníží věrnost plánu."
                    : "Hodina běží (tady zrychleně). Dokud neskončí, můžeš plán měnit bez postihu."))
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(phase == .draft ? "ODESLAT PLÁNOVAČ" : (phase == .sealed ? "ZNOVU" : "STÁHNOUT PLÁNOVAČ")) {
                switch phase {
                case .draft: phase = .sealing
                case .sealing, .sealed:
                    phase = .draft
                    secondsLeft = 3600
                }
            }
            .buttonStyle(PrimaryButtonStyle(color: phase == .sealing ? Theme.orange : Theme.textPrimary,
                                            textColor: phase == .sealing ? Color(hex: 0x000000) : Theme.onPrimary))
        }
        .frame(maxWidth: .infinity)
        .task(id: phase) {
            guard phase == .sealing else { return }
            while secondsLeft > 0, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(90))
                withAnimation(.linear(duration: 0.09)) { secondsLeft = max(0, secondsLeft - 60) }
            }
            if secondsLeft == 0, !Task.isCancelled {
                withAnimation { phase = .sealed }
            }
        }
        .sensoryFeedback(.success, trigger: phase) { _, new in new == .sealed }
    }
}

private struct StreakDemo: View {
    @State private var days = [true, true, false, true, true, true, true]
    private static let names = ["PO", "ÚT", "ST", "ČT", "PÁ", "SO", "NE"]

    private var count: Int { days.reversed().prefix { $0 }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 28))
                    .symbolEffect(.bounce, value: count)
                Text("\(count)")
                    .font(.system(size: 26, weight: .heavy))
                    .contentTransition(.numericText())
                Text(count == 1 ? "den v řadě" : (2...4 ~= count ? "dny v řadě" : "dní v řadě"))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
            }
            .foregroundStyle(count > 0 ? Theme.orange : Theme.textSecondary)
            HStack(spacing: 6) {
                ForEach(days.indices, id: \.self) { index in
                    let ok = days[index]
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { days[index].toggle() }
                    } label: {
                        VStack(spacing: 2) {
                            Text(Self.names[index]).font(.system(size: 10, weight: .bold))
                            Image(systemName: ok ? "checkmark" : "xmark").font(.system(size: 12, weight: .heavy))
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(ok ? Theme.green : Theme.red)
                        .background((ok ? Theme.green : Theme.red).opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(Self.names[index]): \(ok ? "splněno" : "nesplněno")")
                }
            }
            Text("Klepnutím na den přepínáš, jestli vyšel. Den bez úkolů sérii nepřeruší.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
            if days.last == false {
                resultText("Série skončila. Do 48 hodin ji můžeš vrátit za \(PointsService.streakRepairCost) bodů za každý vynechaný den, nebo začít znovu.",
                           color: Theme.orange)
            }
        }
    }
}

private struct MissedDemo: View {
    let activity: String

    private enum Phase: Equatable { case open, reasons, late, written(String) }
    @State private var phase: Phase = .open

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("NESPLNĚNO · VČERA").font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(Theme.red)
                Text(activity).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.textPrimary)
            }
            switch phase {
            case .open:
                HStack(spacing: 8) {
                    demoButton("SPLNĚNO POZDĚ", fill: Theme.orange, text: Color(hex: 0x000000)) { set(.late) }
                    demoButton("NESPLNIL JSEM", fill: Theme.cardRaised, text: Theme.red) { set(.reasons) }
                }
            case .reasons:
                VStack(alignment: .leading, spacing: 10) {
                    Text("Proč to nevyšlo?").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.textPrimary)
                    FlowLayout(spacing: 6) {
                        ForEach(["Prokrastinoval jsem", "Nechtělo se mi", "Neměl jsem čas", "Zapomněl jsem"], id: \.self) { reason in
                            Button(reason) { set(.written(reason)) }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 40)
                                .background(Theme.card)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding(14)
                .background(Theme.cardRaised)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            case .late:
                finished("Splněno pozdě. Body dostaneš, ale méně: čím později, tím menší díl.", color: Theme.orange)
            case .written(let reason):
                finished("„\(reason).“ Teď ještě napíšeš sebekritiku a co uděláš příště. Až to bude potřeba, Kept ti tvoje slova připomene.",
                         color: Theme.textPrimary)
            }
        }
    }

    private func set(_ new: Phase) { withAnimation(.easeOut(duration: 0.2)) { phase = new } }

    private func finished(_ text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            resultText(text, color: color)
            Button("Zkusit znovu") { set(.open) }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .frame(minHeight: 44)
        }
    }
}

private struct ScoreDemo: View {
    @State private var open: Int? = 0

    private static let parts: [(label: String, share: Int, fill: Double, text: String)] = [
        ("Dodržené sliby", 40, 0.92, "Kolik zapečetěných závazků jsi opravdu splnil. Největší část skóre."),
        ("Produktivita", 25, 0.81, "Kolik bodové váhy úkolů jsi za den odvedl, kritické úkoly váží víc."),
        ("Věrnost plánu", 15, 0.74, "Jak moc jsi zapečetěný plán měnil. Mazání a přesuny ji snižují."),
        ("Včas", 10, 0.88, "Kolik úkolů jsi splnil do termínu, ne až potom."),
        ("Týdenní cíle", 10, 0.75, "Jak se ti daří orientační cíle, třeba gym zhruba 4× týdně. Žádný postih, jen se to promítne."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("86").font(.system(size: 54, weight: .heavy)).foregroundStyle(Theme.textPrimary)
                Text("SPOLEHLIVOST").labelStyle()
            }
            ForEach(Self.parts.indices, id: \.self) { index in
                let part = Self.parts[index]
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { open = open == index ? nil : index }
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(part.label).font(.system(size: 14, weight: .bold))
                            Spacer()
                            Text("\(part.share) %").font(.system(size: 14, weight: .heavy))
                        }
                        ThinBar(value: part.fill)
                        if open == index {
                            Text(part.text)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .padding(12)
                    .background(Theme.cardRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(open == index ? Theme.textPrimary : Color.clear, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
