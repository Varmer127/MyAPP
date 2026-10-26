import SwiftUI
import SwiftData

/// The first row of Settings: who the user is in Kept, at a glance. Opens the profile.
struct ProfileCard: View {
    @Query private var tasks: [TaskItem]
    @Query private var plans: [WeeklyPlan]
    @Query private var failures: [FailureRecord]
    @Query private var diary: [DiaryEntry]
    @Query private var settingsList: [UserSettings]

    var body: some View {
        let settings = settingsList.first
        let streak = ScoreEngine.dayStreak(tasks)
        let badges = ProfileData.badges(tasks: tasks, plans: plans, failures: failures, diary: diary, settings: settings)
        NavigationLink {
            ProfileView()
        } label: {
            HStack(spacing: 14) {
                ProfileAvatar(name: settings?.addressName ?? "", size: 54)
                VStack(alignment: .leading, spacing: 3) {
                    Text(ProfileData.displayName(settings))
                        .scaledFont(.heading, weight: .bold)
                        .foregroundStyle(Theme.textPrimary)
                    Text(streak > 0
                         ? "Držíš slovo \(streak) \(streak == 1 ? "den" : (2...4).contains(streak) ? "dny" : "dní") · odznaky \(badges.filter(\.isEarned).count) / \(badges.count)"
                         : "Odznaky \(badges.filter(\.isEarned).count) / \(badges.count) · začni sérii dnes")
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.vertical, 4)
        }
        .accessibilityHint("Otevře profil, kalendář série a odznaky")
    }
}

enum ProfileData {
    static func displayName(_ settings: UserSettings?) -> String {
        let name = settings?.addressName.trimmingCharacters(in: .whitespaces) ?? ""
        return name.isEmpty ? "Tvůj profil" : name
    }

    static func badges(tasks: [TaskItem], plans: [WeeklyPlan], failures: [FailureRecord], diary: [DiaryEntry],
                       settings: UserSettings?) -> [Achievement] {
        BadgeService.evaluate(tasks: tasks, plans: plans, failures: failures, diary: diary) {
            settings?.weeklyTarget(for: $0) ?? $0.defaultWeeklyTarget
        }
    }
}

struct ProfileAvatar: View {
    let name: String
    var size: CGFloat = 54

