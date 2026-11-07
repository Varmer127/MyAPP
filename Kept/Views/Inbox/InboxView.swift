import SwiftData
import SwiftUI

/// What is waiting for the user's attention: friend requests, new pokes and the week and month stories
/// that have not been opened yet. The same bell sits on every tab, always top right.
@MainActor
struct InboxItems {
    var requests: Int
    var pokes: Int
    var news: Int
    var bets: Int
    var challenges: Int
    var groups: Int
    var activities: Int
    var buddy: Int
    var witness: Int
    var week: WeekStory?
    var month: MonthStory?
    var yesterday: DayRecap?

    var count: Int { requests + pokes + news + bets + challenges + groups + activities + buddy + witness + (week == nil ? 0 : 1) + (month == nil ? 0 : 1) + (yesterday == nil ? 0 : 1) }

    init(tasks: [TaskItem], diary: [DiaryEntry], seenWeek: Double, seenMonth: Double, seenDay: Double, now: Date = .now) {
        let friends = FriendsService.shared
        requests = friends.incoming.count
        pokes = friends.unreadPokes
        news = NotificationsService.shared.unseenNews
        bets = BetsService.shared.waiting.count
        let together = TogetherService.shared
        challenges = together.challenges.filter(\.isInvited).count
        groups = together.groups.filter(\.isInvited).count
        activities = together.activities.filter(\.isInvited).count
        buddy = together.incomingBuddy == nil ? 0 : 1
        witness = together.witnessing.toAnswer.count
        if let start = WeekStory.offeredWeek(now: now), seenWeek != start.timeIntervalSince1970 {
            week = WeekStory.make(tasks: tasks, diary: diary, weekStart: start, now: now)
        }
        if let start = MonthStory.offeredMonth(now: now), seenMonth != start.timeIntervalSince1970 {
            month = MonthStory.make(tasks: tasks, monthStart: start, now: now)
        }
        if let recap = DayRecap.make(tasks: tasks, now: now), seenDay != recap.day.timeIntervalSince1970 {
            yesterday = recap
        }
    }
}

struct NotificationBell: View {
    /// Drawn in a round button, as it sits next to the title of each tab.
    var circled = true
    @Query private var tasks: [TaskItem]
    @Query private var diary: [DiaryEntry]
    @AppStorage("storySeenWeek") private var seenWeek = 0.0
    @AppStorage("storySeenMonth") private var seenMonth = 0.0
    @AppStorage("daySummarySeen") private var seenDay = 0.0
    @State private var isOpen = false

