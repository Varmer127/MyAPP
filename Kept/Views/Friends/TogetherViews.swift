import SwiftData
import SwiftUI

// Screens for doing things together: challenges, groups, shared activities, the pair buddy and the witness.

/// Pick friends to invite, up to a limit.
struct FriendPicker: View {
    @Binding var selection: Set<UUID>
    let limit: Int
    var excluded: Set<UUID> = []
    private let friends = FriendsService.shared

    var body: some View {
        if friends.friends.isEmpty {
            Text("Nejdřív si přidej přátele.").foregroundStyle(Theme.textSecondary)
        }
        ForEach(friends.friends.filter { !excluded.contains($0.id) }) { friend in
            let isOn = selection.contains(friend.id)
            Button {
                if isOn { selection.remove(friend.id) } else if selection.count < limit { selection.insert(friend.id) }
            } label: {
                HStack {
                    Text(friend.displayName).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isOn ? Theme.green : Theme.textTertiary)
                }
            }
            .accessibilityAddTraits(isOn ? .isSelected : [])
        }
    }
}

private func togetherScreen<V: View>(_ view: V, title: LocalizedStringKey) -> some View {
    view
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
}

/// The frame of every "together" screen: a title, a line about what it is for, one clear action, then cards.
private struct TogetherPage<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    var action: (title: LocalizedStringKey, run: () -> Void)?
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).scaledFont(.title, weight: .heavy).foregroundStyle(Theme.textPrimary)
                    Text(subtitle).scaledFont(.body).foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let action {
                    Button(action: action.run) { Text(action.title) }
                        .buttonStyle(PrimaryButtonStyle())
                }
                content
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.vertical, 16)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }
}

/// Shown when a list is still empty: an icon and one inviting sentence.
private struct EmptyTogether: View {
    let symbol: String
    let text: LocalizedStringKey

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 72, height: 72)
                .background(Theme.cardRaised)
                .clipShape(Circle())
            Text(text)
                .scaledFont(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

/// Accept or decline, for any invitation, as two real buttons that show how it went.
private struct InvitationButtons: View {
    var acceptTitle: LocalizedStringKey = "PŘIDAT SE"
    let accept: () async throws -> Void
    let decline: () async throws -> Void

    var body: some View {
        HStack(spacing: 10) {
            ActionButton(title: "Ne, díky", look: .bigSecondary(SecondaryButtonStyle()), action: decline)
            ActionButton(title: acceptTitle, symbol: "hand.thumbsup.fill",
                         look: .big(PrimaryButtonStyle(color: Theme.green, textColor: Color(hex: 0x000000))), action: accept)
        }
    }
}

/// One person's progress as a bar with the numbers next to it.
private struct ProgressLine: View {
    let name: String
    let value: Int
    let target: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).scaledFont(.body, weight: .semibold).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(value) / \(target)").scaledFont(.caption, weight: .semibold).foregroundStyle(Theme.textSecondary).monospacedDigit()
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.cardRaised)
                    Capsule().fill(value >= target ? Theme.green : Theme.textPrimary)
                        .frame(width: proxy.size.width * min(1, Double(value) / Double(max(target, 1))))
                }
            }
            .frame(height: 8)
        }
    }
}