    var body: some View {
        ZStack {
            Circle().fill(Theme.textPrimary)
            if let first = name.trimmingCharacters(in: .whitespaces).first {
                Text(String(first).uppercased())
                    .scaledFont(size * 0.46, weight: .heavy)
                    .foregroundStyle(Theme.onPrimary)
            } else {
                CheckStroke()
                    .stroke(Theme.onPrimary, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round, lineJoin: .round))
                    .frame(width: size * 0.42, height: size * 0.32)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Who the user is, how the streak looks month by month, and the badges earned and still to earn.
struct ProfileView: View {
    @Query private var tasks: [TaskItem]
    @Query private var plans: [WeeklyPlan]
    @Query private var failures: [FailureRecord]
    @Query private var diary: [DiaryEntry]
    @Query private var purchases: [PointsPurchase]
    @Query private var settingsList: [UserSettings]
    @State private var filter: Filter = .all
    @State private var selectedID: String?

    private enum Filter: String, CaseIterable, Identifiable {
        case all = "Všechny", earned = "Získané", todo = "Zbývá"
        var id: String { rawValue }
    }

    private var settings: UserSettings? { settingsList.first }
    private var badges: [Achievement] {
        ProfileData.badges(tasks: tasks, plans: plans, failures: failures, diary: diary, settings: settings)
    }

    var body: some View {
        let all = badges
        let shown = all.filter { filter == .all || (filter == .earned) == $0.isEarned }
        let selected = all.first { $0.id == selectedID }
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                header
                StreakCalendar(tasks: tasks)
                FriendsEntryCard()
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SectionLabel(text: "Odznaky")
                        Spacer()
                        Text("\(all.filter(\.isEarned).count) z \(all.count)")
                            .scaledFont(.body, weight: .bold)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    nearest(all)
                    Picker("Filtr", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
                        ForEach(shown) { badge in
                            Button {
                                select(badge)
                            } label: {
                                BadgeTile(badge: badge, isSelected: badge.id == selected?.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if let settings {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "Oslovení")
                        VStack(alignment: .leading, spacing: 0) {
                            TextField("Oslovení, např. Filipe", text: Bindable(settings).addressName)
                                .scaledFont(.body)
                                .frame(minHeight: 44)
                            Divider().overlay(Theme.border)
                            Picker("Mluvit se mnou", selection: Bindable(settings).grammar) {
                                ForEach(GrammarGender.allCases) { Text($0.title).tag($0) }
                            }
                            .tint(Theme.textPrimary)
                            .frame(minHeight: 44)
                        }
                        .card(padding: 14)
                        Text("Takhle tě Kept oslovuje ráno a v textech. Napiš oslovení tak, jak ho chceš číst, třeba „Filipe“ nebo „Anežko“.")
                            .scaledFont(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 32)
        }
        .screenBackground()
        .refreshesData()
        .overlay(alignment: .bottom) {
            // A small window with the details of the chosen badge. It stays until another badge is chosen or it is closed.
            if let selected {
                BadgePopup(badge: selected) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { selectedID = nil }
                }
                .id(selected.id)
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 96)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }

    private func select(_ badge: Achievement) {
        Haptics.light()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { selectedID = badge.id }
    }

    /// The locked badges that are closest to being earned: a goal that is almost reached pulls harder than a list of grey circles.
    @ViewBuilder
    private func nearest(_ all: [Achievement]) -> some View {
        let close = all.filter { !$0.isEarned }
            .compactMap { badge -> (Achievement, Double)? in
                guard let progress = badge.progress, progress.current > 0 else { return nil }
                return (badge, Double(progress.current) / Double(max(progress.target, 1)))
            }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
        if !close.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("NEJBLÍŽ K ZÍSKÁNÍ").labelStyle()
                ForEach(Array(close), id: \.0.id) { badge, fraction in
                    Button { select(badge) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: badge.symbol)
                                .scaledFont(.body, weight: .semibold)
                                .foregroundStyle(Theme.textPrimary)
                                .frame(width: 36, height: 36)
                                .background(Theme.cardRaised)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(badge.name)
                                        .scaledFont(.body, weight: .semibold)
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    Text(badge.statusText)
                                        .scaledFont(.caption, weight: .bold)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                ThinBar(value: fraction, color: Theme.green)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .card()
        }
    }

    private var header: some View {
        let streak = ScoreEngine.dayStreak(tasks)
        let points = PointsService.balance(tasks, purchases: purchases, diary: diary)
        let sealed = plans.filter(\.isCommitted).count
        return VStack(spacing: 18) {
            HStack(spacing: 16) {
                ProfileAvatar(name: settings?.addressName ?? "", size: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text(ProfileData.displayName(settings))
                        .scaledFont(.title, weight: .bold)
                        .foregroundStyle(Theme.textPrimary)
                    Text(streak > 0 ? "Držíš slovo \(streak) \(streak == 1 ? "den" : (2...4).contains(streak) ? "dny" : "dní") v řadě." : "Dnes můžeš začít novou sérii.")
                        .scaledFont(.body)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
            }
            TileRow {
                MetricTile(value: "\(streak)", label: "Série dní")
                MetricTile(value: "\(sealed)", label: "Pečetí")
                MetricTile(value: points.formatted(.number.locale(.app)), label: "Bodů")
            }
        }
    }
}

private struct BadgeTile: View {
    let badge: Achievement
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                if badge.isEarned {
                    Circle().fill(Theme.textPrimary)
                    Image(systemName: badge.shownSymbol)
                        .scaledFont(.title, weight: .semibold)
                        .foregroundStyle(Theme.onPrimary)
                } else {
                    Circle().fill(Theme.card)
                    Circle().strokeBorder(Theme.textTertiary.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    if let progress = badge.progress, progress.current > 0 {
                        // How far along: a ring that fills around the grey circle.
                        Circle()
                            .trim(from: 0, to: min(Double(progress.current) / Double(max(progress.target, 1)), 1))
                            .stroke(Theme.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    Image(systemName: badge.shownSymbol)
                        .scaledFont(.title)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(width: 64, height: 64)
            .overlay {
                if badge.isEarned, badge.tier != .common {
                    Circle().stroke(badge.tier == .legendary ? Theme.orange : Theme.green, lineWidth: 3).padding(-4)
                }
            }
            .scaleEffect(isSelected ? 1.08 : 1)
            Text(badge.shownName)
                .scaledFont(.caption, weight: .semibold)
                .foregroundStyle(badge.isEarned ? Theme.textPrimary : Theme.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(badge.shownName), \(badge.statusText.isEmpty ? "zamčeno" : badge.statusText). \(badge.shownHow)")
    }
}

/// The details of one badge in a small floating window with a close button in its corner.
private struct BadgePopup: View {
    let badge: Achievement
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(badge.isEarned ? Theme.textPrimary : Theme.cardRaised)
                Image(systemName: badge.shownSymbol)
                    .scaledFont(.title, weight: .semibold)
                    .foregroundStyle(badge.isEarned ? Theme.onPrimary : Theme.textTertiary)
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(badge.tier.title)
                    .scaledFont(.caption, weight: .heavy)
                    .tracking(1)
                    .foregroundStyle(badge.tier == .legendary ? Theme.orange : (badge.tier == .rare ? Theme.green : Theme.textSecondary))
                Text(badge.shownName)
                    .scaledFont(.heading, weight: .bold)
                    .foregroundStyle(Theme.textPrimary)
                Text(badge.shownHow)
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let progress = badge.progress, !badge.isEarned {
                    ThinBar(value: Double(min(progress.current, progress.target)) / Double(max(progress.target, 1)), color: Theme.green)
                        .padding(.top, 3)
                }
                if !badge.statusText.isEmpty {
                    Text(badge.statusText)
                        .scaledFont(.caption, weight: .bold)
                        .foregroundStyle(badge.isEarned ? Theme.green : Theme.textSecondary)
                        .padding(.top, 1)
                }
            }
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .scaledFont(.caption, weight: .bold)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, -10)
            .padding(.top, -10)
            .accessibilityLabel("Zavřít")
        }
        .padding(16)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 16, y: 6)
        .accessibilityElement(children: .contain)
    }
}

/// A month at a glance: days kept in green, days broken in red, the running streak as a band, milestones as flames.
struct StreakCalendar: View {
    let tasks: [TaskItem]
    @State private var month = Date.now.startOfDay.startOfMonth
    @State private var selected = Date.now.startOfDay

    private enum Status { case kept, broken, open, none }

    private var byDay: [Date: [TaskItem]] {
        Dictionary(grouping: tasks.filter { !$0.isRemoved && $0.countsInScores }) { $0.scheduledDate.startOfDay }
    }

    private func status(of day: Date) -> Status {
        let items = byDay[day] ?? []
        guard !items.isEmpty else { return .none }
        let today = Date.now.startOfDay
        if day > today { return .open }
        if items.allSatisfy(\.isDone) { return .kept }
        if let score = ScoreEngine.productivity(items, now: .now) {
            if score >= ScoreEngine.Config.streakThreshold { return .kept }
            return day < today ? .broken : .open
        }
        return .open
    }

    /// The days of the running streak, with the rest days between them.
    private var streakDays: Set<Date> {
        var days = Set<Date>()
        let today = Date.now.startOfDay
        guard let earliest = byDay.keys.min() else { return days }
        var day = today
        var lastKept: Date?
        while day >= earliest {
            switch status(of: day) {
            case .kept:
                days.insert(day)
                lastKept = day
            case .broken:
                return days
            case .open, .none:
                break
            }
            day = day.addingDays(-1)
        }
        guard let first = days.min(), let last = days.max(), let _ = lastKept else { return days }
        var d = first
        while d <= last { days.insert(d); d = d.addingDays(1) }
        return days
    }

    var body: some View {
        let streakDays = streakDays
        let milestoneDays = Set(StreakService.milestones(tasks).compactMap { $0.reachedOn?.addingDays(-1).startOfDay })
        let days = monthDays
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionLabel(text: "Kalendář série")
                Spacer()
                Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 36, height: 36) }
                    .accessibilityLabel("Předchozí měsíc")
                Text(month.monthYearText)
                    .scaledFont(.body, weight: .bold)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(minWidth: 110)
                Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 36, height: 36) }
                    .disabled(month >= Date.now.startOfMonth)
                    .accessibilityLabel("Další měsíc")
            }
            .foregroundStyle(Theme.textPrimary)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(["Po", "Út", "St", "Čt", "Pá", "So", "Ne"], id: \.self) { name in
                    Text(name).scaledFont(.caption, weight: .bold).foregroundStyle(Theme.textTertiary)
                }
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        cell(day, streak: streakDays.contains(day), milestone: milestoneDays.contains(day))
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
            HStack(spacing: 14) {
                legend(Theme.green, "den dodržen")
                legend(Theme.red, "slib porušen")
                legend(Theme.orange.opacity(0.35), "série")
                Label("milník", systemImage: "flame.fill").scaledFont(.caption).foregroundStyle(Theme.orange)
            }
            .scaledFont(.caption)
            .foregroundStyle(Theme.textSecondary)
            dayDetail
        }
        .card()
    }

