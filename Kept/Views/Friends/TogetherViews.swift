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

/// Accept or decline, for any invitation.
private struct InvitationButtons: View {
    let accept: () -> Void
    let decline: () -> Void

    var body: some View {
        HStack {
            Button("Přidat se", action: accept).buttonStyle(.borderedProminent).tint(Theme.textPrimary).foregroundStyle(Theme.onPrimary)
            Button("Ne", action: decline).buttonStyle(.bordered).tint(Theme.textSecondary)
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

// MARK: Challenges

struct ChallengesView: View {
    private let together = TogetherService.shared
    @State private var creates = false

    var body: some View {
        togetherScreen(List {
            Section {
                Button { creates = true } label: { Label("Nová společná výzva", systemImage: "plus.circle") }
            } footer: {
                Text("Třeba „30 tréninků za měsíc“. Do výzvy se počítají splněné úkoly vybrané kategorie a každý vidí, jak jsou na tom ostatní.")
            }
            .listRowBackground(Theme.card)
            ForEach(together.challenges) { challenge in
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(challenge.title).scaledFont(.body, weight: .bold).foregroundStyle(Theme.textPrimary)
                        Text("Cíl \(challenge.target) · do \(challenge.endsOn.formatted(.dateTime.day().month().locale(.app)))")
                            .scaledFont(.caption).foregroundStyle(Theme.textSecondary)
                    }
                    ForEach(challenge.members.filter(\.isAccepted)) { member in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(member.isMe ? "Ty" : member.name).foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text("\(member.progress ?? 0) / \(challenge.target)").monospacedDigit().foregroundStyle(Theme.textSecondary)
                            }
                            ProgressView(value: min(Double(member.progress ?? 0), Double(challenge.target)), total: Double(challenge.target))
                                .tint((member.progress ?? 0) >= challenge.target ? Theme.green : Theme.textPrimary)
                        }
                    }
                    if challenge.isInvited {
                        InvitationButtons(accept: { act { try await together.respond(challenge, accept: true) } },
                                          decline: { act { try await together.respond(challenge, accept: false) } })
                    } else {
                        Button("Opustit výzvu", role: .destructive) { act { try await together.leave(challenge) } }
                            .foregroundStyle(Theme.red)
                    }
                }
                .listRowBackground(Theme.card)
            }
        }, title: "Společné výzvy")
        .refreshable { await together.reload() }
        .task { await together.reload() }
        .sheet(isPresented: $creates) { CreateChallengeView() }
    }

    private func act(_ work: @escaping () async throws -> Void) { Task { try? await work() } }
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
                    Button("Začít výzvu") { create() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || invited.isEmpty)
                }
                .listRowBackground(Theme.card)
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

// MARK: Groups

struct GroupsView: View {
    private let together = TogetherService.shared
    @State private var creates = false

    var body: some View {
        togetherScreen(List {
            Section {
                Button { creates = true } label: { Label("Nová skupina", systemImage: "plus.circle") }
            } footer: {
                Text("Rodina, tým, parta z gymu. Skupina má vlastní žebříček spolehlivosti tohoto týdne.")
            }
            .listRowBackground(Theme.card)
            ForEach(together.groups) { group in
                Section {
                    ForEach(Array(group.members.enumerated()), id: \.element.id) { index, member in
                        HStack {
                            Text(member.isAccepted ? "\(index + 1)." : "·").foregroundStyle(Theme.textSecondary).frame(width: 26, alignment: .leading)
                            Text(member.isMe ? "Ty" : member.name).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(member.isAccepted ? (member.reliability.map { "\($0) %" } ?? "—") : "pozván")
                                .foregroundStyle(Theme.textSecondary).monospacedDigit()
                        }
                    }
                    if group.isInvited {
                        InvitationButtons(accept: { act { try await together.respond(group, accept: true) } },
                                          decline: { act { try await together.respond(group, accept: false) } })
                    } else {
                        Button(group.isOwner ? "Zrušit skupinu" : "Opustit skupinu", role: .destructive) {
                            act { try await together.leave(group) }
                        }
                        .foregroundStyle(Theme.red)
                    }
                } header: {
                    Text(group.name)
                }
                .listRowBackground(Theme.card)
            }
        }, title: "Skupiny")
        .refreshable { await together.reload() }
        .task { await together.reload() }
        .sheet(isPresented: $creates) { CreateGroupView() }
    }

    private func act(_ work: @escaping () async throws -> Void) { Task { try? await work() } }
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
                    Button("Založit skupinu") { create() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || invited.isEmpty)
                }
                .listRowBackground(Theme.card)
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

// MARK: Shared activities

struct ActivitiesView: View {
    @Environment(\.modelContext) private var context
    private let together = TogetherService.shared
    @State private var creates = false