private struct CardTitle: View {
    let symbol: String
    let title: String
    let meta: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .scaledFont(.heading, weight: .semibold)
                .foregroundStyle(Theme.onPrimary)
                .frame(width: 44, height: 44)
                .background(Theme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).scaledFont(.heading, weight: .bold).foregroundStyle(Theme.textPrimary)
                Text(meta).scaledFont(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: Challenges

struct ChallengesView: View {
    private let together = TogetherService.shared
    @State private var creates = false

    var body: some View {
        TogetherPage(title: "Společné výzvy",
                     subtitle: "Třeba „30 tréninků za měsíc“. Počítají se splněné úkoly vybrané kategorie a každý vidí, jak jsou na tom ostatní.",
                     action: ("NOVÁ VÝZVA", { creates = true })) {
            if together.challenges.isEmpty {
                EmptyTogether(symbol: "flag.2.crossed", text: "Zatím žádná výzva. Vyzvi kamarády, kdo dá víc.")
            }
            ForEach(together.challenges) { challenge in
                VStack(alignment: .leading, spacing: 14) {
                    CardTitle(symbol: "flag.2.crossed", title: challenge.title,
                              meta: String(localized: "Cíl \(challenge.target) · do \(challenge.endsOn.formatted(.dateTime.day().month().locale(.app)))"))
                    ForEach(challenge.members.filter(\.isAccepted)) { member in
                        ProgressLine(name: member.isMe ? String(localized: "Ty") : member.name, value: member.progress ?? 0, target: challenge.target)
                    }
                    if challenge.isInvited {
                        InvitationButtons(accept: { try await together.respond(challenge, accept: true) },
                                          decline: { try await together.respond(challenge, accept: false) })
                    } else {
                        ActionButton(title: "Opustit výzvu", look: .bigSecondary(SecondaryButtonStyle(textColor: Theme.red))) {
                            try await together.leave(challenge)
                        }
                    }
                }
                .card()
            }
        }
        .refreshable { await together.reload() }
        .task { await together.reload() }
        .sheet(isPresented: $creates) { CreateChallengeView() }
    }
}

// MARK: Groups

struct GroupsView: View {
    private let together = TogetherService.shared
    @State private var creates = false

    var body: some View {
        TogetherPage(title: "Skupiny",
                     subtitle: "Rodina, tým, parta z gymu. Každá skupina má svůj žebříček spolehlivosti tohoto týdne.",
                     action: ("NOVÁ SKUPINA", { creates = true })) {
            if together.groups.isEmpty {
                EmptyTogether(symbol: "person.3", text: "Zatím žádná skupina. Založ ji pro rodinu nebo partu.")
            }
            ForEach(together.groups) { group in
                VStack(alignment: .leading, spacing: 12) {
                    CardTitle(symbol: "person.3.fill", title: group.name,
                              meta: String(localized: "Členů: \(group.members.filter(\.isAccepted).count)"))
                    ForEach(Array(group.members.enumerated()), id: \.element.id) { index, member in
                        HStack(spacing: 10) {
                            Text(member.isAccepted ? "\(index + 1)." : "·")
                                .scaledFont(.body, weight: .bold)
                                .foregroundStyle(index == 0 && member.isAccepted ? Theme.orange : Theme.textSecondary)
                                .frame(width: 26, alignment: .leading)
                            Text(member.isMe ? String(localized: "Ty") : member.name)
                                .scaledFont(.body, weight: member.isMe ? .bold : .regular)
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(member.isAccepted ? (member.reliability.map { "\($0) %" } ?? "—") : String(localized: "pozvánka"))
                                .scaledFont(.body, weight: .semibold)
                                .foregroundStyle(Theme.textSecondary)
                                .monospacedDigit()
                        }
                    }
                    if group.isInvited {
                        InvitationButtons(accept: { try await together.respond(group, accept: true) },
                                          decline: { try await together.respond(group, accept: false) })
                    } else {
                        ActionButton(title: group.isOwner ? "Zrušit skupinu" : "Opustit skupinu",
                                     look: .bigSecondary(SecondaryButtonStyle(textColor: Theme.red))) {
                            try await together.leave(group)
                        }
                    }
                }
                .card()
            }
        }
        .refreshable { await together.reload() }
        .task { await together.reload() }
        .sheet(isPresented: $creates) { CreateGroupView() }
    }
}

// MARK: Shared activities

struct ActivitiesView: View {
    @Environment(\.modelContext) private var context
    private let together = TogetherService.shared
    @State private var creates = false

    var body: some View {
        TogetherPage(title: "Společné aktivity",
                     subtitle: "Třeba „běh v sobotu v 9“. Kdo pozvánku přijme, tomu se aktivita přidá do plánu.",
                     action: ("NAPLÁNOVAT S PŘÁTELI", { creates = true })) {
            if together.activities.isEmpty {
                EmptyTogether(symbol: "calendar.badge.plus", text: "Nic naplánovaného. Domluv si s někým trénink nebo procházku.")
            }
            ForEach(together.activities) { activity in
                VStack(alignment: .leading, spacing: 12) {
                    CardTitle(symbol: (TaskCategory(rawValue: activity.category) ?? .other).icon, title: activity.title,
                              meta: activity.startsAt.formatted(.dateTime.weekday(.wide).day().month().hour().minute().locale(.app)))
                    HStack(spacing: 8) {
                        Label("\(activity.minutes) min", systemImage: "clock")
                        Label("\(activity.members.filter(\.isAccepted).count)", systemImage: "person.2")
                    }
                    .scaledFont(.caption, weight: .semibold)
                    .foregroundStyle(Theme.textSecondary)
                    Text(activity.members.filter(\.isAccepted).map { $0.isMe ? String(localized: "ty") : $0.name }.joined(separator: ", "))
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    if activity.isInvited {
                        InvitationButtons(accept: { try await together.respond(activity, accept: true, context: context) },
                                          decline: { try await together.respond(activity, accept: false, context: context) })
                    } else if activity.myStatus == "accepted" {
                        Label("V tvém plánu", systemImage: "checkmark.circle.fill")
                            .scaledFont(.caption, weight: .semibold)
                            .foregroundStyle(Theme.green)
                    }
                }
                .card()
            }
        }
        .refreshable { await together.reload() }
        .task { await together.reload() }
        .sheet(isPresented: $creates) { CreateActivityView() }
    }
}

// MARK: Buddy

struct BuddyView: View {
    private let together = TogetherService.shared
    private let friends = FriendsService.shared
    @State private var errorText: LocalizedStringKey?

    var body: some View {
        let paired = together.buddies.filter { $0.state == .paired }
        let incoming = together.buddies.filter { $0.state == .incoming }
        let taken = Set(together.buddies.map(\.id))
        TogetherPage(title: "Parťáci",
                     subtitle: "Přátelé, kteří denně uvidí, kolik slibů máš splněno, a ty jejich. Můžeš jich mít až \(TogetherService.maxBuddies).") {
            ForEach(incoming) { request in
                VStack(alignment: .leading, spacing: 14) {
                    CardTitle(symbol: "figure.2", title: request.name, meta: String(localized: "chce být tvůj parťák"))
                    InvitationButtons(acceptTitle: "BERU", accept: { try await respond(request, accept: true) },
                                      decline: { try await respond(request, accept: false) })
                }
                .card()
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
            if !paired.isEmpty {
                Text("TVOJI PARŤÁCI · \(paired.count)").labelStyle()
            }
            ForEach(paired) { buddy in
                BuddyCard(buddy: buddy) { try await end(buddy) }
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .scale(scale: 0.9).combined(with: .opacity)))
            }
            let candidates = friends.friends.filter { !paired.map(\.id).contains($0.id) && !incoming.map(\.id).contains($0.id) }
            if paired.count < TogetherService.maxBuddies {
                Text(paired.isEmpty ? "VYBER SI PARŤÁKA" : "PŘIDEJ DALŠÍHO").labelStyle()
                if friends.friends.isEmpty {
                    EmptyTogether(symbol: "person.badge.plus", text: "Nejdřív si přidej přátele.")
                } else if candidates.isEmpty {
                    EmptyTogether(symbol: "figure.2", text: "Všichni tvoji přátelé už jsou tvoji parťáci.")
                }
                ForEach(candidates) { friend in
                    let asked = together.buddies.contains { $0.id == friend.id && $0.state == .outgoing }
                    HStack(spacing: 12) {
                        Avatar(initial: String(friend.displayName.prefix(1)).uppercased())
                        Text(friend.displayName).scaledFont(.body, weight: .semibold).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        if asked {
                            Label("Čeká", systemImage: "hourglass")
                                .scaledFont(.caption, weight: .bold)
                                .foregroundStyle(Theme.textSecondary)
                                .symbolEffect(.pulse, options: .repeating)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 36)
                                .background(Theme.cardRaised, in: Capsule())
                        } else {
                            ActionButton(title: "Požádat", symbol: "hand.wave.fill", look: .pill(.primary)) {
                                try await ask(friend)
                            }
                        }
                    }
                    .card(padding: 12)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: asked)
                }
            } else {
                Text("Víc parťáků už mít nejde. Když budeš chtít nového, s někým parťáctví ukonči.")
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            if let errorText {
                Text(errorText).scaledFont(.caption).foregroundStyle(Theme.red)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: together.buddies)
        .refreshable { await together.reload() }
        .task { await together.reload() }
    }

    private func ask(_ friend: Friend) async throws {
        try await guarded { try await together.askBuddy(friend) }
    }

    private func respond(_ buddy: Buddy, accept: Bool) async throws {
        try await guarded { try await together.respondBuddy(buddy, accept: accept) }
    }

    private func end(_ buddy: Buddy) async throws {
        try await guarded { try await together.endBuddy(buddy) }
    }

    /// Shows what went wrong and passes the failure on, so the button shakes.
    private func guarded(_ work: () async throws -> Void) async throws {
        errorText = nil
        do { try await work() }
        catch let error as ServerError where error.code == "buddy_limit" {
            errorText = "Jeden z vás už má plný počet parťáků."
            throw error
        } catch let error as ServerError where error.code == "already_paired" {
            errorText = "Už jste parťáci."
            throw error
        } catch {
            errorText = "Nepovedlo se to. Zkus to prosím znovu."
            throw error
        }
    }
}

/// One buddy with how their day goes: a ring that fills as they keep their promises.
private struct BuddyCard: View {
    let buddy: Buddy
    let end: () async throws -> Void
    @State private var confirmsEnd = false

