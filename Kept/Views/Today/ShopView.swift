import SwiftUI
import SwiftData

/// Where points are spent, and the streak milestones that hand out more of them.
struct ShopView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var tasks: [TaskItem]
    @Query private var purchases: [PointsPurchase]
    @Query private var diary: [DiaryEntry]
    @State private var confirmItem: ShopItem?
    @State private var confirmRepair: StreakService.Broken?
    @State private var showsPassInfo = false
    /// How many times each row's price was tapped without enough points; drives the shake.
    @State private var refusals: [String: Int] = [:]

    private var balance: Int { PointsService.balance(tasks, purchases: purchases, diary: diary) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                    header
                    VStack(spacing: 10) {
                        SectionLabel(text: "Za body")
                        if let broken = StreakService.broken(tasks), broken.canRepair() {
                            row(symbol: "flame.fill", title: "Vrátit sérii \(String.days(broken.length))",
                                summary: "Plamínek se vrátí, jako by se nepřerušil. Jde to jen 48 hodin od půlnoci, kdy série skončila.",
                                cost: broken.cost, note: nil) { confirmRepair = broken }
                        }
                        ForEach(ShopItem.allCases) { item in
                            let owned = PointsService.unused(item, in: purchases)
                            row(symbol: item.symbol, title: item.title, summary: item.summary, cost: item.cost,
                                note: note(for: item, owned: owned),
                                soldOut: item.maxStored.map { owned >= $0 } ?? false) { confirmItem = item }
                        }
                        passRow
                    }
                    milestones
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 32)
            }
            .screenBackground()
            .navigationTitle("Obchod")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Hotovo") { dismiss() }.foregroundStyle(Theme.textPrimary)
                }
            }
        }
        .appAppearance()
        .alert(confirmItem.map { "Koupit „\($0.title)“ za \($0.cost) bodů?" } ?? "",
               isPresented: Binding(get: { confirmItem != nil }, set: { if !$0 { confirmItem = nil } }),
               presenting: confirmItem) { item in
            Button("Koupit") { withAnimation { context.insert(PointsPurchase(item)) } }
            Button("Zrušit", role: .cancel) {}
        }
        .alert("Propustku použiješ u úkolu", isPresented: $showsPassInfo) {
            Button("Rozumím", role: .cancel) {}
        } message: {
            Text("Body na ni máš. Na obrazovce Dnes klepni u závazku na Přeskočit a zvol „Zrušit za \(PointsService.passCost) bodů bez postihu“. Odečtou se až tam.")
        }
        .alert(confirmRepair.map { "Vrátit sérii za \($0.cost) bodů?" } ?? "",
               isPresented: Binding(get: { confirmRepair != nil }, set: { if !$0 { confirmRepair = nil } }),
               presenting: confirmRepair) { broken in
            Button("Vrátit sérii") { withAnimation { StreakService.repair(broken, tasks: tasks) } }
            Button("Zrušit", role: .cancel) {}
        } message: { _ in
            Text("Nesplněné úkoly těch dnů i jejich vliv na spolehlivost zůstávají.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(balance.formatted(.number.locale(.app)))")
                    .font(.system(size: 56, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
                Text("BODŮ").labelStyle()
            }
            ThinBar(value: Double(balance) / Double(PointsService.cap))
            Text("Strop je \(PointsService.cap.formatted(.number.locale(.app))). \(PointsService.perCommitment) za splněný týdenní závazek, \(PointsService.perSuggestion) za splněný návrh aplikace, \(DiaryService.pointsPerEntry) za den v deníku, bonusy za milníky série.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .animation(.easeOut(duration: 0.4), value: balance)
    }

    private func note(for item: ShopItem, owned: Int) -> String? {
        switch item {
        case .streakInsurance:
            owned > 0 ? "Máš připraveno: \(owned) z \(item.maxStored ?? owned)" : nil
        case .extraPostpone:
            PointsService.extraPostponements(purchases) > 0
                ? "Tento měsíc koupeno: \(PointsService.extraPostponements(purchases))" : nil
        }
    }

    /// One thing on offer. The price is the button: white when affordable, grey with a red price when not.
    private func row(symbol: String, title: String, summary: String, cost: Int, note: String?, soldOut: Bool = false,
                     action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(Theme.orange)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(summary)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let note {
                    Text(note)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.green)
                }
                Button(soldOut ? "MÁŠ MAXIMUM" : "\(cost.formatted(.number.locale(.app))) BODŮ") {
                    guard balance < cost else { return action() }
                    // Not enough points: the price shakes its head instead of doing nothing.
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    withAnimation(.linear(duration: 0.4)) { refusals[title, default: 0] += 1 }
                }
                .buttonStyle(PriceButtonStyle(state: soldOut ? .soldOut : (balance >= cost ? .affordable : .tooExpensive)))
                .disabled(soldOut)
                .modifier(Shake(animatableData: CGFloat(refusals[title, default: 0])))
                .padding(.top, 6)
                if !soldOut, balance < cost {
                    Text("Chybí ti \((cost - balance).formatted(.number.locale(.app))) bodů")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .card()
    }

    /// The pass is spent directly on a task, so its button only explains where.
    private var passRow: some View {
        row(symbol: "ticket.fill", title: "Propustka ze závazku",
            summary: "Zruší jeden otevřený týdenní závazek bez postihu. Použiješ ji přímo u úkolu: klepni na Přeskočit a zvol zrušení za body.",
            cost: PointsService.passCost, note: nil) { showsPassInfo = true }
    }

    private var milestones: some View {
        let all = StreakService.milestones(tasks)
        return VStack(spacing: 10) {
            SectionLabel(text: "Milníky série")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(all) { milestone in
                    let reached = milestone.reachedOn != nil
                    VStack(spacing: 6) {
                        Image(systemName: reached ? "flame.fill" : "flame")
                            .font(.system(size: 26))
                            .foregroundStyle(reached ? Theme.orange : Theme.textTertiary)
                        Text(String.days(milestone.days))
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(reached ? Theme.textPrimary : Theme.textSecondary)
                        Text(reached ? (milestone.reachedOn?.dayMonthText ?? "") : "+\(milestone.bonus.formatted(.number.locale(.app))) bodů")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(reached ? Theme.green : Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radius)
                        .stroke(reached ? Theme.orange.opacity(0.5) : Theme.border, lineWidth: 1))
                }
            }
            Text("Za každý milník dostaneš body jednou, ve chvíli, kdy na něj série poprvé dosáhne.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The price button of a shop row.
private struct PriceButtonStyle: ButtonStyle {
    enum State { case affordable, tooExpensive, soldOut }
    let state: State

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(state == .affordable ? Theme.onPrimary : (state == .tooExpensive ? Theme.red : Theme.textSecondary))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.textPrimary.opacity(state == .affordable ? 1 : 0.16))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(state == .affordable ? Color.clear : Theme.border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// A quick left-right shake, played once every time `animatableData` goes up by one.
private struct Shake: GeometryEffect {
    var animatableData: CGFloat
    private static let distance: CGFloat = 8
    private static let swings: CGFloat = 3

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: Self.distance * sin(animatableData * .pi * 2 * Self.swings), y: 0))
    }
}
