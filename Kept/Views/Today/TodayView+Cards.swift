import SwiftUI
import SwiftData

extension TodayView {
    /// The failure state exists only in the savage tone and only when the day is really going wrong:
    /// several critical tasks overdue or all of them lost, or under 50 % by the evening.
    func isSlipping(_ day: TodaySnapshot, now: Date) -> Bool {
        guard settingsList.first?.tone == .savage else { return false }
        let critical = day.scored.filter { $0.scoringPriority == .critical && !$0.isRemoved }
        let overdue = critical.filter { $0.isOverdue(now) }.count
        let allCriticalGone = critical.count >= Self.slippingCriticalCount
            && critical.allSatisfy { $0.isLost(now) || $0.isOverdue(now) }
        let weakEvening = now.minutesIntoDay >= Self.slippingAfterMinutes
            && !day.scored.isEmpty && (day.productivity ?? 0) < Theme.poorThreshold
        return overdue >= Self.slippingCriticalCount || allCriticalGone || weakEvening
    }

    func slippingBanner(_ day: TodaySnapshot) -> some View {
        let critical = day.scored.filter { $0.scoringPriority == .critical && !$0.isRemoved }
        return VStack(alignment: .leading, spacing: 6) {
            Text("DNEŠEK TI UTÍKÁ")
                .scaledFont(.title, weight: .heavy)
                .foregroundStyle(Theme.red)
            if !critical.isEmpty {
                Text("KRITICKÉ ÚKOLY \(critical.filter(\.isDone).count) / \(critical.count)")
                    .labelStyle(Theme.red)
            }
        }
    }