    var body: some View {
        let today = buddy.day.map { $0.isSameDay(as: .now) } ?? false
        let total = today ? max(buddy.total ?? 0, 0) : 0
        let done = today ? (buddy.done ?? 0) : 0
        HStack(spacing: 14) {
            ProgressRing(value: total == 0 ? 0 : Double(done) / Double(total), color: done >= total && total > 0 ? Theme.green : Theme.textPrimary,
                         lineWidth: 6) {
                Text(String(buddy.name.prefix(1)).uppercased())
                    .scaledFont(.heading, weight: .heavy)
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(width: 56, height: 56)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: done)
            VStack(alignment: .leading, spacing: 3) {
                Text(buddy.name).scaledFont(.heading, weight: .bold).foregroundStyle(Theme.textPrimary)
                Group {
                    if total > 0 {
                        Text(done >= total ? "Dnes má splněno všechno" : "Dnes \(done) z \(total)")
                    } else {
                        Text("Dnes zatím nic nepřišlo")
                    }
                }
                .scaledFont(.caption)
                .foregroundStyle(done >= total && total > 0 ? Theme.green : Theme.textSecondary)
                .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
            Menu {
                Button("Ukončit parťáctví", systemImage: "person.badge.minus", role: .destructive) { confirmsEnd = true }
            } label: {
                Image(systemName: "ellipsis")
                    .scaledFont(.body, weight: .bold)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Možnosti parťáka \(buddy.name)")
        }
        .card(padding: 14)
        .confirmationDialog("Ukončit parťáctví s \(buddy.name)?", isPresented: $confirmsEnd, titleVisibility: .visible) {
            Button("Ukončit", role: .destructive) { Task { try? await end(); Haptics.medium() } }
            Button("Nechat", role: .cancel) {}
        }
    }
}

// MARK: Witness

struct WitnessInboxView: View {
    private let together = TogetherService.shared

    var body: some View {
        TogetherPage(title: "Svědek",
                     subtitle: "Přátelé tě žádají, abys potvrdil, že úkol opravdu splnili. Potvrď jen to, o čem víš.") {
            if together.witnessing.toAnswer.isEmpty {
                EmptyTogether(symbol: "person.badge.shield.checkmark", text: "Nikdo tě teď nežádá o potvrzení.")
            }
            ForEach(together.witnessing.toAnswer) { request in
                VStack(alignment: .leading, spacing: 14) {
                    CardTitle(symbol: "checkmark.seal", title: request.title,
                              meta: String(localized: "\(request.ownerName) · \(request.day.longDayText)"))
                    HStack(spacing: 10) {
                        ActionButton(title: "Nepotvrzuji", look: .bigSecondary(SecondaryButtonStyle(textColor: Theme.red))) {
                            try await together.answer(request, confirm: false)
                        }
                        ActionButton(title: "POTVRZUJI", symbol: "checkmark.seal.fill",
                                     look: .big(PrimaryButtonStyle(color: Theme.green, textColor: Color(hex: 0x000000)))) {
                            try await together.answer(request, confirm: true)
                        }
                    }
                }
                .card()
            }
        }
        .refreshable { await together.reload() }
        .task { await together.reload() }
    }
}

struct CreateChallengeView: View {
    @Environment(\.dismiss) private var dismiss
    private let together = TogetherService.shared
    @State private var title = ""
    @State private var category: TaskCategory? = .gym
    @State private var target = 12
    @State private var days = 30
    @State private var invited: Set<UUID> = []
    @State private var errorText: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            togetherScreen(Form {
                Section {
                    TextField("Název, třeba „30 tréninků za měsíc“", text: $title)
                    Picker("Co se počítá", selection: $category) {
                        Text("Jakýkoli splněný úkol").tag(TaskCategory?.none)
                        ForEach(TaskCategory.allCases) { Text($0.title).tag(TaskCategory?.some($0)) }
                    }
                    Stepper("Cíl: \(target) splněných", value: $target, in: 1...500)
                    Picker("Délka", selection: $days) {
                        Text("1 týden").tag(7); Text("2 týdny").tag(14); Text("1 měsíc").tag(30); Text("3 měsíce").tag(90)
                    }
                }
                .listRowBackground(Theme.card)
                Section { FriendPicker(selection: $invited, limit: 19) } header: { Text("Koho pozveš") } footer: {
                    if let errorText { Text(errorText).foregroundStyle(Theme.red) }
                }
                .listRowBackground(Theme.card)
                Section {
                    Button("ZAČÍT VÝZVU") { create() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || invited.isEmpty)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }, title: "Nová výzva")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Zrušit") { dismiss() } } }
        }
        .appAppearance()
    }

    private func create() {
        Task {
            do {
                try await together.createChallenge(title: title, category: category, target: target, days: days, invitees: Array(invited))
                Haptics.success(); dismiss()
            } catch { errorText = "Výzvu se nepodařilo založit." }
        }
    }
}

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    private let together = TogetherService.shared
    @State private var name = ""
    @State private var invited: Set<UUID> = []
    @State private var errorText: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            togetherScreen(Form {
                Section { TextField("Název, třeba „Rodina“", text: $name) }.listRowBackground(Theme.card)
                Section { FriendPicker(selection: $invited, limit: 29) } header: { Text("Koho pozveš") } footer: {
                    if let errorText { Text(errorText).foregroundStyle(Theme.red) }
                }
                .listRowBackground(Theme.card)
                Section {
                    Button("ZALOŽIT SKUPINU") { create() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || invited.isEmpty)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }, title: "Nová skupina")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Zrušit") { dismiss() } } }
        }
        .appAppearance()
    }

