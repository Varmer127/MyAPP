import SwiftUI

/// Poking a friend: one short text of your own, up to 100 characters. One person can be poked once every 3 hours.
struct PokeView: View {
    let friend: Friend
    @Environment(\.dismiss) private var dismiss
    private let friends = FriendsService.shared
    @State private var text = ""
    @State private var isBusy = false
    @State private var errorText: LocalizedStringKey?
    @FocusState private var focused: Bool

    private var waitingUntil: Date? {
        friends.cooldowns[friend.id].flatMap { $0 > AccountService.shared.now ? $0 : nil }
    }

    private var remaining: Int { PokeText.maxCharacters - text.count }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("PROŠŤOUCHNOUT").labelStyle()
                Text(friend.displayName)
                    .scaledFont(.title, weight: .heavy)
                    .foregroundStyle(Theme.textPrimary)
                if let waitingUntil {
                    waiting(until: waitingUntil)
                } else {
                    composer
                }
                if let errorText {
                    Text(errorText).scaledFont(.caption).foregroundStyle(Theme.red)
                }
                Spacer()
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 8)
            .screenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Zavřít") { dismiss() } } }
            .onAppear { focused = true }
        }
        .appAppearance()
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .trailing, spacing: 6) {
                TextField("Napiš, co mu chceš říct", text: $text, axis: .vertical)
                    .lineLimit(2...5)
                    .focused($focused)
                    .scaledFont(.body)
                    .foregroundStyle(Theme.textPrimary)
                    .onChange(of: text) { _, new in
                        if new.count > PokeText.maxCharacters { text = String(new.prefix(PokeText.maxCharacters)) }
                        errorText = nil
                    }
                Text("\(remaining)")
                    .scaledFont(.caption)
                    .foregroundStyle(remaining < 15 ? Theme.orange : Theme.textTertiary)
                    .monospacedDigit()
            }
            .padding(14)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
            if PokeText.containsLink(text) {
                Text("Odkazy se posílat nedají.").scaledFont(.caption).foregroundStyle(Theme.orange)
            }
            Button { send() } label: {
                Text(isBusy ? "POSÍLÁM…" : "ŠŤOUCHNOUT")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!PokeText.isSendable(text) || isBusy)
            Text("Jednoho člověka jde šťouchnout jednou za 3 hodiny. Co napíšeš, uvidí jen on.")
                .scaledFont(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func waiting(until date: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Už jsi ho šťouchl", systemImage: "clock")
                .scaledFont(.body, weight: .semibold)
                .foregroundStyle(Theme.textPrimary)
            Text("Znovu to půjde \(date.formatted(.relative(presentation: .named, unitsStyle: .wide).locale(.app))).")
                .scaledFont(.body)
                .foregroundStyle(Theme.textSecondary)
        }
        .card()
    }

    private func send() {
        isBusy = true
        errorText = nil
        Task {
            defer { isBusy = false }
            do {
                try await friends.poke(friend, text: text)
                Haptics.success()
                dismiss()
            } catch let error as ServerError {
                switch error.code {
                case "too_soon": errorText = "Tohle jsi už poslal nedávno. Zkus to později."; await friends.reload()
                case "do_not_disturb": errorText = "\(friend.displayName) má zapnuté Nerušit."
                case "links_not_allowed": errorText = "Odkazy se posílat nedají."
                case "poke_banned": errorText = "Šťouchání ti bylo vypnuto."
                case "invalid_text": errorText = "Text má mít 1 až 100 znaků."
                default: errorText = "Pošťouchnutí se nepodařilo odeslat. Zkus to prosím znovu."
                }
            } catch {
                errorText = "Pošťouchnutí se nepodařilo odeslat. Zkontroluj připojení."
            }
        }
    }
}

/// "Do not disturb": friends see it and cannot poke. One mode, a reason from a short list or a few own words.
struct DoNotDisturbView: View {
    private let account = AccountService.shared
    private let friends = FriendsService.shared
    @State private var reason: DNDReason = .work
    @State private var custom = ""
    @State private var shared = false
    @State private var hours = 0
    @State private var isBusy = false
    @State private var loaded = false
    @State private var errorText: LocalizedStringKey?

    private static let durations: [(hours: Int, title: LocalizedStringKey)] = [
        (0, "Dokud ho nevypnu"), (1, "1 hodinu"), (4, "4 hodiny"), (8, "8 hodin"), (24, "24 hodin")
    ]

    private var isOn: Bool { account.profile?.dndActive == true }
    private var canSave: Bool { reason != .custom || DNDReason.isValidCustom(custom) }

    var body: some View {
        Form {
            Section {
                Picker("Důvod", selection: $reason) {
                    ForEach(DNDReason.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
                if reason == .custom {
                    TextField("Pár slov, třeba „na horách bez signálu“", text: $custom)
                        .onChange(of: custom) { _, new in
                            if new.count > DNDReason.maxCharacters { custom = String(new.prefix(DNDReason.maxCharacters)) }
                        }
                    Text("\(DNDReason.wordCount(custom)) z \(DNDReason.maxWords) slov")
                        .scaledFont(.caption)
                        .foregroundStyle(DNDReason.wordCount(custom) > DNDReason.maxWords ? Theme.red : Theme.textSecondary)
                }
                Toggle("Ukázat přátelům důvod", isOn: $shared).tint(Theme.textSecondary)
                Picker("Vypnout samo za", selection: $hours) {
                    ForEach(Self.durations, id: \.hours) { Text($0.title).tag($0.hours) }
                }
            } header: {
                Text(isOn ? "Nerušit je zapnuté" : "Nerušit")
            } footer: {
                Text("Přátelé uvidí jen „Nerušit“. Důvod vidí, jen když to povolíš. Dokud je to zapnuté, nikdo tě nemůže šťouchnout.")
            }
            .listRowBackground(Theme.card)

            Section {
                Button(isBusy ? "Ukládám…" : (isOn ? "Uložit změny" : "Zapnout Nerušit")) { save(active: true) }
                    .disabled(!canSave || isBusy)
                if isOn {
                    Button("Vypnout Nerušit", role: .destructive) { save(active: false) }
                        .foregroundStyle(Theme.red)
                        .disabled(isBusy)
                }
            } footer: {
                if let errorText { Text(errorText).foregroundStyle(Theme.red) }
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Nerušit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .onAppear(perform: load)
    }

    /// Starts from what is set now, so changing one detail does not reset the rest.
    private func load() {
        guard !loaded, let profile = account.profile else { return }
        loaded = true
        reason = DNDReason(rawValue: profile.dndReasonKey ?? "") ?? .work
        custom = profile.dndReasonText ?? ""
        shared = profile.dndReasonShared
    }

    private func save(active: Bool) {
        isBusy = true
        errorText = nil
        Task {
            defer { isBusy = false }
            do {
                try await friends.setDND(active: active, reason: active ? reason : nil, text: custom, shared: shared, hours: hours)
                Haptics.success()
            } catch let error as ServerError where error.code == "invalid_reason" {
                errorText = "Vlastní důvod má mít nejvýš \(DNDReason.maxWords) slov."
            } catch {
                errorText = "Nepodařilo se to uložit. Zkontroluj připojení a zkus to znovu."
            }
        }
    }
}