    /// Offered in the first days of a month, once, when the month that ended has something to tell.
    @ViewBuilder
    func monthStoryCard(now: Date) -> some View {
        if let month = MonthStory.offeredMonth(now: now), storySeenMonth != month.timeIntervalSince1970,
           let offered = MonthStory.make(tasks: tasks, monthStart: month, now: now) {
            Button {
                Haptics.light()
                monthStory = offered
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "calendar.badge.checkmark")
                        .scaledFont(.heading)
                        .foregroundStyle(Theme.onPrimary)
                        .frame(width: 44, height: 44)
                        .background(Theme.textPrimary)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TVŮJ MĚSÍC JE HOTOVÝ").labelStyle(Theme.textPrimary)
                        Text("\(offered.done) z \(offered.total) slibů. Podívej se, jak to dopadlo.")
                            .scaledFont(.body)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
                }
                .card()
            }
            .buttonStyle(.plain)
        }
    }

    /// Offered once the week is over, once per week, when the week has something to tell.
    @ViewBuilder
    func weekStoryCard(now: Date) -> some View {
        if let week = WeekStory.offeredWeek(now: now), storySeenWeek != week.timeIntervalSince1970,
           let offered = WeekStory.make(tasks: tasks, diary: diaryEntries, weekStart: week, now: now) {
            Button {
                Haptics.light()
                story = offered
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .scaledFont(.heading)
                        .foregroundStyle(Theme.onPrimary)
                        .frame(width: 44, height: 44)
                        .background(Theme.textPrimary)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TVŮJ TÝDEN JE HOTOVÝ").labelStyle(Theme.textPrimary)
                        Text("\(offered.done) z \(offered.total) slibů. Podívej se, jak to dopadlo.")
                            .scaledFont(.body)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
                }
                .card()
            }
            .buttonStyle(.plain)
        }
    }

    /// The broken streak that is currently offered for buying back, if any.
    func repairOffer(now: Date) -> StreakService.Broken? {
        guard let broken = StreakService.broken(tasks, now: now), broken.canRepair(now: now),
              streakOfferDismissed != broken.brokenOn.timeIntervalSince1970 else { return nil }
        return broken
    }

    /// Yesterday under 60 %: today is a comeback until it is back above 80 %.
    func comeback(_ day: TodaySnapshot, now: Date) -> (yesterday: Double, today: Double, succeeded: Bool)? {
        let yesterdayTasks = tasks.filter { $0.scheduledDate.isSameDay(as: now.startOfDay.addingDays(-1)) }
        guard let yesterday = ScoreEngine.productivity(yesterdayTasks, now: now), yesterday < Self.comebackThreshold else { return nil }
        let today = day.productivity ?? 0
        return (yesterday, today, today >= ScoreEngine.Config.streakThreshold)
    }

    /// For a few days after the streak breaks it can be bought back with points.
    /// A bad yesterday is part of the same story, so the comeback is folded into this card instead of a second one.
    @ViewBuilder
    func streakCard(_ day: TodaySnapshot, now: Date) -> some View {
        if let broken = repairOffer(now: now) {
            let balance = PointsService.balance(tasks, purchases: purchases, diary: diary)
            let cost = broken.cost
            VStack(alignment: .leading, spacing: 12) {
                Label("SÉRIE SKONČILA", systemImage: "flame.fill").labelStyle(Theme.orange)
                Text("Měl jsi \(String.days(broken.length)) v řadě.")
                    .scaledFont(.heading, weight: .bold)
                    .foregroundStyle(Theme.textPrimary)
                // The day text already ends with a full stop ("so 10.").
                Text("Přerušeno: \(broken.failedDays.map(\.shortDayText).joined(separator: ", ")) "
                     + "Za \(cost.formatted(.number.locale(.app))) bodů ji vrátíš, jako by se nepřerušila.")
                    .scaledFont(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                streakCountdown(until: broken.repairEnds, now: now)
                if balance < cost {
                    Text("Máš \(balance.formatted(.number.locale(.app))) bodů, chybí ti \((cost - balance).formatted(.number.locale(.app))).")
                        .scaledFont(.caption, weight: .semibold)
                        .foregroundStyle(Theme.orange)
                }
                HStack(spacing: 10) {
                    Button("VRÁTIT ZA \(cost.formatted(.number.locale(.app))) BODŮ") { confirmRepair = broken }
                        .buttonStyle(PrimaryButtonStyle(color: Theme.orange))
                        .disabled(balance < cost)
                    Button("ZAČÍT OD NULY") {
                        withAnimation { streakOfferDismissed = broken.brokenOn.timeIntervalSince1970 }
                    }
                    .buttonStyle(SecondaryButtonStyle(textColor: Theme.textSecondary))
                }
                if let comeback = comeback(day, now: now) {
                    Divider().overlay(Theme.border)
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(comeback.succeeded ? "COMEBACK SE POVEDL" : "COMEBACK DAY")
                                .labelStyle(comeback.succeeded ? Theme.green : Theme.orange)
                            Text("Včera \(comeback.yesterday.percentText) · dnes \(comeback.today.percentText)")
                                .scaledFont(.body, weight: .semibold)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        Spacer()
                        if !comeback.succeeded {
                            Button("RECOVERY ÚKOL") { editor = EditorRequest(date: now, isRecovery: true) }
                                .scaledFont(.caption, weight: .bold)
                                .tracking(0.6)
                                .foregroundStyle(Theme.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(Theme.cardRaised)
                                .clipShape(Capsule())
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.orange.opacity(0.5), lineWidth: 1))
            .alert("Vrátit sérii za \(cost.formatted(.number.locale(.app))) bodů?",
                   isPresented: Binding(get: { confirmRepair != nil }, set: { if !$0 { confirmRepair = nil } }),
                   presenting: confirmRepair) { broken in
                Button("Vrátit sérii") {
                    withAnimation { StreakService.repair(broken, tasks: tasks) }
                }
                Button("Zrušit", role: .cancel) {}
            } message: { _ in
                Text("Plamínek se vrátí. Nesplněné úkoly těch dnů i jejich vliv na spolehlivost zůstávají.")
            }
        }
    }

    /// The day after a streak insurance stepped in, so it does not get spent unnoticed.
    @ViewBuilder
    func insuranceUsedCard(now: Date) -> some View {
        let yesterday = now.startOfDay.addingDays(-1)
        if purchases.contains(where: { $0.kind == .streakInsurance && $0.usedOn == yesterday }) {
            HStack(spacing: 12) {
                Image(systemName: ShopItem.streakInsurance.symbol)
                    .scaledFont(.title)
                    .foregroundStyle(Theme.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text("POJISTKA SÉRIE POUŽITA").labelStyle(Theme.orange)
                    Text("Včerejšek nevyšel, plamínek ale hoří dál. Zbývá pojistek: \(PointsService.unused(.streakInsurance, in: purchases)).")
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .card()
        }
    }

    /// Live countdown to the end of the buy-back offer; turns red in the last hours.
    func streakCountdown(until end: Date, now: Date) -> some View {
        let color = end.timeIntervalSince(now) < Self.streakUrgentSeconds ? Theme.red : Theme.orange
        return HStack(spacing: 6) {
            Image(systemName: "timer")
            Text("NABÍDKA KONČÍ ZA")
                .tracking(0.6)
            Text(timerInterval: min(now, end)...end, countsDown: true)
                .monospacedDigit()
        }
        .scaledFont(.caption, weight: .bold)
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.14))
        .clipShape(Capsule())
    }

    var uncommittedCard: some View {
        Button(action: openWeek) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TENTO TÝDEN BEZ ZÁVAZKU").labelStyle(Theme.orange)
                    Text("Dokud neodešleš plánovač a nezapečetí se, nic z toho, co uděláš, se nepočítá jako dodržený slib.")
                        .scaledFont(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    /// After a day under 60 %, today is framed as a comeback: orange until today is back above 80 %.
    /// While the streak buy-back card is shown, the comeback lives inside that one.
    @ViewBuilder
    func comebackCard(_ day: TodaySnapshot, now: Date) -> some View {
        if repairOffer(now: now) == nil, let comeback = comeback(day, now: now) {
            let color = comeback.succeeded ? Theme.green : Theme.orange
            VStack(alignment: .leading, spacing: 14) {
                Text(comeback.succeeded ? "COMEBACK SE POVEDL" : "COMEBACK DAY").labelStyle(color)
                HStack(spacing: 28) {
                    comebackFigure("Včera", comeback.yesterday.percentText, Theme.textSecondary)
                    comebackFigure("Dnes", comeback.today.percentText, color)
                }
                Text(comeback.succeeded ? "Včerejšek jsi nezměnil. Dnešek ano." : "Včerejšek nezměníš. Dnešek ano.")
                    .scaledFont(.body, weight: .semibold)
                    .foregroundStyle(Theme.textPrimary)
                if !comeback.succeeded {
                    Button("VYTVOŘIT RECOVERY ÚKOL") {
                        editor = EditorRequest(date: now, isRecovery: true)
                    }
                    .buttonStyle(PrimaryButtonStyle(color: Theme.orange))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(color.opacity(0.5), lineWidth: 1))
        }
    }

    func comebackFigure(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).labelStyle()
            Text(value)
                .scaledFont(34, weight: .heavy)
                .foregroundStyle(color)
        }
    }

    /// After failing a task with a stake on it, asks whether the stake was honoured.
    @ViewBuilder
    func stakeCards(now: Date) -> some View {
        let since = now.startOfDay.addingDays(-Self.stakeQuestionDays)
        let open = tasks.filter {
            !$0.stake.isEmpty && $0.stakeOutcome == 0 && $0.scheduledDate >= since
                && ($0.status == .skipped || $0.status == .failed)
        }
        ForEach(open) { task in
            VStack(alignment: .leading, spacing: 12) {
                Text("SÁZKA").labelStyle(Theme.orange)
                Text("Nesplnil jsi „\(task.title)“. Vsadil ses o tohle:")
                    .scaledFont(.body)
                    .foregroundStyle(Theme.textSecondary)
                Text("„\(task.stake)“")
                    .scaledFont(.heading, weight: .semibold)
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 10) {
                    Button("DODRŽEL JSEM") { withAnimation { task.stakeOutcome = 1 } }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("NEDODRŽEL") { withAnimation { task.stakeOutcome = 2 } }
                        .buttonStyle(SecondaryButtonStyle(textColor: Theme.red))
                }
            }
            .card()
        }
    }

    /// Apple Health saw a workout today while a gym task is still open: one tap to log and close it.
    @ViewBuilder
    func healthWorkoutCard(_ day: TodaySnapshot) -> some View {
        let gymToday = day.visible.filter { $0.category == .gym }
        // Nothing to offer once a gym workout is logged today.
        if let minutes = healthGymMinutes, !gymToday.contains(where: \.isDone) {
            let planned = gymToday.first { $0.status == .pending }
            VStack(alignment: .leading, spacing: 12) {
                Label("APPLE HEALTH", systemImage: "heart.fill").labelStyle(Theme.green)
                Text(planned.map { "Dnes máš zaznamenaný trénink (\(minutes) min). Zapiš, co jsi jel, a „\($0.title)“ je splněný." }
                     ?? "Dnes máš zaznamenaný trénink (\(minutes) min), i když jsi ho neměl v plánu. Zapiš ho, ať se počítá.")
                    .scaledFont(.body)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("ZAPSAT TRÉNINK") { complete(planned ?? addUnplannedGym(minutes: minutes)) }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .card()
        }
    }

    /// A workout Health recorded without a planned task still gets tracked: it becomes today's gym task.
    func addUnplannedGym(minutes: Int) -> TaskItem {
        var draft = TaskDraft(date: .now)
        draft.title = TaskCategory.gym.title
        draft.category = .gym
        draft.plannedMinutes = max(15, minutes / 15 * 15)
        // If the app was suggesting gym today anyway, the workout earns the suggestion bonus.
        draft.fromSuggestion = visibleSuggestions(now: .now).contains { $0.category == .gym }
        draft.weight = settingsList.first?.defaultWeight(category: .gym, priority: draft.priority)
            ?? UserSettings.weight(points: draft.priority.basePoints, multiplier: TaskCategory.gym.defaultMultiplier)
        return PlanService.save(draft, to: nil, in: context)
    }

    /// Points towards the next pass. One pass cancels a weekly commitment without penalty.
    var pointsCard: some View {
        let balance = PointsService.balance(tasks, purchases: purchases, diary: diary)
        let passes = balance / PointsService.passCost
        let towardsNext = balance % PointsService.passCost
        let isFull = balance >= PointsService.cap
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(balance.formatted(.number.locale(.app)))")
                    .scaledFont(.body, weight: .semibold)
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
                Text("/ \(PointsService.cap.formatted(.number.locale(.app))) BODŮ").labelStyle()
                Spacer()
                Button {
                    showsShop = true
                } label: {
                    Label("OBCHOD", systemImage: "bag.fill")
                        .scaledFont(.caption, weight: .bold)
                        .tracking(0.6)
                        .foregroundStyle(Theme.onPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Theme.textPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            ThinBar(value: Double(balance) / Double(PointsService.cap),
                    color: passes > 0 ? Theme.green : Theme.textPrimary)
            Text(passes == 0 ? "Do propustky chybí \(PointsService.passCost - towardsNext). Co všechno se dá za body pořídit, najdeš v obchodě."
                 : (isFull ? "Propustky: \(passes) · plná zásoba, další body propadají. Utrať je v obchodě."
                    : "Propustky: \(passes). Co všechno se dá za body pořídit, najdeš v obchodě."))
                .scaledFont(.caption)
                .foregroundStyle(Theme.textTertiary)
        }
        .animation(.easeOut(duration: 0.4), value: balance)
    }

    func reflectionCard(_ pending: ReflectionRequest) -> some View {
        Button {
            reflection = pending
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SEBEREFLEXE TÝDNE \(pending.weekStart.weekNumber)").labelStyle(Theme.textPrimary)
                    Text("Projdi si týden a zapiš do deníčku, jak jsi se sebou spokojený.")
                        .scaledFont(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    var realityCheckCard: some View {
        Button {
            showsRealityCheck = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("UZAVŘI DNEŠEK").labelStyle(Theme.orange)
                    Text("Den končí a ty máš pořád otevřené závazky.")
                        .scaledFont(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    /// An empty day invites the first promise instead of showing numbers that mean nothing yet.
    var emptyState: some View {
        VStack(spacing: 14) {
            EmptyStateArt(kind: .plan)
            Text("Dnes nemáš nic v plánu.")
                .scaledFont(.heading, weight: .bold)
                .foregroundStyle(Theme.textPrimary)
            Text("Den bez slibu nejde dodržet ani porušit. Přidej si jeden a začni.")
                .scaledFont(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("PŘIDAT DNEŠNÍ SLIB") {
                editor = EditorRequest(date: .now)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .card()
    }
}
