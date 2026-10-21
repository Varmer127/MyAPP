import SwiftUI
import SwiftData

struct TodayView: View {
    @Query private var tasks: [TaskItem]
    @Query private var plans: [WeeklyPlan]
    @Query private var settingsList: [UserSettings]
    @Query private var failures: [FailureRecord]
    @Query private var postponements: [Postponement]
    @Query private var reflections: [WeekReflection]
    @Query private var purchases: [PointsPurchase]
    @Query private var diary: [DiaryEntry]
    @State private var showsShop = false
    /// Points just earned, shown for a moment above the tab bar.
    @State private var pointsGain: PointsGain?
    /// Day on which the weekly reflection last opened by itself, so it only interrupts once a day.
    @AppStorage("reflectionPromptDay") private var reflectionPromptDay = 0.0
    @State private var reflection: ReflectionRequest?
    /// Minutes of a gym workout Apple Health recorded today, if any.
    @State private var healthGymMinutes: Int?
    /// Start of the day (as a timestamp) on which the Morning Brief was last dismissed.
    @AppStorage("briefDismissedDay") private var briefDismissedDay = 0.0
    /// "<day seed>:<category>,<category>" — suggestions the user declined today.
    @AppStorage("declinedSuggestions") private var declinedSuggestions = ""
    /// Day (as a timestamp) of the streak break whose buy-back offer the user turned down.
    @AppStorage(StreakService.offerDismissedKey) private var streakOfferDismissed = 0.0
    /// Broken streak waiting for the "really spend the points?" confirmation.
    @State private var confirmRepair: StreakService.Broken?
    @State private var showsRealityCheck = false
    @State private var editor: EditorRequest?
    @State private var workoutTask: TaskItem?
    @State private var proofTask: TaskItem?
    @State private var partialTask: TaskItem?
    /// Partial completion confirmed in the sheet; applied once the sheet has finished closing.
    @State private var pendingPartial: (task: TaskItem, share: Double, note: String)?
    @State private var postponeTask: TaskItem?
    /// Task the user wants to give up on; asks whether to postpone or to skip.
    @State private var failChoice: TaskItem?
    @State private var focusTask: TaskItem?
    @State private var gymTimerTask: TaskItem?
    @State private var detailTask: TaskItem?
    /// Task to complete once the focus screen has finished closing.
    @State private var completeAfterFocus: TaskItem?
    /// Task waiting for the "did you really do it as planned?" confirmation.
    @State private var confirmDone: TaskItem?
    @State private var excuse: ExcuseRequest?
    let openWeek: () -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    private static let refreshInterval: TimeInterval = 60
    private static let briefVisibleUntilHour = 12
    private static let comebackThreshold = 0.6
    private static let stakeQuestionDays = 7
    private static let slippingAfterMinutes = 18 * 60
    private static let slippingCriticalCount = 2
    private static let streakUrgentSeconds: TimeInterval = 6 * 3600

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: Self.refreshInterval)) { timeline in
                content(now: timeline.date)
            }
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editor = EditorRequest(date: .now)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
        }
        .sheet(item: $editor) {
            TaskEditorView(task: $0.task, defaultDate: $0.date, suggestion: $0.suggestion, isRecovery: $0.isRecovery)
        }
        .fullScreenCover(item: $excuse) { NoExcusesView(task: $0.task, kind: $0.kind) }
        .fullScreenCover(isPresented: $showsRealityCheck) { RealityCheckView() }
        .sheet(item: $workoutTask) { WorkoutLogView(task: $0) }
        .sheet(item: $proofTask) { ProofView(task: $0) }
        .sheet(item: $partialTask, onDismiss: {
            if let partial = pendingPartial {
                pendingPartial = nil
                complete(partial.task, share: partial.share, note: partial.note)
            }
        }) { task in
            PartialView(task: task) { share, note in pendingPartial = (task, share, note) }
        }
        .fullScreenCover(item: $reflection) { ReflectionView(weekStart: $0.weekStart) }
        .task(id: scenePhase) {
            // Opens the reflection by itself the first time the app is used after the week ends.
            let today = Date.now.startOfDay.timeIntervalSince1970
            // Never on top of the focus timer: presenting a second cover would close the first.
            guard scenePhase == .active, reflectionPromptDay != today, focusTask == nil, gymTimerTask == nil,
                  let pending = ReflectionRequest.pending(tasks: tasks, reflections: reflections) else { return }
            reflectionPromptDay = today
            reflection = pending
        }
        .task(id: scenePhase) {
            guard scenePhase == .active, settingsList.first?.healthEnabled == true else { return }
            healthGymMinutes = await HealthService.gymMinutesToday()
        }
        .sheet(item: $postponeTask) { PostponeView(task: $0, remaining: postponesLeft, limit: postponeLimit) }
        .confirmationDialog("Co s tím úkolem?", isPresented: Binding(get: { failChoice != nil }, set: { if !$0 { failChoice = nil } }),
                            titleVisibility: .visible, presenting: failChoice) { task in
            if postponesLeft > 0, !task.isRecovery {
                Button("Odložit bez postihu (zbývá \(postponesLeft) z \(postponeLimit))") { postponeTask = task }
            }
            if PointsService.canRedeem(task, balance: PointsService.balance(tasks, purchases: purchases, diary: diary)) {
                Button("Zrušit za \(PointsService.passCost) bodů bez postihu") {
                    withAnimation { PointsService.redeem(task) }
                }
            }
            Button("Přeskočit a vysvětlit", role: .destructive) { excuse = ExcuseRequest(task: task, kind: .skipped) }
        }
        .sheet(item: $detailTask) { TaskDetailView(task: $0) }
        .sheet(isPresented: $showsShop) { ShopView() }
        // Every rise of the balance gets a short celebration: completing, partial completion, a milestone bonus.
        .onChange(of: PointsService.balance(tasks, purchases: purchases, diary: diary)) { old, new in
            if new > old { pointsGain = PointsGain(amount: new - old) }
        }
        .overlay(alignment: .bottom) {
            if let pointsGain {
                PointsGainToast(amount: pointsGain.amount) { self.pointsGain = nil }
                    .id(pointsGain.id)
                    .padding(.bottom, 24)
                    .allowsHitTesting(false)
            }
        }
        .sensoryFeedback(.success, trigger: pointsGain?.id) { _, new in new != nil }
        // A moment to be honest before anything counts as done.
        .alert("Opravdu jsi to splnil podle plánu?",
               isPresented: Binding(get: { confirmDone != nil }, set: { if !$0 { confirmDone = nil } }),
               presenting: confirmDone) { task in
            Button("Ano, splnil jsem") { complete(task) }
            if !task.isMissed(.now) {
                Button("Jen částečně") { partialTask = task }
            }
            Button("Zrušit", role: .cancel) {}
        } message: { task in
            Text("\(task.title) · \(task.plannedMinutes) min\n\nBuď k sobě upřímný. Podvedl bys jen sám sebe.")
        }
        .fullScreenCover(item: $focusTask, onDismiss: {
            if let task = completeAfterFocus {
                completeAfterFocus = nil
                confirmDone = task
            }
        }) { task in
            FocusView(task: task) { completeAfterFocus = task }
        }
        .fullScreenCover(item: $gymTimerTask, onDismiss: {
            if let task = completeAfterFocus {
                completeAfterFocus = nil
                confirmDone = task
            }
        }) { task in
            GymTimerView(task: task) { completeAfterFocus = task }
        }
    }

    private var postponeLimit: Int { settingsList.first?.postponeLimit ?? UserSettings.postponeLimitRange.upperBound }
    private var postponesLeft: Int {
        max(0, postponeLimit + PointsService.extraPostponements(purchases) - PlanService.postponementsUsed(postponements))
    }

    /// Skipping first offers a penalty-free postponement while the month's allowance lasts.
    private func giveUp(on task: TaskItem, now: Date) {
        if task.isMissed(now) {
            excuse = ExcuseRequest(task: task, kind: .missed)
        } else if (postponesLeft > 0 && !task.isRecovery) || PointsService.canRedeem(task, balance: PointsService.balance(tasks, purchases: purchases, diary: diary), now: now) {
            failChoice = task
        } else {
            excuse = ExcuseRequest(task: task, kind: .skipped)
        }
    }

    /// Gym tasks ask what was trained and proof tasks ask for proof before they count as done.
    private func complete(_ task: TaskItem, share: Double = 1, note: String = "") {
        // Set on every attempt, so a cancelled partial completion never leaks into a later full one.
        task.completionShare = share
        task.partialNote = note
        if task.category == .gym {
            workoutTask = task
        } else if task.requiresProof {
            proofTask = task
        } else {
            withAnimation { task.markDone() }
        }
    }

    private func showsBrief(_ day: TodaySnapshot, now: Date) -> Bool {
        settingsList.first?.morningBriefEnabled != false
            && !day.visible.isEmpty
            && now.minutesIntoDay < Self.briefVisibleUntilHour * 60
            && briefDismissedDay != now.startOfDay.timeIntervalSince1970
    }

    /// From the configured time on, as long as something is still open today.
    private func showsRealityCheckCard(_ day: TodaySnapshot, now: Date) -> Bool {
        guard let settings = settingsList.first, settings.realityCheckEnabled else { return false }
        return now.minutesIntoDay >= settings.realityCheckMinutes && !(day.critical + day.open).isEmpty
    }

    private func content(now: Date) -> some View {
        let day = TodaySnapshot(tasks: tasks, plans: plans, targets: settingsList.first?.weeklyTargets ?? [:], now: now)
        let slipping = isSlipping(day, now: now)
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                header(now: now, streak: day.streak)
                if slipping {
                    slippingBanner(day)
                }
                streakCard(day, now: now)
                insuranceUsedCard(now: now)
                if showsBrief(day, now: now) {
                    MorningBriefCard(tasks: tasks, todayTasks: day.visible, promisesKeptThisWeek: day.promisesKept,
                                     streak: day.streak, now: now) {
                        withAnimation { briefDismissedDay = now.startOfDay.timeIntervalSince1970 }
                    }
                }
                if let pending = ReflectionRequest.pending(tasks: tasks, reflections: reflections, now: now) {
                    reflectionCard(pending)
                }
                comebackCard(day, now: now)
                stakeCards(now: now)
                healthWorkoutCard(day)
                hero(day)
                metrics(day)
                pointsCard
                if showsRealityCheckCard(day, now: now) {
                    realityCheckCard
                }
                if !day.weekIsCommitted {
                    uncommittedCard
                }
                if !day.unresolved.isEmpty {
                    section("Nevyřešené — \(day.unresolved.count)", color: Theme.red, tasks: day.unresolved, now: now)
                }
                if !day.critical.isEmpty {
                    section("Kritické", tasks: day.critical, now: now)
                }
                if !day.open.isEmpty {
                    section("Úkoly", tasks: day.open, now: now)
                }
                suggestionsSection(now: now)
                if !day.closed.isEmpty {
                    section("Uzavřené", tasks: day.closed, now: now)
                }
                if day.visible.isEmpty && day.unresolved.isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 32)
        }
        .background(alignment: .top) {
            // Savage tone only: a quiet dark-red wash at the top while the day is being lost.
            LinearGradient(colors: [Theme.red.opacity(slipping ? 0.22 : 0), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 340)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: slipping)
        }
    }

    /// The failure state exists only in the savage tone and only when the day is really going wrong:
    /// several critical tasks overdue or all of them lost, or under 50 % by the evening.
    private func isSlipping(_ day: TodaySnapshot, now: Date) -> Bool {
        guard settingsList.first?.tone == .savage else { return false }
        let critical = day.scored.filter { $0.scoringPriority == .critical && !$0.isRemoved }
        let overdue = critical.filter { $0.isOverdue(now) }.count
        let allCriticalGone = critical.count >= Self.slippingCriticalCount
            && critical.allSatisfy { $0.isLost(now) || $0.isOverdue(now) }
        let weakEvening = now.minutesIntoDay >= Self.slippingAfterMinutes
            && !day.scored.isEmpty && (day.productivity ?? 0) < Theme.poorThreshold
        return overdue >= Self.slippingCriticalCount || allCriticalGone || weakEvening
    }

    private func slippingBanner(_ day: TodaySnapshot) -> some View {
        let critical = day.scored.filter { $0.scoringPriority == .critical && !$0.isRemoved }
        return VStack(alignment: .leading, spacing: 6) {
            Text("DNEŠEK TI UTÍKÁ")
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(Theme.red)
            if !critical.isEmpty {
                Text("KRITICKÉ ÚKOLY \(critical.filter(\.isDone).count) / \(critical.count)")
                    .labelStyle(Theme.red)
            }
        }
    }

    private func header(now: Date, streak: Int) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DNES").labelStyle()
                Text(now.longDayText)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            // Days in a row at 80 % or better. Lit only while the streak is alive.
            VStack(spacing: 0) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 30))
                    .symbolEffect(.bounce, options: .nonRepeating, value: streak)
                Text("\(streak)")
                    .font(.system(size: 17, weight: .heavy))
                    .contentTransition(.numericText())
            }
            .foregroundStyle(streak > 0 ? Theme.orange : Theme.textTertiary)
            .animation(.easeOut(duration: 0.4), value: streak)
        }
    }

    /// The broken streak that is currently offered for buying back, if any.
    private func repairOffer(now: Date) -> StreakService.Broken? {
        guard let broken = StreakService.broken(tasks, now: now), broken.canRepair(now: now),
              streakOfferDismissed != broken.brokenOn.timeIntervalSince1970 else { return nil }
        return broken
    }

    /// Yesterday under 60 %: today is a comeback until it is back above 80 %.
    private func comeback(_ day: TodaySnapshot, now: Date) -> (yesterday: Double, today: Double, succeeded: Bool)? {
        let yesterdayTasks = tasks.filter { $0.scheduledDate.isSameDay(as: now.startOfDay.addingDays(-1)) }
        guard let yesterday = ScoreEngine.productivity(yesterdayTasks, now: now), yesterday < Self.comebackThreshold else { return nil }
        let today = day.productivity ?? 0
        return (yesterday, today, today >= ScoreEngine.Config.streakThreshold)
    }

    /// For a few days after the streak breaks it can be bought back with points.
    /// A bad yesterday is part of the same story, so the comeback is folded into this card instead of a second one.
    @ViewBuilder
    private func streakCard(_ day: TodaySnapshot, now: Date) -> some View {
        if let broken = repairOffer(now: now) {
            let balance = PointsService.balance(tasks, purchases: purchases, diary: diary)
            let cost = broken.cost
            VStack(alignment: .leading, spacing: 12) {
                Label("SÉRIE SKONČILA", systemImage: "flame.fill").labelStyle(Theme.orange)
                Text("Měl jsi \(String.days(broken.length)) v řadě.")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                // The day text already ends with a full stop ("so 10.").
                Text("Přerušeno: \(broken.failedDays.map(\.shortDayText).joined(separator: ", ")) "
                     + "Za \(cost.formatted(.number.locale(.app))) bodů ji vrátíš, jako by se nepřerušila.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                streakCountdown(until: broken.repairEnds, now: now)
                if balance < cost {
                    Text("Máš \(balance.formatted(.number.locale(.app))) bodů, chybí ti \((cost - balance).formatted(.number.locale(.app))).")
                        .font(.system(size: 13, weight: .semibold))
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
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        Spacer()
                        if !comeback.succeeded {
                            Button("RECOVERY ÚKOL") { editor = EditorRequest(date: now, isRecovery: true) }
                                .font(.system(size: 12, weight: .bold))
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
    private func insuranceUsedCard(now: Date) -> some View {
        let yesterday = now.startOfDay.addingDays(-1)
        if purchases.contains(where: { $0.kind == .streakInsurance && $0.usedOn == yesterday }) {
            HStack(spacing: 12) {
                Image(systemName: ShopItem.streakInsurance.symbol)
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text("POJISTKA SÉRIE POUŽITA").labelStyle(Theme.orange)
                    Text("Včerejšek nevyšel, plamínek ale hoří dál. Zbývá pojistek: \(PointsService.unused(.streakInsurance, in: purchases)).")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .card()
        }
    }

    /// Live countdown to the end of the buy-back offer; turns red in the last hours.
    private func streakCountdown(until end: Date, now: Date) -> some View {
        let color = end.timeIntervalSince(now) < Self.streakUrgentSeconds ? Theme.red : Theme.orange
        return HStack(spacing: 6) {
            Image(systemName: "timer")
            Text("NABÍDKA KONČÍ ZA")
                .tracking(0.6)
            Text(timerInterval: min(now, end)...end, countsDown: true)
                .monospacedDigit()
        }
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.14))
        .clipShape(Capsule())
    }

    private func hero(_ day: TodaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // A new user starts with a clean record, not with dashes.
            Text("\(day.accountability?.score ?? ScoreEngine.startingScore)")
                .font(.system(size: 72, weight: .heavy))
                .foregroundStyle(day.accountability == nil ? Theme.green : heroColor(day.accountability?.score))
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.6), value: day.accountability?.score)
            HStack(spacing: 8) {
                Text("SPOLEHLIVOST").labelStyle()
                if day.accountability == nil {
                    Badge(text: "Čistý štít", color: Theme.green)
                }
            }
            Text(day.accountability?.subtitle ?? "Startuješ na plných 100. Zatím jsi nic neporušil. Odešli plánovač na týden a udrž to tak.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 4)
        }
    }

    private func heroColor(_ score: Int?) -> Color {
        guard let score else { return Theme.textTertiary }
        return Double(score) / 100 < Theme.poorThreshold ? Theme.red : Theme.textPrimary
    }

    private func metrics(_ day: TodaySnapshot) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                MetricTile(value: day.freshValue(day.promisesKept), label: "Dodržené sliby")
                MetricTile(value: day.freshValue(day.productivity), label: "Produktivita")
                MetricTile(value: "\(day.streak)", label: "Série dní")
            }
            if !day.scored.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Text("\(day.doneCount) / \(day.scored.count)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("ÚKOLŮ SPLNĚNO").labelStyle()
                        if day.partialCount > 0 {
                            Text("z toho částečně: \(day.partialCount)")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.orange)
                        }
                        Spacer()
                    }
                    ThinBar(value: Double(day.doneCount) / Double(day.scored.count),
                            color: day.doneCount == day.scored.count && day.partialCount == 0 ? Theme.green : Theme.textPrimary)
                }
            }
        }
    }

    private var uncommittedCard: some View {
        Button(action: openWeek) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TENTO TÝDEN BEZ ZÁVAZKU").labelStyle(Theme.orange)
                    Text("Dokud neodešleš plánovač a nezapečetí se, nic z toho, co uděláš, se nepočítá jako dodržený slib.")
                        .font(.system(size: 14))
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

    private func declinedToday(_ now: Date) -> Set<String> {
        let parts = declinedSuggestions.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, parts[0] == "\(now.daySeed)" else { return [] }
        return Set(parts[1].split(separator: ",").map(String.init))
    }

    /// Today's suggestions without the ones declined for the day.
    private func visibleSuggestions(now: Date) -> [Suggestion] {
        let declined = declinedToday(now)
        let settings = settingsList.first
        return SuggestionService.suggestions(
            tasks: tasks,
            workoutPresets: settings?.workoutPresets ?? UserSettings.defaultWorkoutPresets,
            now: now,
            target: { settings?.weeklyTarget(for: $0) ?? $0.defaultWeeklyTarget }
        ).filter { !declined.contains($0.category.rawValue) }
    }

    @ViewBuilder
    private func suggestionsSection(now: Date) -> some View {
        let declined = declinedToday(now)
        let suggestions = visibleSuggestions(now: now)
        if !suggestions.isEmpty {
            VStack(spacing: 10) {
                SectionLabel(text: "Návrhy")
                ForEach(suggestions) { suggestion in
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Label(suggestion.category.suggestionTitle, systemImage: suggestion.category.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text(suggestion.reason)
                                .font(.system(size: 13))
                                .foregroundStyle(suggestion.isUrgent ? Theme.orange : Theme.textSecondary)
                            if let hint = suggestion.hint {
                                Text(hint)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            Text("+\(PointsService.perSuggestion) bodů za splnění")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.green)
                        }
                        HStack(spacing: 10) {
                            Button("PŘIDAT NA DNES") {
                                editor = EditorRequest(date: now, suggestion: suggestion.category)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            Button("DNES NE") {
                                let all = declined.union([suggestion.category.rawValue])
                                withAnimation { declinedSuggestions = "\(now.daySeed):\(all.sorted().joined(separator: ","))" }
                            }
                            .buttonStyle(SecondaryButtonStyle(textColor: Theme.textSecondary))
                        }
                    }
                    .card()
                }
            }
        }
    }

    /// After a day under 60 %, today is framed as a comeback: orange until today is back above 80 %.
    /// While the streak buy-back card is shown, the comeback lives inside that one.
    @ViewBuilder
    private func comebackCard(_ day: TodaySnapshot, now: Date) -> some View {
        if repairOffer(now: now) == nil, let comeback = comeback(day, now: now) {
            let color = comeback.succeeded ? Theme.green : Theme.orange
            VStack(alignment: .leading, spacing: 14) {
                Text(comeback.succeeded ? "COMEBACK SE POVEDL" : "COMEBACK DAY").labelStyle(color)
                HStack(spacing: 28) {
                    comebackFigure("Včera", comeback.yesterday.percentText, Theme.textSecondary)
                    comebackFigure("Dnes", comeback.today.percentText, color)
                }
                Text(comeback.succeeded ? "Včerejšek jsi nezměnil. Dnešek ano." : "Včerejšek nezměníš. Dnešek ano.")
                    .font(.system(size: 16, weight: .semibold))
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

    private func comebackFigure(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).labelStyle()
            Text(value)
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(color)
        }
    }

    /// After failing a task with a stake on it, asks whether the stake was honoured.
    @ViewBuilder
    private func stakeCards(now: Date) -> some View {
        let since = now.startOfDay.addingDays(-Self.stakeQuestionDays)
        let open = tasks.filter {
            !$0.stake.isEmpty && $0.stakeOutcome == 0 && $0.scheduledDate >= since
                && ($0.status == .skipped || $0.status == .failed)
        }
        ForEach(open) { task in
            VStack(alignment: .leading, spacing: 12) {
                Text("SÁZKA").labelStyle(Theme.orange)
                Text("Nesplnil jsi „\(task.title)“. Vsadil ses o tohle:")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                Text("„\(task.stake)“")
                    .font(.system(size: 17, weight: .semibold))
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
    private func healthWorkoutCard(_ day: TodaySnapshot) -> some View {
        let gymToday = day.visible.filter { $0.category == .gym }
        // Nothing to offer once a gym workout is logged today.
        if let minutes = healthGymMinutes, !gymToday.contains(where: \.isDone) {
            let planned = gymToday.first { $0.status == .pending }
            VStack(alignment: .leading, spacing: 12) {
                Label("APPLE HEALTH", systemImage: "heart.fill").labelStyle(Theme.green)
                Text(planned.map { "Dnes máš zaznamenaný trénink (\(minutes) min). Zapiš, co jsi jel, a „\($0.title)“ je splněný." }
                     ?? "Dnes máš zaznamenaný trénink (\(minutes) min), i když jsi ho neměl v plánu. Zapiš ho, ať se počítá.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("ZAPSAT TRÉNINK") { complete(planned ?? addUnplannedGym(minutes: minutes)) }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .card()
        }
    }

    /// A workout Health recorded without a planned task still gets tracked: it becomes today's gym task.
    private func addUnplannedGym(minutes: Int) -> TaskItem {
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
    private var pointsCard: some View {
        let balance = PointsService.balance(tasks, purchases: purchases, diary: diary)
        let passes = balance / PointsService.passCost
        let towardsNext = balance % PointsService.passCost
        let isFull = balance >= PointsService.cap
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(balance.formatted(.number.locale(.app)))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
                Text("/ \(PointsService.cap.formatted(.number.locale(.app))) BODŮ").labelStyle()
                Spacer()
                Button {
                    showsShop = true
                } label: {
                    Label("OBCHOD", systemImage: "bag.fill")
                        .font(.system(size: 12, weight: .bold))
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
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
        }
        .animation(.easeOut(duration: 0.4), value: balance)
    }

    private func reflectionCard(_ pending: ReflectionRequest) -> some View {
        Button {
            reflection = pending
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SEBEREFLEXE TÝDNE \(pending.weekStart.weekNumber)").labelStyle(Theme.textPrimary)
                    Text("Projdi si týden a zapiš do deníčku, jak jsi se sebou spokojený.")
                        .font(.system(size: 14))
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

    private var realityCheckCard: some View {
        Button {
            showsRealityCheck = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("VEČERNÍ BILANCE").labelStyle(Theme.orange)
                    Text("Den končí a ty máš pořád otevřené závazky.")
                        .font(.system(size: 14))
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

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Na dnešek nemáš nic v plánu.")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Den bez závazků nejde dodržet ani porušit.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
        }
        .card()
    }

    private func section(_ title: String, color: Color = Theme.textSecondary, tasks: [TaskItem], now: Date) -> some View {
        VStack(spacing: 10) {
            SectionLabel(text: title, color: color)
            ForEach(tasks) { task in
                TaskCard(
                    task: task,
                    now: now,
                    warning: PatternDetectionService.warning(for: task, tasks: self.tasks, failures: failures, now: now),
                    onTap: {
                        if task.status == .pending, !task.isMissed(now) {
                            editor = EditorRequest(task: task)
                        } else {
                            detailTask = task
                        }
                    },
                    onDone: { confirmDone = task },
                    onFail: { giveUp(on: task, now: now) },
                    onFocus: {
                        if task.category == .gym {
                            // The workout starts before the screen opens, so nothing on this screen
                            // changes under the opening animation.
                            _ = task.startFocusIfNeeded(in: context)
                            gymTimerTask = task
                        } else {
                            focusTask = task
                        }
                    },
                    onPartial: { partialTask = task }
                )
                .contextMenu {
                    if task.canReopen(now: now) {
                        Button("Změnit rozhodnutí") { withAnimation { task.reopen() } }
                    }
                }
            }
        }
    }
}

/// Everything the Today screen shows, derived once per render.
private struct TodaySnapshot {
    let scored: [TaskItem]
    let visible: [TaskItem]
    let unresolved: [TaskItem]
    let critical: [TaskItem]
    let open: [TaskItem]
    let closed: [TaskItem]
    let accountability: ScoreEngine.Accountability?
    let promisesKept: Double?
    let productivity: Double?
    let streak: Int
    let weekIsCommitted: Bool

    var doneCount: Int { scored.filter(\.isDone).count }

    /// Before anything was ever closed there is nothing to measure yet, so the record shows as clean (100 %).
    func freshValue(_ value: Double?) -> String {
        value == nil && accountability == nil ? 1.0.percentText : value.percentText
    }
    var partialCount: Int { scored.filter(\.isPartial).count }

    init(tasks: [TaskItem], plans: [WeeklyPlan], targets: [TaskCategory: Int], now: Date) {
        let weekStart = now.weekStart
        scored = tasks.filter { $0.scheduledDate.isSameDay(as: now) && $0.countsInScores }
        visible = scored.filter { !$0.isRemoved }
        unresolved = tasks.filter { $0.isMissed(now) }.sorted { $0.scheduledDate > $1.scheduledDate }

        let pending = visible.filter { $0.status == .pending }.sorted {
            $0.dueDate == $1.dueDate ? $0.priority.rank > $1.priority.rank : $0.dueDate < $1.dueDate
        }
        critical = pending.filter { $0.priority == .critical }
        open = pending.filter { $0.priority != .critical }
        closed = visible.filter { $0.status != .pending }

        accountability = ScoreEngine.accountability(tasks: tasks, plans: plans, targets: targets, now: now)
        promisesKept = ScoreEngine.promisesKept(tasks.filter { $0.scheduledDate.weekStart == weekStart }, now: now)
        productivity = ScoreEngine.productivity(scored, now: now)
        streak = ScoreEngine.dayStreak(tasks, now: now)
        // A plan that is handed in and waiting to be sealed is as good as committed here.
        weekIsCommitted = plans.first { $0.weekStart == weekStart }.map { $0.isCommitted || $0.isSealing } ?? false
    }
}