    private func create() {
        Task {
            do { try await together.createGroup(name: name, invitees: Array(invited)); Haptics.success(); dismiss() }
            catch { errorText = "Skupinu se nepodařilo založit." }
        }
    }
}

struct CreateActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    private let together = TogetherService.shared
    @State private var title = ""
    @State private var category: TaskCategory = .sport
    @State private var startsAt = Calendar.app.date(byAdding: .day, value: 1, to: Date.now.startOfDay.addingTimeInterval(18 * 3600)) ?? .now
    @State private var minutes = 60
    @State private var invited: Set<UUID> = []
    @State private var errorText: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            togetherScreen(Form {
                Section {
                    TextField("Co, třeba „Běh kolem přehrady“", text: $title)
                    Picker("Kategorie", selection: $category) {
                        ForEach(TaskCategory.allCases) { Text($0.title).tag($0) }
                    }
                    DatePicker("Kdy", selection: $startsAt, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                    Stepper("Délka: \(minutes) min", value: $minutes, in: 15...480, step: 15)
                }
                .listRowBackground(Theme.card)
                Section { FriendPicker(selection: $invited, limit: 19) } header: { Text("Koho pozveš") } footer: {
                    if let errorText { Text(errorText).foregroundStyle(Theme.red) }
                }
                .listRowBackground(Theme.card)
                Section {
                    Button("POSLAT POZVÁNKY") { create() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || invited.isEmpty)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }, title: "Společná aktivita")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Zrušit") { dismiss() } } }
        }
        .appAppearance()
    }

    private func create() {
        Task {
            do {
                try await together.createActivity(title: title, category: category, startsAt: startsAt, minutes: minutes,
                                                  invitees: Array(invited), context: context)
                Haptics.success(); dismiss()
            } catch { errorText = "Aktivitu se nepodařilo založit." }
        }
    }
}

/// On a finished task: ask a friend to confirm it, and show the answer.
struct WitnessRow: View {
    let task: TaskItem
    private let together = TogetherService.shared
    private let friends = FriendsService.shared
    @State private var picks = false

    var body: some View {
        if AccountService.shared.profile != nil, task.isDone {
            if let result = together.witnessResult(for: task) {
                Label(result.status == "confirmed" ? "Potvrzeno: \(result.witnessName)"
                      : result.status == "rejected" ? "Nepotvrzeno: \(result.witnessName)" : "Čeká na potvrzení: \(result.witnessName)",
                      systemImage: result.status == "confirmed" ? "checkmark.seal.fill" : "hourglass")
                    .foregroundStyle(result.status == "confirmed" ? Theme.green : Theme.textSecondary)
            } else {
                Button { picks = true } label: { Label("Požádat přítele o potvrzení", systemImage: "person.badge.shield.checkmark") }
                    .confirmationDialog("Kdo to potvrdí?", isPresented: $picks, titleVisibility: .visible) {
                        ForEach(friends.friends) { friend in
                            Button(friend.displayName) { Task { try? await together.requestWitness(friend, for: task) } }
                        }
                    }
            }
        }
    }
}