    private var monthDays: [Date?] {
        let calendar = Calendar.app
        let range = calendar.range(of: .day, in: .month, for: month) ?? 1..<31
        let offset = (calendar.component(.weekday, from: month) + 5) % 7
        return Array(repeating: nil, count: offset) + range.map { month.addingDays($0 - 1) }
    }

    private func shift(_ delta: Int) {
        withAnimation(.easeOut(duration: 0.2)) {
            month = Calendar.app.date(byAdding: .month, value: delta, to: month)?.startOfMonth ?? month
        }
    }

    /// Days still to come are grey; days before the first task ever are fainter, since there was nothing to keep yet.
    private func dayColor(_ day: Date) -> Color {
        if day > .now { return Theme.textSecondary }
        if let first = byDay.keys.min(), day >= first { return Theme.textPrimary }
        return Theme.textTertiary.opacity(0.45)
    }

    private func cell(_ day: Date, streak: Bool, milestone: Bool) -> some View {
        let state = status(of: day)
        let isToday = day.isSameDay(as: .now)
        let isSelected = day.isSameDay(as: selected)
        let fill: Color = state == .kept ? Theme.green : (state == .broken ? Theme.red : .clear)
        return Button {
            Haptics.light()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selected = day }
        } label: {
            ZStack {
                if streak {
                    Rectangle().fill(Theme.orange.opacity(0.18)).frame(height: 30)
                }
                Circle().fill(fill).frame(width: 32, height: 32)
                    .overlay(Circle().stroke(isSelected || isToday ? Theme.textPrimary : .clear, lineWidth: 2))
                Text("\(Calendar.app.component(.day, from: day))")
                    .scaledFont(.caption, weight: .bold)
                    .foregroundStyle(state == .kept ? Color(hex: 0x000000) : (state == .broken ? Color(hex: 0xFFFFFF)
                        : dayColor(day)))
                if milestone {
                    Image(systemName: "flame.fill")
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.orange)
                        .offset(x: 12, y: -14)
                }
            }
            .frame(height: 44)
            .scaleEffect(isSelected ? 1.1 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.dayMonthText)")
    }

    private var dayDetail: some View {
        let items = byDay[selected] ?? []
        let state = status(of: selected)
        let title: String = {
            switch state {
            case .kept: "Den dodržen"
            case .broken: "Slib porušen"
            case .open: selected.isSameDay(as: .now) ? "Dnes ještě není hotovo" : "Ještě se nestalo"
            case .none: "Bez plánu"
            }
        }()
        return VStack(alignment: .leading, spacing: 4) {
            Text(selected.longDayText.uppercased()).labelStyle()
            Text(title).scaledFont(.heading, weight: .bold).foregroundStyle(Theme.textPrimary)
            if !items.isEmpty {
                Text("\(items.filter(\.isDone).count) z \(items.count) úkolů splněno")
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.cardRaised)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(text)
        }
    }
}
