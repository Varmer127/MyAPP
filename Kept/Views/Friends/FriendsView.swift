import SwiftUI

/// The friends screen. Without an account it is a locked preview that leads to the registration.
struct FriendsView: View {
    private let account = AccountService.shared
    private let friends = FriendsService.shared
    @State private var showsAdd = false
    @State private var showsRegistration = false
    @State private var selected: Friend?
    @State private var poking: Friend?
    @State private var reportingPoke: ReceivedPoke?
    @State private var errorText: LocalizedStringKey?

    var body: some View {
        Group {
            switch account.state {
            case .ready: list
            case .unavailable: unavailable
            case .needsProfile: locked
            case .unknown, .signedOut: locked
            }
        }
        .screenBackground()
        .navigationTitle("Přátelé")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .sheet(isPresented: $showsRegistration) { RegistrationView() }
        .sheet(isPresented: $showsAdd) { AddFriendView() }
        .sheet(item: $selected) { FriendDetailView(friend: $0) }
        .sheet(item: $poking) { PokeView(friend: $0) }
        .confirmationDialog("Nahlásit pošťouchnutí", isPresented: Binding(get: { reportingPoke != nil }, set: { if !$0 { reportingPoke = nil } }),
                            titleVisibility: .visible) {
            ForEach(ReportReason.allCases) { reason in
                Button(String(localized: reason.title)) { reportPoke(with: reason) }
            }
        } message: {
            Text("Text zmizí a my ho uvidíme. Ten člověk se nedozví, kdo ho nahlásil.")
        }
        .task {
            await friends.reload()
            await BetsService.shared.reload()
            await TogetherService.shared.reload()
            // The list is on screen now, so the pokes count as seen after a moment.
            try? await Task.sleep(for: .seconds(2))
            await friends.markPokesSeen()
        }
    }

    // MARK: Signed in

    private var list: some View {
        List {
            if !friends.incoming.isEmpty {
                Section {
                    ForEach(friends.incoming) { request in
                        HStack(spacing: 12) {
                            Avatar(initial: request.initial)
                            Text(request.displayName)
                                .scaledFont(.body, weight: .semibold)
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            ActionButton(title: "Odmítnout", look: .pill(.secondary)) {
                                try await friends.respond(to: request, accept: false)
                            }
                            ActionButton(title: "Přijmout", symbol: "person.fill.checkmark", look: .pill(.positive)) {
                                try await friends.respond(to: request, accept: true)
                            }
                        }
                        .padding(.vertical, 2)
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                                removal: .scale(scale: 0.9).combined(with: .opacity)))
                    }
                } header: {
                    Label("Chtějí být tvoji přátelé · \(friends.incoming.count)", systemImage: "person.badge.plus")
                        .foregroundStyle(Theme.orange)
                }
                .listRowBackground(Theme.card)
            }

            Section {
                Button { showsAdd = true } label: {
                    Label("Přidat přítele", systemImage: "person.badge.plus")
                }
                NavigationLink {
                    DoNotDisturbView()
                } label: {
                    LabeledContent {
                        Text(account.profile?.dndActive == true ? "Zapnuto" : "Vypnuto")
                            .foregroundStyle(Theme.textSecondary)
                    } label: {
                        Label("Nerušit", systemImage: "moon")
                    }
                }
            }
            .listRowBackground(Theme.card)

            Section("Spolu") {
                togetherRow("Sázky", "trophy", BetsService.shared.waiting.count) { BetsView() }
                togetherRow("Společné výzvy", "flag.2.crossed", TogetherService.shared.challenges.filter(\.isInvited).count) { ChallengesView() }
                togetherRow("Skupiny", "person.3", TogetherService.shared.groups.filter(\.isInvited).count) { GroupsView() }
                togetherRow("Společné aktivity", "calendar.badge.plus", TogetherService.shared.activities.filter(\.isInvited).count) { ActivitiesView() }
                togetherRow("Parťáci", "figure.2", TogetherService.shared.incomingBuddies.count) { BuddyView() }
                togetherRow("Svědek", "person.badge.shield.checkmark", TogetherService.shared.witnessing.toAnswer.count) { WitnessInboxView() }
            }
            .listRowBackground(Theme.card)

            if !friends.pokes.isEmpty {
                Section("Pošťouchnutí") {
                    ForEach(friends.pokes) { poke in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                if !poke.seen { Circle().fill(Theme.green).frame(width: 8, height: 8) }
                                Text(poke.senderName)
                                    .scaledFont(.body, weight: .semibold)
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text(poke.createdAt.formatted(.relative(presentation: .named).locale(.app)))
                                    .scaledFont(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Text(poke.body)
                                .scaledFont(.body)
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 2)
                        .swipeActions {
                            Button("Smazat", role: .destructive) { Task { try? await friends.delete(poke) } }
                            Button("Nahlásit") { reportingPoke = poke }.tint(Theme.orange)
                        }
                    }
                }
                .listRowBackground(Theme.card)
            }

