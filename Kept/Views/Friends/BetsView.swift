import SwiftData
import SwiftUI

/// Bets for points with friends: open ones first, finished below, and a way to start a new one.
struct BetsView: View {
    private let bets = BetsService.shared
    @State private var creates = false
    @State private var selected: Bet?

    var body: some View {
        List {
            Section {
                Button { creates = true } label: {
                    Label("Vsadit se s přáteli", systemImage: "plus.circle")
                }
            } footer: {
                Text("Hraje se o body, nikdy o peníze. Body jsou během sázky v úschově: vítěz bere všechno, při neshodě nebo bez vítěze se každému vrátí jeho vklad.")
            }
            .listRowBackground(Theme.card)

            if !bets.open.isEmpty {
                Section("Běží") {
                    ForEach(bets.open) { bet in row(bet) }
                }
                .listRowBackground(Theme.card)
            }
            if !bets.finished.isEmpty {
                Section("Skončené") {
                    ForEach(bets.finished) { bet in row(bet) }
                }
                .listRowBackground(Theme.card)
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Sázky")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .refreshable { await bets.reload() }
        .task { await bets.reload() }
        .sheet(isPresented: $creates) { CreateBetView() }
        .sheet(item: $selected) { BetDetailView(betID: $0.id) }
    }

    private func row(_ bet: Bet) -> some View {
        Button { selected = bet } label: {
            HStack(spacing: 12) {
                Image(systemName: bet.kind == .week ? "chart.line.uptrend.xyaxis" : "flag.checkered")
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(bet.title).scaledFont(.body, weight: .semibold).foregroundStyle(Theme.textPrimary).lineLimit(2)
                    Text(BetText.summary(bet)).scaledFont(.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if bet.awaitsMyAnswer || bet.awaitsMyVerdict {
                    Circle().fill(Theme.orange).frame(width: 10, height: 10)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

enum BetText {
    static func summary(_ bet: Bet) -> String {
        switch bet.status {
        case .open:
            if bet.awaitsMyAnswer { return String(localized: "Pozvánka · vklad \(bet.stake) b.") }
            if bet.awaitsMyVerdict { return String(localized: "\(bet.name(of: bet.claimant) ?? "") tvrdí, že to splnil") }
            return String(localized: "V banku \(bet.pot) b. · do \(bet.endsAt.formatted(.dateTime.day().month().locale(.app)))")
        case .settled:
            return bet.winner == bet.me?.id
                ? String(localized: "Vyhrál jsi \(bet.pot) b.")
                : String(localized: "Vyhrál \(bet.name(of: bet.winner) ?? "")")
        case .refunded: return String(localized: "Bez vítěze, vklady vráceny")
        case .cancelled: return String(localized: "Zrušeno, vklad vrácen")
        }
    }
}

struct CreateBetView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var tasks: [TaskItem]
    @Query private var purchases: [PointsPurchase]
    @Query private var diary: [DiaryEntry]
    private let friends = FriendsService.shared
    private let bets = BetsService.shared
    @State private var kind: Bet.Kind = .week
    @State private var title = ""
    @State private var terms = ""
    @State private var stake = 200
    @State private var days = 30
    @State private var invited: Set<UUID> = []
    @State private var isBusy = false
    @State private var errorText: LocalizedStringKey?

    /// Quick picks under the slider.
    private static let lengths: [(days: Int, title: LocalizedStringKey)] = [
        (7, "týden"), (30, "měsíc"), (90, "3 měs."), (365, "rok")
    ]

    private var daysValue: Binding<Double> {
        Binding(get: { Double(days) }, set: { days = Int($0.rounded()) })
    }

    private var endDate: Date { Date.now.addingDays(days) }


    private var balance: Int { PointsService.balance(tasks, purchases: purchases, diary: diary) }
    private var canCreate: Bool {
        !invited.isEmpty && invited.count <= 9 && stake >= 200 && stake <= balance && !isBusy
            && (kind == .week || !title.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Druh", selection: $kind) {
                        Text("Týdenní souboj").tag(Bet.Kind.week)
                        Text("Dlouhodobý cíl").tag(Bet.Kind.goal)
                    }
                    .pickerStyle(.segmented)
                    if kind == .goal {
                        TextField("Cíl, třeba „Bench 100 kg“", text: $title)
                            .onChange(of: title) { _, new in if new.count > 80 { title = String(new.prefix(80)) } }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Do kdy").foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text(endDate.formatted(.dateTime.day().month().year().locale(.app)))
                                    .scaledFont(.body, weight: .semibold)
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            Slider(value: daysValue, in: 1...365, step: 1)
                                .tint(Theme.textPrimary)
                                .accessibilityValue(Text(String.days(days)))
                            HStack {
                                Text(String.days(days)).scaledFont(.caption).foregroundStyle(Theme.textSecondary)
                                Spacer()
                                ForEach(Self.lengths, id: \.days) { length in
                                    Button(length.title) { days = length.days }
                                        .scaledFont(.caption, weight: .semibold)
                                        .foregroundStyle(days == length.days ? Theme.onPrimary : Theme.textPrimary)
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(days == length.days ? Theme.textPrimary : Theme.cardRaised)
                                        .clipShape(Capsule())
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                } footer: {
                    Text(kind == .week
                         ? "Kdo bude mít na konci tohoto týdne vyšší spolehlivost, vyhrává. Při shodě se vklady vrátí."
                         : "Kdo cíl splní první, klepne „Splnil jsem“. Když to ostatní potvrdí, vyhrává. Když to někdo rozporuje, vklady se vrátí.")
                }
                .listRowBackground(Theme.card)

                Section {
                    Stepper("Vklad: \(stake) b.", value: $stake, in: 200...max(200, balance), step: 50)
                    TextField("Co dál? Třeba „kdo prohraje, vaří večeři“ (nepovinné)", text: $terms, axis: .vertical)
                        .lineLimit(1...3)
                        .onChange(of: terms) { _, new in if new.count > 200 { terms = String(new.prefix(200)) } }
                } header: {
                    Text("Sázka")
                } footer: {
                    Text(balance >= 200 ? "Máš \(balance) bodů. Stejný vklad dá každý, kdo pozvánku přijme." : "Na sázku potřebuješ aspoň 200 bodů, teď máš \(balance).")
                }
                .listRowBackground(Theme.card)

                Section {
                    if friends.friends.isEmpty {
                        Text("Nejdřív si přidej přátele.").foregroundStyle(Theme.textSecondary)
                    }
                    ForEach(friends.friends) { friend in
                        Button {
                            if invited.contains(friend.id) { invited.remove(friend.id) } else if invited.count < 9 { invited.insert(friend.id) }
                        } label: {
                            HStack {
                                Text(friend.displayName).foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Image(systemName: invited.contains(friend.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(invited.contains(friend.id) ? Theme.green : Theme.textTertiary)
                            }
                        }
                    }
                } header: {
                    Text("Koho pozveš (\(invited.count) z 9)")
                } footer: {
                    if let errorText { Text(errorText).foregroundStyle(Theme.red) }
                }
                .listRowBackground(Theme.card)

                Section {
                    Button(isBusy ? "POSÍLÁM…" : "POSLAT POZVÁNKY") { create() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!canCreate)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Nová sázka")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Zrušit") { dismiss() } } }
            .task { if friends.friends.isEmpty { await friends.reload() } }
        }
        .appAppearance()
    }

    private func create() {
        isBusy = true
        errorText = nil
        Task {
            defer { isBusy = false }
            do {
                try await bets.create(kind: kind, title: title, terms: terms, stake: stake, days: days, invitees: Array(invited))
                Haptics.success()
                dismiss()
            } catch let error as ServerError where error.code == "rate_limited" {
                errorText = "Dnes jsi založil hodně sázek. Zkus to zítra."
            } catch {
                errorText = "Sázku se nepodařilo založit. Zkus to prosím znovu."
            }
        }
    }
}

struct BetDetailView: View {
    let betID: UUID
    @Environment(\.dismiss) private var dismiss
    @Query private var tasks: [TaskItem]
    @Query private var purchases: [PointsPurchase]
    @Query private var diary: [DiaryEntry]
    private let bets = BetsService.shared
    @State private var errorText: LocalizedStringKey?
    @State private var confirmsClaim = false

    private var bet: Bet? { bets.bets.first { $0.id == betID } }
    private var balance: Int { PointsService.balance(tasks, purchases: purchases, diary: diary) }

    var body: some View {
        NavigationStack {
            Form {
                if let bet {
                    Section {
                        Text(bet.title).scaledFont(.heading, weight: .bold).foregroundStyle(Theme.textPrimary)
                        LabeledContent("Vklad", value: "\(bet.stake) b.")
                        LabeledContent("V banku", value: "\(bet.pot) b.")
                        LabeledContent("Konec", value: bet.endsAt.formatted(.dateTime.day().month().year().locale(.app)))
                        if let terms = bet.terms {
                            LabeledContent("Domluva", value: terms)
                        }
                        Text(BetText.summary(bet)).scaledFont(.caption).foregroundStyle(Theme.textSecondary)
                    }
                    .listRowBackground(Theme.card)

                    Section("Kdo hraje") {
                        ForEach(bet.participants) { person in
                            HStack {
                                Text(person.isMe ? "Ty" : person.name).foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text(state(of: person, in: bet)).scaledFont(.caption).foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .listRowBackground(Theme.card)

                    actions(bet)
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Sázka")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Zavřít") { dismiss() } } }
            .alert("Splnil jsi to?", isPresented: $confirmsClaim) {
                Button("Ano, splnil") { run { try await bets.claim($0) } }
                Button("Ještě ne", role: .cancel) {}
            } message: {
                Text("Ostatní to potvrdí, nebo rozporují. Když to někdo rozporuje, vklady se všem vrátí.")
            }
        }
        .appAppearance()
    }

    @ViewBuilder
    private func actions(_ bet: Bet) -> some View {
        Section {
            if bet.awaitsMyAnswer {
                Button(balance >= bet.stake ? "Přijmout a vsadit \(bet.stake) b." : "Na vklad nemáš dost bodů (\(balance))") {
                    run { try await bets.respond($0, accept: true) }
                }
                .disabled(balance < bet.stake)
                Button("Odmítnout", role: .destructive) { run { try await bets.respond($0, accept: false) } }
                    .foregroundStyle(Theme.red)
            }
            if bet.awaitsMyVerdict {
                Button("Potvrdit, že to splnil") { run { try await bets.judge($0, confirm: true) } }
                Button("Rozporovat", role: .destructive) { run { try await bets.judge($0, confirm: false) } }
                    .foregroundStyle(Theme.red)
            }
            if bet.isOpen, bet.kind == .goal, bet.claimant == nil, bet.me?.status == .accepted {
                Button("Splnil jsem") { confirmsClaim = true }
            }
            if bet.isOpen, bet.isCreator, bet.accepted.count == 1 {
                Button("Zrušit sázku", role: .destructive) { run { try await bets.cancel($0) } }
                    .foregroundStyle(Theme.red)
            }
        } footer: {
            if let errorText { Text(errorText).foregroundStyle(Theme.red) }
        }
        .listRowBackground(Theme.card)
    }

    private func state(of person: Bet.Participant, in bet: Bet) -> LocalizedStringKey {
        if bet.winner == person.id { return "Vítěz" }
        if bet.claimant == person.id { return "Tvrdí, že splnil" }
        switch person.status {
        case .invited: return "Pozván"
        case .declined: return "Odmítl"
        case .accepted:
            if person.verdict == "confirm" { return "Potvrdil" }
            if person.verdict == "dispute" { return "Rozporoval" }
            return "Hraje"
        }
    }

    private func run(_ work: @escaping (Bet) async throws -> Void) {
        guard let bet else { return }
        errorText = nil
        Task {
            do { try await work(bet); Haptics.success() }
            catch { errorText = "Nepovedlo se to. Zkus to prosím znovu." }
        }
    }
}
