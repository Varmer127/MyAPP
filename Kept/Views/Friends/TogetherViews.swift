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

/// Accept or decline, for any invitation, as two real buttons.
private struct InvitationButtons: View {
    let accept: () -> Void
    let decline: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button("Ne, díky", action: decline).buttonStyle(SecondaryButtonStyle())
            Button("PŘIDAT SE", action: accept).buttonStyle(PrimaryButtonStyle(color: Theme.green, textColor: Color(hex: 0x000000)))
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

private func act(_ work: @escaping () async throws -> Void) {
    Task {
        do { try await work(); Haptics.success() } catch { Haptics.warning() }
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
                        InvitationButtons(accept: { act { try await together.respond(challenge, accept: true) } },
                                          decline: { act { try await together.respond(challenge, accept: false) } })
                    } else {
                        Button("Opustit výzvu") { act { try await together.leave(challenge) } }
                            .buttonStyle(SecondaryButtonStyle(textColor: Theme.red))
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
                            Text(member.isAccepted ? (member.reliability.map { "\($0) %" } ?? "—") : String(localized: "pozván(a)"))
                                .scaledFont(.body, weight: .semibold)
                                .foregroundStyle(Theme.textSecondary)
                                .monospacedDigit()
                        }
                    }
                    if group.isInvited {
                        InvitationButtons(accept: { act { try await together.respond(group, accept: true) } },
                                          decline: { act { try await together.respond(group, accept: false) } })
                    } else {
                        Button(group.isOwner ? "Zrušit skupinu" : "Opustit skupinu") { act { try await together.leave(group) } }
                            .buttonStyle(SecondaryButtonStyle(textColor: Theme.red))
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
                        InvitationButtons(accept: { act { try await together.respond(activity, accept: true, context: context) } },
                                          decline: { act { try await together.respond(activity, accept: false, context: context) } })
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
        TogetherPage(title: "Parťák",
                     subtitle: "Jeden přítel, který denně uvidí, kolik slibů máš splněno, a ty jeho. Nic víc.") {
            if let buddy = together.buddy {
                VStack(alignment: .leading, spacing: 14) {
                    CardTitle(symbol: "figure.2", title: buddy.name, meta: String(localized: "Tvůj parťák"))
                    if let total = buddy.total, let day = buddy.day, day.isSameDay(as: .now) {
                        ProgressLine(name: String(localized: "Dnes"), value: buddy.done ?? 0, target: max(total, 1))
                    } else {
                        Text("Dnes zatím nic nepřišlo.").scaledFont(.body).foregroundStyle(Theme.textSecondary)
                    }
                    Button("Ukončit parťáctví") { run { try await together.endBuddy() } }
                        .buttonStyle(SecondaryButtonStyle(textColor: Theme.red))
                }
                .card()
            } else {
                if let incoming = together.incomingBuddy {
                    VStack(alignment: .leading, spacing: 14) {
                        CardTitle(symbol: "figure.2", title: incoming.name, meta: String(localized: "chce být tvůj parťák"))
                        InvitationButtons(accept: { run { try await together.respondBuddy(incoming, accept: true) } },
                                          decline: { run { try await together.respondBuddy(incoming, accept: false) } })
                    }
                    .card()
                }
                Text("VYBER SI PARŤÁKA").labelStyle()
                if friends.friends.isEmpty {
                    EmptyTogether(symbol: "person.badge.plus", text: "Nejdřív si přidej přátele.")
                }
                ForEach(friends.friends) { friend in
                    let asked = together.buddies.contains { $0.id == friend.id && $0.state == .outgoing }
                    HStack(spacing: 12) {
                        Avatar(initial: String(friend.displayName.prefix(1)).uppercased())
                        Text(friend.displayName).scaledFont(.body, weight: .semibold).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Button(asked ? "Čeká" : "Požádat") { run { try await together.askBuddy(friend) } }
                            .buttonStyle(.borderedProminent)
                            .tint(asked ? Theme.cardRaised : Theme.textPrimary)
                            .foregroundStyle(asked ? Theme.textSecondary : Theme.onPrimary)
                            .disabled(asked)
                    }
                    .card(padding: 12)
                }
            }
            if let errorText {
                Text(errorText).scaledFont(.caption).foregroundStyle(Theme.red)
            }
        }
        .refreshable { await together.reload() }
        .task { await together.reload() }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        errorText = nil
        Task {
            do { try await work(); Haptics.success() }
            catch let error as ServerError where error.code == "already_paired" { errorText = "Jeden z vás už parťáka má." }
            catch { errorText = "Nepovedlo se to. Zkus to prosím znovu." }
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
                        Button("Nepotvrzuji") { act { try await together.answer(request, confirm: false) } }
                            .buttonStyle(SecondaryButtonStyle(textColor: Theme.red))
                        Button("POTVRZUJI") { act { try await together.answer(request, confirm: true) } }
                            .buttonStyle(PrimaryButtonStyle(color: Theme.green, textColor: Color(hex: 0x000000)))
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
                Label(result.status == "confirmed" ? "Potvrdil(a) \(result.witnessName)"
                      : result.status == "rejected" ? "\(result.witnessName) nepotvrdil(a)" : "Čeká na potvrzení: \(result.witnessName)",
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