    var body: some View {
        let count = InboxItems(tasks: tasks, diary: diary, seenWeek: seenWeek, seenMonth: seenMonth, seenDay: seenDay).count
        Button { isOpen = true } label: {
            Image(systemName: count > 0 ? "bell.fill" : "bell")
                .scaledFont(.heading, weight: .semibold)
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 44, height: 44)
                .background {
                    if circled {
                        Circle().fill(Theme.card).overlay(Circle().stroke(Theme.border, lineWidth: 1))
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if count > 0 {
                        Text(count > 9 ? "9+" : "\(count)")
                            .scaledFont(.caption, weight: .bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Theme.red)
                            .clipShape(Capsule())
                            .offset(x: 2, y: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(count > 0 ? "Upozornění, nových: \(count)" : "Upozornění")
        .sheet(isPresented: $isOpen) { InboxView() }
        .task {
            guard AccountService.shared.isSignedIn else { return }
            await FriendsService.shared.reload()
            await BetsService.shared.reload()
            await TogetherService.shared.reload()
        }
    }
}

struct InboxView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var tasks: [TaskItem]
    @Query private var diary: [DiaryEntry]
    @AppStorage("storySeenWeek") private var seenWeek = 0.0
    @AppStorage("storySeenMonth") private var seenMonth = 0.0
    @AppStorage("daySummarySeen") private var seenDay = 0.0
    @State private var weekStory: WeekStory?
    @State private var monthStory: MonthStory?
    @State private var dayRecap: DayRecap?
    private let friends = FriendsService.shared

    var body: some View {
        let items = InboxItems(tasks: tasks, diary: diary, seenWeek: seenWeek, seenMonth: seenMonth, seenDay: seenDay)
        NavigationStack {
            List {
                if items.count == 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Všechno máš přečtené.")
                            .scaledFont(.body, weight: .semibold)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Sem přijde shrnutí včerejšího dne, přehledy týdne a měsíce, žádosti o přátelství a pošťouchnutí.")
                            .scaledFont(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Theme.card)
                }
                if let recap = items.yesterday {
                    row("sunrise", "Jak dopadl včerejšek", "Dodrženo \(recap.done) z \(recap.total). Shrnutí včerejšího dne.") {
                        dayRecap = recap
                    }
                }
                if let week = items.week {
                    row("sparkles", "Tvůj týden je hotový", "\(week.done) z \(week.total) slibů. Podívej se, jak to dopadlo.") {
                        weekStory = week
                    }
                }
                if let month = items.month {
                    row("calendar.badge.checkmark", "Tvůj měsíc je hotový", "\(month.done) z \(month.total) slibů. Podívej se, jak to dopadlo.") {
                        monthStory = month
                    }
                }
                if items.requests > 0 {
                    NavigationLink { FriendsView() } label: {
                        rowLabel("person.badge.plus", "Žádosti o přátelství", "Čeká na tebe: \(items.requests)")
                    }
                    .listRowBackground(Theme.card)
                }
                if items.bets > 0 {
                    link("trophy", "Sázky čekají na tebe", "Pozvánky a výsledky k potvrzení: \(items.bets)") { BetsView() }
                }
                if items.challenges > 0 {
                    link("flag.2.crossed", "Pozvánka do výzvy", "Čeká na odpověď: \(items.challenges)") { ChallengesView() }
                }
                if items.groups > 0 {
                    link("person.3", "Pozvánka do skupiny", "Čeká na odpověď: \(items.groups)") { GroupsView() }
                }
                if items.activities > 0 {
                    link("calendar.badge.plus", "Pozvánka na společnou aktivitu", "Čeká na odpověď: \(items.activities)") { ActivitiesView() }
                }
                if items.buddy > 0 {
                    link("figure.2", "Někdo chce být tvůj parťák", TogetherService.shared.incomingBuddy?.name ?? "") { BuddyView() }
                }
                if items.witness > 0 {
                    link("person.badge.shield.checkmark", "Žádost o potvrzení", "Čeká na tebe: \(items.witness)") { WitnessInboxView() }
                }
                if items.pokes > 0 {
                    NavigationLink { FriendsView() } label: {
                        rowLabel("hand.point.right", "Pošťouchnutí", latestPokes)
                    }
                    .listRowBackground(Theme.card)
                }
                if !NotificationsService.shared.news.isEmpty {
                    Section("Novinky") {
                        ForEach(NotificationsService.shared.news.prefix(20)) { note in
                            HStack(alignment: .top, spacing: 10) {
                                Circle().fill(note.seen ? Color.clear : Theme.orange).frame(width: 8, height: 8).padding(.top, 7)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(note.title).scaledFont(.body, weight: note.seen ? .regular : .semibold).foregroundStyle(Theme.textPrimary)
                                    if let detail = note.detail {
                                        Text(detail).scaledFont(.caption).foregroundStyle(Theme.textSecondary)
                                    }
                                    Text(note.createdAt.formatted(.relative(presentation: .named).locale(.app)))
                                        .scaledFont(.caption).foregroundStyle(Theme.textTertiary)
                                }
                            }
                        }
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Upozornění")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Zavřít") { dismiss() } } }
            .refreshable {
                await friends.reload()
                await NotificationsService.shared.reload()
            }
            .task {
                await NotificationsService.shared.reload()
                // The news counts as read once the list has been on screen for a moment.
                try? await Task.sleep(for: .seconds(2))
                await NotificationsService.shared.markSeen()
            }
        }
        .appAppearance()
        .fullScreenCover(item: Binding(get: { weekStory.map { InboxWeekBox(story: $0) } }, set: { if $0 == nil { weekStory = nil } })) { box in
            WeekStoryView(story: box.story) {
                seenWeek = box.story.weekStart.timeIntervalSince1970
                weekStory = nil
            }
            .appAppearance()
        }
        .sheet(item: $dayRecap) { recap in
            DayRecapView(recap: recap, streak: ScoreEngine.dayStreak(tasks)) {
                seenDay = recap.day.timeIntervalSince1970
                dayRecap = nil
            }
        }
        .fullScreenCover(item: $monthStory) { month in
            MonthStoryView(story: month) {
                seenMonth = month.monthStart.timeIntervalSince1970
                monthStory = nil
            }
            .appAppearance()
        }
    }

    /// Who cheered, in one line.
    private var cheers: String {
        let names = Array(Set(friends.unreadReactions.map(\.senderName))).sorted()
        return names.prefix(3).joined(separator: ", ")
    }

    /// The newest unread pokes in one line: who and what.
    private var latestPokes: String {
        friends.pokes.filter { !$0.seen }.prefix(2).map { "\($0.senderName): \($0.body)" }.joined(separator: " · ")
    }

    private func link<Destination: View>(_ symbol: String, _ title: LocalizedStringKey, _ subtitle: String,
                                         @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink(destination: destination) { rowLabel(symbol, title, subtitle) }
            .listRowBackground(Theme.card)
    }

    private func row(_ symbol: String, _ title: LocalizedStringKey, _ subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { rowLabel(symbol, title, subtitle) }
            .buttonStyle(.plain)
            .listRowBackground(Theme.card)
    }

    private func rowLabel(_ symbol: String, _ title: LocalizedStringKey, _ subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .scaledFont(.body, weight: .semibold)
                .foregroundStyle(Theme.onPrimary)
                .frame(width: 38, height: 38)
                .background(Theme.textPrimary)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).scaledFont(.body, weight: .semibold).foregroundStyle(Theme.textPrimary)
                Text(subtitle).scaledFont(.caption).foregroundStyle(Theme.textSecondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct InboxWeekBox: Identifiable {
    let story: WeekStory
    var id: Date { story.weekStart }
}