    var body: some View {
        togetherScreen(List {
            Section {
                Button { creates = true } label: { Label("Naplánovat s přáteli", systemImage: "calendar.badge.plus") }
            } footer: {
                Text("Třeba „běh v sobotu v 9“. Komu pozvánku pošleš a kdo ji přijme, tomu se aktivita přidá do jeho plánu.")
            }
            .listRowBackground(Theme.card)
            ForEach(together.activities) { activity in
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(activity.title).scaledFont(.body, weight: .bold).foregroundStyle(Theme.textPrimary)
                        Text("\(activity.startsAt.formatted(.dateTime.weekday(.wide).day().month().hour().minute().locale(.app))) · \(activity.minutes) min")
                            .scaledFont(.caption).foregroundStyle(Theme.textSecondary)
                        Text(activity.members.filter(\.isAccepted).map { $0.isMe ? String(localized: "ty") : $0.name }.joined(separator: ", "))
                            .scaledFont(.caption).foregroundStyle(Theme.textSecondary)
                    }
                    if activity.isInvited {
                        InvitationButtons(accept: { act { try await together.respond(activity, accept: true, context: context) } },
                                          decline: { act { try await together.respond(activity, accept: false, context: context) } })
                    }
                }
                .listRowBackground(Theme.card)
            }
        }, title: "Společné aktivity")
        .refreshable { await together.reload() }
        .task { await together.reload() }
        .sheet(isPresented: $creates) { CreateActivityView() }
    }

    private func act(_ work: @escaping () async throws -> Void) { Task { try? await work() } }
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
                    Button("Poslat pozvánky") { create() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || invited.isEmpty)
                }
                .listRowBackground(Theme.card)
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

// MARK: Buddy

struct BuddyView: View {
    private let together = TogetherService.shared
    private let friends = FriendsService.shared
    @State private var errorText: LocalizedStringKey?

    var body: some View {
        togetherScreen(Form {
            if let buddy = together.buddy {
                Section {
                    Text(buddy.name).scaledFont(.heading, weight: .bold).foregroundStyle(Theme.textPrimary)
                    if let total = buddy.total, let day = buddy.day, day.isSameDay(as: .now) {
                        LabeledContent("Dnes", value: "\(buddy.done ?? 0) z \(total) slibů")
                        ProgressView(value: Double(buddy.done ?? 0), total: Double(max(total, 1))).tint(Theme.green)
                    } else {
                        Text("Dnes zatím nic nepřišlo.").foregroundStyle(Theme.textSecondary)
                    }
                    Button("Ukončit parťáctví", role: .destructive) { act { try await together.endBuddy() } }
                        .foregroundStyle(Theme.red)
                } footer: {
                    Text("Parťák vidí, kolik slibů máš dnes splněno, a ty vidíš jeho. Nic víc.")
                }
                .listRowBackground(Theme.card)
            } else {
                if let incoming = together.incomingBuddy {
                    Section("Chce být tvůj parťák") {
                        Text(incoming.name).foregroundStyle(Theme.textPrimary)
                        InvitationButtons(accept: { act { try await together.respondBuddy(incoming, accept: true) } },
                                          decline: { act { try await together.respondBuddy(incoming, accept: false) } })
                    }
                    .listRowBackground(Theme.card)
                }
                Section {
                    ForEach(friends.friends) { friend in
                        let asked = together.buddies.contains { $0.id == friend.id && $0.state == .outgoing }
                        Button(asked ? "\(friend.displayName) · čeká na odpověď" : friend.displayName) {
                            act { try await together.askBuddy(friend) }
                        }
                        .disabled(asked)
                    }
                } header: {
                    Text("Vyber si parťáka")
                } footer: {
                    Text(errorText ?? "Jeden přítel, který denně uvidí, jak ti jde plnění slibů, a ty jeho. Parťáka máš jen jednoho.")
                }
                .listRowBackground(Theme.card)
            }
        }, title: "Parťák")
        .refreshable { await together.reload() }
        .task { await together.reload() }
    }

    private func act(_ work: @escaping () async throws -> Void) {
        errorText = nil
        Task {
            do { try await work() }
            catch let error as ServerError where error.code == "already_paired" { errorText = "Jeden z vás už parťáka má." }
            catch { errorText = "Nepovedlo se to. Zkus to prosím znovu." }
        }
    }
}

// MARK: Witness

struct WitnessInboxView: View {
    private let together = TogetherService.shared

    var body: some View {
        togetherScreen(List {
            if together.witnessing.toAnswer.isEmpty {
                Text("Nikdo tě teď nežádá o potvrzení.").foregroundStyle(Theme.textSecondary).listRowBackground(Theme.card)
            }
            ForEach(together.witnessing.toAnswer) { request in
                Section {
                    Text("\(request.ownerName): \(request.title)").scaledFont(.body, weight: .semibold).foregroundStyle(Theme.textPrimary)
                    Text(request.day.longDayText).scaledFont(.caption).foregroundStyle(Theme.textSecondary)
                    HStack {
                        Button("Potvrzuji") { act { try await together.answer(request, confirm: true) } }
                            .buttonStyle(.borderedProminent).tint(Theme.green)
                        Button("Nepotvrzuji") { act { try await together.answer(request, confirm: false) } }
                            .buttonStyle(.bordered).tint(Theme.red)
                    }
                } footer: {
                    Text("Potvrď jen to, o čem víš, že se opravdu stalo.")
                }
                .listRowBackground(Theme.card)
            }
        }, title: "Svědek")
        .refreshable { await together.reload() }
        .task { await together.reload() }
    }

    private func act(_ work: @escaping () async throws -> Void) { Task { try? await work() } }
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
