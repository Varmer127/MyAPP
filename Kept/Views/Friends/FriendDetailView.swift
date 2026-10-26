import SwiftUI

/// What can be done with one friend: remove, block, report. Each of them ends all sharing with that person.
struct FriendDetailView: View {
    let friend: Friend
    @Environment(\.dismiss) private var dismiss
    private let friends = FriendsService.shared
    @State private var confirmsRemove = false
    @State private var confirmsBlock = false
    @State private var showsReport = false
    @State private var errorText: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Avatar(initial: String(friend.displayName.prefix(1)).uppercased())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(friend.displayName).scaledFont(.heading, weight: .bold).foregroundStyle(Theme.textPrimary)
                            Text(friend.handle).scaledFont(.caption).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    if let since = friend.since {
                        LabeledContent("Přátelé od", value: since.formatted(.dateTime.day().month().year().locale(.app)))
                    }
                }
                .listRowBackground(Theme.card)

                Section {
                    Button("Odebrat z přátel") { confirmsRemove = true }
                    Button("Nahlásit") { showsReport = true }
                    Button("Zablokovat", role: .destructive) { confirmsBlock = true }
                        .foregroundStyle(Theme.red)
                } footer: {
                    if let errorText {
                        Text(errorText).foregroundStyle(Theme.red)
                    } else {
                        Text("Odebráním se přestane sdílet všechno mezi vámi. Zablokovaný člověk tě navíc nenajde a nemůže ti poslat novou žádost.")
                    }
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(friend.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Zavřít") { dismiss() } } }
            .alert("Odebrat \(friend.displayName)?", isPresented: $confirmsRemove) {
                Button("Odebrat", role: .destructive) { run { try await friends.remove(friend.id) } }
                Button("Nechat", role: .cancel) {}
            } message: {
                Text("Přestanete si sdílet všechno. Znovu se přidat můžete kdykoli.")
            }
            .alert("Zablokovat \(friend.displayName)?", isPresented: $confirmsBlock) {
                Button("Zablokovat", role: .destructive) { run { try await friends.block(friend.id) } }
                Button("Nechat", role: .cancel) {}
            } message: {
                Text("Přestanete být přátelé a ten člověk tě už nenajde ani ti nepošle žádost. Odblokovat ho můžeš v seznamu přátel.")
            }
            .sheet(isPresented: $showsReport) {
                ReportView(friend: friend) { dismiss() }
            }
        }
        .appAppearance()
    }

    private func run(_ work: @escaping () async throws -> Void) {
        errorText = nil
        Task {
            do { try await work(); dismiss() }
            catch { errorText = "Nepovedlo se to. Zkus to prosím znovu." }
        }
    }
}

struct ReportView: View {
    let friend: Friend
    var onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    private let friends = FriendsService.shared
    @State private var reason: ReportReason = .abuse
    @State private var note = ""
    @State private var alsoBlock = true
    @State private var isBusy = false
    @State private var errorText: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            Form {
                Section("Co se stalo") {
                    Picker("Důvod", selection: $reason) {
                        ForEach(ReportReason.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                .listRowBackground(Theme.card)
                Section {
                    TextField("Chceš něco dodat? (nepovinné)", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                        .onChange(of: note) { _, new in if new.count > 500 { note = String(new.prefix(500)) } }
                    Toggle("Zároveň zablokovat", isOn: $alsoBlock).tint(Theme.textSecondary)
                } footer: {
                    if let errorText { Text(errorText).foregroundStyle(Theme.red) }
                    else { Text("Nahlášení uvidí jen tvůrce Kept. Ozveme se do 24 hodin a ten člověk se nedozví, kdo ho nahlásil.") }
                }
                .listRowBackground(Theme.card)
                Section {
                    Button(isBusy ? "Odesílám…" : "Odeslat nahlášení") { send() }
                        .disabled(isBusy)
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Nahlásit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Zrušit") { dismiss() } } }
        }
        .appAppearance()
    }

    private func send() {
        isBusy = true
        errorText = nil
        Task {
            defer { isBusy = false }
            do {
                try await friends.report(friend.id, reason: reason, note: note)
                if alsoBlock { try await friends.block(friend.id) }
                Haptics.success()
                dismiss()
                onDone()
            } catch let error as ServerError where error.code == "rate_limited" {
                errorText = "Dnes jsi už poslal hodně nahlášení. Zkus to zítra."
            } catch {
                errorText = "Nahlášení se nepodařilo odeslat. Zkus to prosím znovu."
            }
        }
    }
}