            Section {
                if friends.friends.isEmpty, friends.hasLoaded {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Zatím tu nikdo není.")
                            .scaledFont(.body, weight: .semibold)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Ukaž kamarádovi svůj QR kód, nebo mu pošli své označení. Co sdílíš, rozhoduješ ty.")
                            .scaledFont(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
                ForEach(friends.friends) { friend in
                    HStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Avatar(initial: String(friend.displayName.prefix(1)).uppercased())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend.displayName)
                                    .scaledFont(.body, weight: .semibold)
                                    .foregroundStyle(Theme.textPrimary)
                                Text(friend.handle)
                                    .scaledFont(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selected = friend }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        if friend.dnd {
                            Label(friend.dndReasonKey == nil ? "Nerušit" : "Nerušit · \(Self.reasonText(friend))", systemImage: "moon.fill")
                                .scaledFont(.caption, weight: .semibold)
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        } else {
                            Button {
                                Haptics.light()
                                poking = friend
                            } label: {
                                Label(waiting(for: friend) ? "Počkej" : "Šťouchnout", systemImage: "hand.point.right.fill")
                                    .symbolEffect(.wiggle, options: .nonRepeating, value: poking?.id == friend.id)
                            }
                            .buttonStyle(PillButtonStyle(kind: waiting(for: friend) ? .secondary : .primary))
                        }
                    }
                }
            } header: {
                Text("Přátelé \(friends.friends.count)")
            }
            .listRowBackground(Theme.card)

            if friends.leaderboard.count > 1 {
                LeaderboardSection()
            }

            if !friends.outgoing.isEmpty {
                Section("Čeká na odpověď") {
                    ForEach(friends.outgoing) { request in
                        HStack(spacing: 12) {
                            Avatar(initial: request.initial)
                            Text(request.displayName)
                                .scaledFont(.body)
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            ActionButton(title: "Zrušit", look: .pill(.secondary)) { try await friends.cancel(request) }
                        }
                    }
                }
                .listRowBackground(Theme.card)
            }

            if !friends.blocked.isEmpty {
                Section {
                    ForEach(friends.blocked) { person in
                        HStack {
                            Text(person.displayName).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            ActionButton(title: "Odblokovat", look: .pill(.secondary)) { try await friends.unblock(person.id) }
                        }
                    }
                } header: {
                    Text("Zablokovaní")
                } footer: {
                    Text("Zablokovaný člověk tě nenajde a nemůže ti poslat žádost.")
                }
                .listRowBackground(Theme.card)
            }

            if let errorText {
                Section { Text(errorText).scaledFont(.caption).foregroundStyle(Theme.red) }
                    .listRowBackground(Theme.card)
            }
        }
        .scrollContentBackground(.hidden)
        .refreshable { await friends.reload() }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: friends.incoming.map(\.id))
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: friends.friends.map(\.id))
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: friends.outgoing.map(\.id))
    }

    private var unavailable: some View {
        VStack(spacing: 16) {
            Text("Účet se nenačetl.")
                .scaledFont(.heading, weight: .bold)
                .foregroundStyle(Theme.textPrimary)
            Text("Zkontroluj připojení a zkus to znovu.")
                .scaledFont(.body)
                .foregroundStyle(Theme.textSecondary)
            Button("ZKUSIT ZNOVU") { Task { await account.reload() } }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Theme.screenPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func togetherRow<Destination: View>(_ title: LocalizedStringKey, _ symbol: String, _ waiting: Int,
                                                @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink(destination: destination) {
            LabeledContent {
                if waiting > 0 { Text("\(waiting)").scaledFont(.body, weight: .bold).foregroundStyle(Theme.orange) }
            } label: {
                Label(title, systemImage: symbol)
            }
        }
    }

    private func waiting(for friend: Friend) -> Bool {
        friends.cooldowns[friend.id].map { $0 > account.now } ?? false
    }

    /// The reason a friend chose to show, in words.
    private static func reasonText(_ friend: Friend) -> String {
        if let text = friend.dndReasonText, !text.isEmpty { return text }
        return DNDReason(rawValue: friend.dndReasonKey ?? "").map { String(localized: $0.title) } ?? ""
    }

    private func reportPoke(with reason: ReportReason) {
        guard let poke = reportingPoke else { return }
        reportingPoke = nil
        Task { try? await friends.report(poke, reason: reason) }
    }

    // MARK: Signed out

    /// A taste of what an account unlocks: a blurred sample list and one big button.
    private var locked: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PŘÁTELÉ · VOLITELNÉ").labelStyle()
                    Text("Kept s kamarády.")
                        .scaledFont(.title, weight: .heavy)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Sdílej týden, pošťouchávejte se a sázejte se o body. Bez účtu Kept funguje dál jako dnes.")
                        .scaledFont(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 0) {
                    ForEach(["Anna", "Honza", "Kuba"], id: \.self) { name in
                        HStack(spacing: 12) {
                            Avatar(initial: String(name.prefix(1)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name).scaledFont(.body, weight: .semibold)
                                Text("Držel slovo 6 dní v řadě").scaledFont(.caption)
                            }
                            Spacer()
                            Image(systemName: "hand.point.right")
                        }
                        .foregroundStyle(Theme.textPrimary)
                        .padding(14)
                    }
                }
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                .blur(radius: 5)
                .overlay {
                    Label("Ukázka", systemImage: "lock.fill")
                        .scaledFont(.body, weight: .semibold)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Theme.cardRaised)
                        .clipShape(Capsule())
                }
                .accessibilityHidden(true)
                Button("ODEMKNOUT PŘÁTELE") { showsRegistration = true }
                    .buttonStyle(PrimaryButtonStyle())
                Text("Deník, váha, zdraví a fotky zůstanou jen v tvém telefonu. Nic se nesdílí, dokud to sám nezapneš.")
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.vertical, 20)
        }
    }

}

/// A round badge with the first letter of a name.
struct Avatar: View {
    let initial: String

    var body: some View {
        Text(initial)
            .scaledFont(.body, weight: .heavy)
            .foregroundStyle(Theme.onPrimary)
            .frame(width: 40, height: 40)
            .background(Theme.textPrimary)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}
