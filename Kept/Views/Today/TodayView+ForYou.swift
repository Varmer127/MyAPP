import SwiftUI

/// "Pro tebe": everything on Today that is good to see but not urgent, as one row of small tiles
/// (the week and month story, the weekly reflection, a used streak insurance, friends).
extension TodayView {
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
        let friends = FriendsService.shared
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Pro tebe")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if let week {
                        ForYouTile(symbol: "sparkles", title: "Tvůj týden je hotový", detail: "\(week.done) z \(week.total) slibů") {
                            story = week
                        }
                    }
                    if let month {
                        ForYouTile(symbol: "calendar.badge.checkmark", title: "Tvůj měsíc je hotový", detail: "\(month.done) z \(month.total) slibů") {
                            monthStory = month
                        }
                    }
                    if let pending {
                        ForYouTile(symbol: "book.closed", title: "Sebereflexe týdne", detail: "Týden \(pending.weekStart.weekNumber)") {
                            reflection = pending
                        }
                    }
                    if insuranceUsed {
                        ForYouTile(symbol: ShopItem.streakInsurance.symbol, title: "Pojistka série použita",
                                   detail: "Zbývá: \(PointsService.unused(.streakInsurance, in: purchases))", tint: Theme.orange) {}
                    }
                    ForYouTile(symbol: "person.2", title: "Přátelé",
                               detail: friends.incoming.isEmpty
                                   ? (friends.unreadPokes > 0 ? "Nová šťouchnutí: \(friends.unreadPokes)" : "Spolu je to snazší")
                                   : "Žádosti: \(friends.incoming.count)") {
                        showsFriends = true
                    }
                }
                .padding(.horizontal, 1)
            }
            .scrollHintBar()
        }
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
