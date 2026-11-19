import SwiftUI

/// The screens a "Pro tebe" tile opens in a sheet.
enum ForYouSheet: Identifiable {
    case recap(DayRecap)
    case friends, diary, gym, bets, challenges, stats

    var id: String {
        switch self {
        case .recap: "recap"
        case .friends: "friends"
        case .diary: "diary"
        case .gym: "gym"
        case .bets: "bets"
        case .challenges: "challenges"
        case .stats: "stats"
        }
    }

    @MainActor @ViewBuilder
    var destination: some View {
        switch self {
        case .recap: EmptyView()
        case .friends: FriendsView()
        case .diary: DiaryView(isEmbedded: true)
        case .gym: GymProgressView()
        case .bets: BetsView()
        case .challenges: ChallengesView()
        case .stats: StatsView(isEmbedded: true)
        }
    }
}

/// "Pro tebe": everything on Today that is good to see but not urgent, as one row of small tiles.
/// What is fresh comes first (stories, the reflection, yesterday), then what helps plan ahead,
/// then the places worth a visit (diary, points, gym, friends, bets, challenges, stats).
extension TodayView {
    /// From Thursday on, the coming week is worth planning while it is not handed in yet.
    private static let planAheadFromWeekday = 5

    @ViewBuilder
    func forYouRow(now: Date) -> some View {
        let week = WeekStory.offeredWeek(now: now).flatMap { start in
            storySeenWeek == start.timeIntervalSince1970 ? nil : WeekStory.make(tasks: tasks, diary: diaryEntries, weekStart: start, now: now)
        }
        let month = MonthStory.offeredMonth(now: now).flatMap { start in
            storySeenMonth == start.timeIntervalSince1970 ? nil : MonthStory.make(tasks: tasks, monthStart: start, now: now)
        }
        let pending = ReflectionRequest.pending(tasks: tasks, reflections: reflections, now: now)
        let yesterday = now.startOfDay.addingDays(-1)
        let insuranceUsed = purchases.contains { $0.kind == .streakInsurance && $0.usedOn == yesterday }
        let recap = DayRecap.make(tasks: tasks, now: now)
        let nextWeek = nextWeekToPlan(now: now)
        let settings = settingsList.first
        let wroteToday = diaryEntries.contains { $0.day.isSameDay(as: now) && $0.hasWriting }
        let points = PointsService.balance(tasks, purchases: purchases, diary: diary, now: now)
        let lastGym = tasks.filter { $0.category == .gym && $0.isDone }.compactMap(\.completedAt).max()
        let signedIn = AccountService.shared.isSignedIn
        let friends = FriendsService.shared
        let bets = BetsService.shared
        let challenges = TogetherService.shared.challenges
        let weekKept = ScoreEngine.promisesKept(tasks.filter { $0.scheduledDate.weekStart == now.weekStart && $0.countsInScores }, now: now)
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: String(localized: "Pro tebe", bundle: .kept))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if let week {
                        ForYouTile(symbol: "sparkles", title: "Tvůj týden je hotový", detail: String(localized: "\(week.done) z \(week.total) slibů", bundle: .kept)) {
                            story = week
                        }
                    }
                    if let month {
                        ForYouTile(symbol: "calendar.badge.checkmark", title: "Tvůj měsíc je hotový", detail: String(localized: "\(month.done) z \(month.total) slibů", bundle: .kept)) {
                            monthStory = month
                        }
                    }
                    if let pending {
                        ForYouTile(symbol: "book.closed", title: "Sebereflexe týdne", detail: String(localized: "Týden \(pending.weekStart.weekNumber)", bundle: .kept)) {
                            reflection = pending
                        }
                    }
                    if insuranceUsed {
                        ForYouTile(symbol: ShopItem.streakInsurance.symbol, title: "Pojistka série použita",
                                   detail: String(localized: "Zbývá: \(PointsService.unused(.streakInsurance, in: purchases))", bundle: .kept), tint: Theme.orange) {}
                    }
                    if let recap {
                        ForYouTile(symbol: "sunrise", title: "Jak dopadl včerejšek", detail: String(localized: "Dodrženo \(recap.done) z \(recap.total)", bundle: .kept)) {
                            forYouSheet = .recap(recap)
                        }
                    }
                    if let nextWeek {
                        ForYouTile(symbol: "calendar.badge.plus", title: "Naplánuj příští týden",
                                   detail: nextWeek == 0 ? String(localized: "Zatím prázdný", bundle: .kept) : String(localized: "V plánu: \(nextWeek)", bundle: .kept), tint: Theme.orange) {
                            openNextWeek()
                        }
                    }
                    if settings?.diaryEnabled != false, !wroteToday {
                        ForYouTile(symbol: "square.and.pencil", title: "Zapiš si dnešek", detail: String(localized: "Pár vět do deníku", bundle: .kept)) {
                            forYouSheet = .diary
                        }
                    }
                    ForYouTile(symbol: "star.circle", title: "Tvoje body", detail: String(localized: "Zůstatek: \(points)", bundle: .kept)) {
                        showsShop = true
                    }
                    if let lastGym {
                        ForYouTile(symbol: TaskCategory.gym.symbol, title: "Gym – progres",
                                   detail: String(localized: "Naposledy \(lastGym.formatted(.relative(presentation: .named).locale(.app)))", bundle: .kept)) {
                            forYouSheet = .gym
                        }
                    }
                    ForYouTile(symbol: "person.2", title: "Přátelé",
                               detail: friends.incoming.isEmpty
                                   ? (friends.unreadPokes > 0 ? String(localized: "Nová šťouchnutí: \(friends.unreadPokes)", bundle: .kept) : String(localized: "Spolu je to snazší", bundle: .kept))
                                   : String(localized: "Žádosti: \(friends.incoming.count)", bundle: .kept)) {
                        forYouSheet = .friends
                    }
                    if signedIn {
                        ForYouTile(symbol: "trophy", title: "Sázky",
                                   detail: bets.open.isEmpty ? String(localized: "Vsaď se o body", bundle: .kept) : String(localized: "Běží: \(bets.open.count)", bundle: .kept)) {
                            forYouSheet = .bets
                        }
                        ForYouTile(symbol: "flag.2.crossed", title: "Výzvy",
                                   detail: challenges.isEmpty ? String(localized: "Dotáhněte to spolu", bundle: .kept) : String(localized: "Tvoje výzvy: \(challenges.count)", bundle: .kept)) {
                            forYouSheet = .challenges
                        }
                    }
                    if let weekKept {
                        ForYouTile(symbol: "chart.bar", title: "Statistiky", detail: String(localized: "Tento týden \(weekKept.percentText)", bundle: .kept)) {
                            forYouSheet = .stats
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
            .scrollHintBar()
        }
    }

    /// Tasks already planned for the coming week, or nil when it is too early or the plan is handed in.
    private func nextWeekToPlan(now: Date) -> Int? {
        let weekday = Calendar.app.component(.weekday, from: now)
        guard weekday == 1 || weekday >= Self.planAheadFromWeekday else { return nil }
        let plan = plans.first { $0.weekStart == now.weekStart.addingDays(7) }
        guard plan?.isCommitted != true, plan?.isSealing != true else { return nil }
        return plan?.activeTasks.count ?? 0
    }
}

/// One small card of the "Pro tebe" row.
struct ForYouTile: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: String
    var tint: Color = Theme.textPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: symbol)
                    .scaledFont(.heading, weight: .semibold)
                    .foregroundStyle(tint)
                Text(title)
                    .scaledFont(.body, weight: .bold)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(detail)
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(width: 152, height: 118, alignment: .topLeading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
