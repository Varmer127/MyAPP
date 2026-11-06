import SwiftData
import SwiftUI

/// A friend's week inside their detail: what they share, a few cheers, and a way to take their plan over.
struct FriendWeekSection: View {
    let friend: Friend
    @Environment(\.modelContext) private var context
    private let friends = FriendsService.shared
    @State private var week: FriendWeek?
    @State private var failed = false
    @State private var confirmsCopy = false
    @State private var copied = 0

    var body: some View {
        Section {
            if let week {
                content(week)
            } else if failed {
                Text("Týden se nepodařilo načíst.").foregroundStyle(Theme.textSecondary)
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        } header: {
            Text("Tento týden")
        }
        .listRowBackground(Theme.card)
        .task { await load() }
        .alert("Zkopírovat plán do příštího týdne?", isPresented: $confirmsCopy) {
            Button("Zkopírovat") { copyPlan() }
            Button("Nechat", role: .cancel) {}
        } message: {
            Text("Do plánovače příštího týdne přibudou úkoly ze stejných dnů. Pak si je můžeš upravit, než plán zapečetíš.")
        }
    }

    @ViewBuilder
    private func content(_ week: FriendWeek) -> some View {
        switch week.level {
        case .none:
            Text("\(friend.displayName) svůj týden nesdílí.")
                .foregroundStyle(Theme.textSecondary)
        case .summary, .plan:
            if let total = week.total {
                HStack(spacing: 18) {
                    stat(week.reliability.map { "\($0) %" } ?? "—", "Spolehlivost")
                    stat("\(week.done ?? 0) z \(total)", "Splněno")
                    stat("\(week.streak ?? 0)", "Série")
                }
                if week.sealed == true {
                    Label("Týden zapečetěný", systemImage: "checkmark.seal.fill")
                        .scaledFont(.caption, weight: .semibold)
                        .foregroundStyle(Theme.textSecondary)
                }
            } else {
                Text("Tento týden zatím nic nepřišlo.").foregroundStyle(Theme.textSecondary)
            }
            if let tasks = week.tasks, !tasks.isEmpty {
                ForEach(tasks) { task in
                    HStack(spacing: 10) {
                        Image(systemName: task.isDone ? "checkmark.circle.fill" : (task.isMissed ? "xmark.circle.fill" : "circle"))
                            .foregroundStyle(task.isDone ? Theme.green : (task.isMissed ? Theme.red : Theme.textTertiary))
                        Text(task.title).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text(task.day.formatted(.dateTime.weekday(.abbreviated).locale(.app)).localizedCapitalized)
                            .scaledFont(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Button(copied > 0 ? "Zkopírováno: \(copied)" : "Zkopírovat plán do mého příštího týdne") { confirmsCopy = true }
                    .disabled(copied > 0)
            }
        }
        reactions(week)
    }

    private func stat(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).scaledFont(.heading, weight: .bold).foregroundStyle(Theme.textPrimary)
            Text(label).scaledFont(.caption).foregroundStyle(Theme.textSecondary)
        }
    }

    /// Four small cheers; each can be given once a week and taken back with a second tap.
    private func reactions(_ week: FriendWeek) -> some View {
        HStack(spacing: 10) {
            ForEach(ReactionKind.allCases) { kind in
                let isOn = week.myReactions.contains(kind)
                Button { toggle(kind) } label: {
                    Image(systemName: kind.symbol)
                        .scaledFont(.body, weight: .semibold)
                        .foregroundStyle(isOn ? Theme.onPrimary : Theme.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(isOn ? Theme.textPrimary : Theme.cardRaised)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: kind.title))
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        do { week = try await friends.week(of: friend) } catch { failed = true }
    }

    private func toggle(_ kind: ReactionKind) {
        Haptics.light()
        Task {
            if let on = try? await friends.toggle(kind, for: friend), var current = week {
                current.myReactions.removeAll { $0 == kind }
                if on { current.myReactions.append(kind) }
                week = current
            }
        }
    }

    /// The friend's tasks become drafts on the same weekdays of next week; days already past are left out.
    private func copyPlan() {
        guard let tasks = week?.tasks else { return }
        let settings = UserSettings.current(in: context)
        let today = Date.now.startOfDay
        var count = 0
        for task in tasks {
            let day = task.day.addingDays(7)
            guard day >= today else { continue }
            var draft = TaskDraft(date: day)
            draft.title = task.title
            draft.category = TaskCategory(rawValue: task.category) ?? .other
            draft.weight = settings.defaultWeight(category: draft.category, priority: draft.priority)
            _ = PlanService.save(draft, to: nil, in: context)
            count += 1
        }
        Persistence.save(context)
        copied = count
        Haptics.success()
    }
}

/// Friends' leaderboards for this week: reliability and badges.
struct LeaderboardSection: View {
    private let friends = FriendsService.shared
    @State private var kind = 0

    private var rows: [LeaderboardRow] {
        kind == 0
            ? friends.leaderboard.sorted { ($0.reliability ?? -1) > ($1.reliability ?? -1) }
            : friends.leaderboard.sorted { $0.badges > $1.badges }
    }

    var body: some View {
        Section {
            Picker("Žebříček", selection: $kind) {
                Text("Spolehlivost").tag(0)
                Text("Odznaky").tag(1)
            }
            .pickerStyle(.segmented)
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack(spacing: 12) {
                    Text("\(index + 1).")
                        .scaledFont(.body, weight: .bold)
                        .foregroundStyle(index == 0 ? Theme.orange : Theme.textSecondary)
                        .frame(width: 28, alignment: .leading)
                    Text(row.isMe ? "Ty" : row.displayName)
                        .scaledFont(.body, weight: row.isMe ? .bold : .regular)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(kind == 0 ? (row.reliability.map { "\($0) %" } ?? "—") : "\(row.badges)")
                        .scaledFont(.body, weight: .semibold)
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                }
            }
        } header: {
            Text("Žebříčky tohoto týdne")
        } footer: {
            Text("Spolehlivost je podíl dodržených slibů, ne jejich počet. Z žebříčků se můžeš odhlásit v Účtu.")
        }
        .listRowBackground(Theme.card)
    }
}
