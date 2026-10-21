import SwiftUI
import SwiftData

struct WeekView: View {
    @Query(sort: \WeeklyPlan.weekStart) private var plans: [WeeklyPlan]
    @Query private var tasks: [TaskItem]
    @Query private var settingsList: [UserSettings]
    @Binding var showsNextWeek: Bool
    @State private var editor: EditorRequest?
    @State private var planToCommit: WeeklyPlan?
    @State private var showsQuickPlan = false
    @State private var detailTask: TaskItem?
    /// Events of the shown week from the iPhone calendar, when that is switched on.
    @State private var calendarEvents: [CalendarService.Event] = []
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Newly planned tasks fly into the send button, so it is clear the plan still has to be sent.
    @State private var knownTaskIDs: Set<UUID> = []
    @State private var knownWeekStart: Date?
    @State private var flights: [PlanFlight] = []
    /// Not observed: the frames change on every scroll and only matter when something flies.
    @State private var flightFrames = FlightFrameStore()
    @State private var commitPulse = 0
    @State private var landedCount = 0
    /// Where the next flight starts instead of the rows, for example the copy tile.
    @State private var flightOrigin: CGPoint?
    @State private var confirmsCopy = false
    @State private var nothingToCopy = false
    @State private var confirmsReset = false

    /// Last week's plan, offered as a starting point until the shown week is handed in.
    /// The week can still take tasks copied from the one before.
    private var canCopyWeek: Bool {
        plan?.isCommitted != true && plan?.isSealing != true && Date.now < weekStart.addingDays(7)
    }

    private var planToCopy: WeeklyPlan? {
        guard canCopyWeek,
              let previous = plans.first(where: { $0.weekStart == weekStart.addingDays(-7) }),
              !previous.committableTasks.isEmpty else { return nil }
        return previous
    }

    private var weekStart: Date { Date.now.weekStart.addingDays(showsNextWeek ? 7 : 0) }
    private var plan: WeeklyPlan? { plans.first { $0.weekStart == weekStart } }
    private var days: [Date] { (0..<7).map { weekStart.addingDays($0) } }

    private var goals: [WeeklyGoal] {
        let settings = settingsList.first
        return SuggestionService.goals(tasks: tasks, weekStart: weekStart) {
            settings?.weeklyTarget(for: $0) ?? $0.defaultWeeklyTarget
        }
    }

    private var weeklyTotal: (planned: Int, done: Int, minimum: Int)? {
        let minimum = settingsList.first?.minimumWeeklyTasks ?? UserSettings.defaultMinimumWeeklyTasks
        guard minimum > 0 else { return nil }
        let week = (plan?.committableTasks ?? [])
        return (week.count, week.filter(\.isDone).count, minimum)
    }

    private var canCommit: Bool {
        guard let plan else { return false }
        return !plan.isCommitted && !plan.isSealing && !plan.pledgeableTasks().isEmpty && Date.now < plan.weekEnd
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                    header
                    statusCard
                    if Date.now < weekStart.addingDays(7) {
                        PlanStartCard(previousWeek: weekStart.addingDays(-7).weekNumber,
                                      onQuick: { showsQuickPlan = true },
                                      onSingle: { editor = EditorRequest(date: max(Date.now, weekStart)) },
                                      onCopy: { if planToCopy == nil { nothingToCopy = true } else { confirmsCopy = true } },
                                      onReset: resettableTasks.isEmpty ? nil : { confirmsReset = true })
                    }
                    if !goals.isEmpty || weeklyTotal != nil {
                        WeeklyGoalsCard(goals: goals, total: weeklyTotal)
                    }
                    if !showsNextWeek, plan?.tasks.isEmpty == false {
                        NavigationLink {
                            WeeklyReviewView(weekStart: weekStart)
                        } label: {
                            HStack {
                                Text("PŘEHLED TÝDNE").labelStyle(Theme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
                            }
                            .card()
                        }
                    }
                    VStack(spacing: 20) {
                        ForEach(days, id: \.self) { day in
                            daySection(day)
                        }
                    }
                    if let plan, plan.isCommitted {
                        PlanChangesView(plan: plan)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 32)
            }
            .screenBackground()
            .safeAreaInset(edge: .bottom) {
                if canCommit, let plan {
                    Button("ZKONTROLOVAT A ODESLAT PLÁNOVAČ") { planToCommit = plan }
                        .buttonStyle(PrimaryButtonStyle())
                        .overlay(alignment: .topTrailing) {
                            if landedCount > 0 {
                                Text("+\(landedCount)")
                                    .font(.system(size: 13, weight: .heavy))
                                    .foregroundStyle(Color(hex: 0x000000))
                                    .padding(.horizontal, 8)
                                    .frame(minHeight: 24)
                                    .background(Theme.green)
                                    .clipShape(Capsule())
                                    .offset(x: 6, y: -10)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .scaleEffect(commitPulse % 2 == 1 ? 1.05 : 1)
                        .shadow(color: Theme.green.opacity(commitPulse % 2 == 1 ? 0.5 : 0), radius: 14)
                        .flightFrame(FlightFramesKey.commitButton)
                        .padding(.horizontal, Theme.screenPadding)
                        .padding(.vertical, 12)
                        .background(Theme.background)
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
        }
        .onPreferenceChange(FlightFramesKey.self) { flightFrames.frames = $0 }
        .overlay {
            GeometryReader { proxy in
                let origin = proxy.frame(in: .global).origin
                ZStack {
                    ForEach(flights) { flight in
                        FlyingIcon(flight: flight, origin: origin)
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .sensoryFeedback(.success, trigger: commitPulse) { _, new in new % 2 == 1 }
        .onAppear { rememberTasks() }
        .onChange(of: openTaskIDs) { launchFlights() }
        .onChange(of: isPresenting) { _, presenting in
            guard !presenting else { return }
            // Let the sheet slide away and the new rows settle before anything flies.
            Task {
                try? await Task.sleep(for: .seconds(0.45))
                launchFlights()
            }
        }
        .sheet(item: $editor) { TaskEditorView(task: $0.task, defaultDate: $0.date, suggestion: $0.suggestion) }
        .sheet(item: $planToCommit) { CommitSummaryView(plan: $0) }
        .sheet(item: $detailTask) { TaskDetailView(task: $0) }
        .modifier(PlanningDialogs(view: self))
        .task(id: "\(weekStart)-\(settingsList.first?.calendarEnabled == true)-\(scenePhase == .active)") {
            calendarEvents = settingsList.first?.calendarEnabled == true
                ? CalendarService.events(from: weekStart, to: weekStart.addingDays(7)) : []
        }
    }

    // MARK: Planning dialogs

    fileprivate func planningDialogs<Content: View>(_ content: Content) -> some View {
        content
        .sheet(isPresented: $showsQuickPlan) {
            QuickPlanView(weekStart: weekStart) {
                showsQuickPlan = false
                guard let plan else { return }
                Task {
                    try? await Task.sleep(for: .seconds(0.5))
                    planToCommit = plan
                }
            }
        }
        // What was planned in Rychlé plánování already flew there, so it does not fly again here.
        .onChange(of: showsQuickPlan) { _, isShown in if !isShown { rememberTasks() } }
        .alert("Naplánovat jako minulý týden?", isPresented: $confirmsCopy) {
            Button("Zkopírovat týden \(weekStart.addingDays(-7).weekNumber)") {
                guard let planToCopy else { return }
                if let tile = flightFrames.frames[PlanStartCard.copyTile] {
                    flightOrigin = CGPoint(x: tile.midX, y: tile.midY)
                }
                // Copy once the question has gone, so the icons fly over a clear screen.
                Task {
                    try? await Task.sleep(for: .seconds(0.35))
                    withAnimation { _ = PlanService.copyWeek(planToCopy, in: context) }
                }
            }
            Button("Zpět", role: .cancel) {}
        } message: {
            Text("Úkoly z týdne \(weekStart.addingDays(-7).weekNumber) se naplánují na stejné dny tohoto týdne. Co už tu ten den máš pod stejným názvem, se nezdvojí. Pořád je to jen návrh, upravíš ho a pak odešleš.")
        }
        .alert("Minulý týden jsi nic neměl", isPresented: $nothingToCopy) {
            Button("Rozumím", role: .cancel) {}
        } message: {
            Text("V týdnu \(weekStart.addingDays(-7).weekNumber) nemáš žádné úkoly, takže není co kopírovat. Začni Rychlým plánováním nebo jedním úkolem.")
        }
        .alert("Začít plán znovu?", isPresented: $confirmsReset) {
            Button("Vymazat naplánované", role: .destructive) { resetPlan() }
            Button("Nechat, jak je", role: .cancel) {}
        } message: {
            Text("Všechny úkoly, které tu ještě čekají, zmizí a můžeš plánovat od nuly. Splněné zůstanou. Plán ještě není odeslaný, takže to nic nestojí.")
        }
    }

    // MARK: Planning flight

    private var openTaskIDs: Set<UUID> { Set((plan?.activeTasks ?? []).filter { $0.status == .pending }.map(\.uid)) }
    private var isPresenting: Bool { showsQuickPlan || editor != nil || planToCommit != nil || detailTask != nil }

    /// The draft's tasks that a fresh start clears: open ones that are not done yet.
    private var resettableTasks: [TaskItem] {
        guard canCopyWeek, let plan else { return [] }
        return plan.activeTasks.filter { $0.status == .pending && $0.scheduledDate.endOfDay > Date.now }
    }

    private func resetPlan() {
        withAnimation {
            for task in resettableTasks { PlanService.remove(task, in: context) }
        }
        try? context.save()
        rememberTasks()
    }

    private func rememberTasks() {
        knownTaskIDs = openTaskIDs
        knownWeekStart = weekStart
    }

    /// Sends every task planned since the last look into the send button, one after another.
    private func launchFlights() {
        guard knownWeekStart == weekStart else { return rememberTasks() }
        guard !isPresenting else { return }
        let added = openTaskIDs.subtracting(knownTaskIDs)
        knownTaskIDs = openTaskIDs
        guard !added.isEmpty else { return }
        fly(added, attempt: 0)
    }

    /// In an empty week the send button only appears with the first task, so wait for it a moment.
    private func fly(_ added: Set<UUID>, attempt: Int) {
        guard canCommit, let target = flightFrames.frames[FlightFramesKey.commitButton] else {
            guard attempt < 5 else { return }
            Task {
                try? await Task.sleep(for: .seconds(0.12))
                fly(added, attempt: attempt + 1)
            }
            return
        }
        let newTasks = (plan?.activeTasks ?? []).filter { added.contains($0.uid) }.sorted { $0.dueDate < $1.dueDate }
        let screen = UIScreen.main.bounds
        let fallback = CGPoint(x: screen.midX, y: screen.height * 0.4)
        let stagger = 0.07
        let shown = Array(newTasks.prefix(12))
        if !reduceMotion {
            let launched = shown.enumerated().map { index, task -> PlanFlight in
                let row = flightFrames.frames[task.uid.uuidString]
                let start = flightOrigin
                    ?? row.flatMap { screen.intersects($0) ? CGPoint(x: $0.minX + 34, y: $0.midY) : nil }
                    ?? fallback
                return PlanFlight(icon: task.icon, from: start, to: CGPoint(x: target.midX, y: target.midY),
                                  delay: Double(index) * stagger)
            }
            flights.append(contentsOf: launched)
        }
        flightOrigin = nil
        let landing = reduceMotion ? 0 : PlanFlight.duration + Double(shown.count - 1) * stagger
        let ids = Set(flights.map(\.id))
        Task {
            try? await Task.sleep(for: .seconds(landing))
            withAnimation(.spring(duration: 0.3)) {
                commitPulse += 1
                landedCount = newTasks.count
            }
            flights.removeAll { ids.contains($0.id) }
            try? await Task.sleep(for: .seconds(0.35))
            withAnimation(.spring(duration: 0.4)) { commitPulse += 1 }
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeOut(duration: 0.3)) { landedCount = 0 }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TÝDEN \(weekStart.weekNumber)").labelStyle()
                Text("\(weekStart.dayMonthText) – \(weekStart.addingDays(6).dayMonthText)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Picker("Týden", selection: $showsNextWeek) {
                Text("Tento týden").tag(false)
                Text("Příští týden").tag(true)
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var statusCard: some View {
        if let plan, let committedAt = plan.committedAt {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("ZAPEČETĚNO", systemImage: "checkmark.seal.fill").labelStyle(Theme.textPrimary)
                        Text("Závazky: \(plan.committedTasks.count) · \(committedAt.stampText)")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    if let share = SealedWeekShare(plan: plan) {
                        ShareLink(item: share, preview: SharePreview("Kept – týden \(share.weekNumber)",
                                                                     image: Image(systemName: "checkmark.seal.fill"))) {
                            Label("SDÍLET", systemImage: "square.and.arrow.up")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(0.6)
                                .foregroundStyle(Theme.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Theme.cardRaised)
                                .clipShape(Capsule())
                        }
                    }
                }
                PerformanceBar(label: "Dodržené sliby", value: ScoreEngine.promisesKept(plan.tasks))
                PerformanceBar(label: "Věrnost plánu", value: ScoreEngine.commitmentIntegrity(plan))
            }
            .card()
            .transition(.scale(scale: 0.94).combined(with: .opacity))
        } else if let plan, let sealDate = plan.sealDate, let submittedAt = plan.submittedAt {
            SealingCard(plan: plan, submittedAt: submittedAt, sealDate: sealDate,
                        minimum: settingsList.first?.minimumWeeklyTasks ?? UserSettings.defaultMinimumWeeklyTasks)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("BEZ ZÁVAZKU").labelStyle(Theme.orange)
                Text(plan?.activeTasks.isEmpty == false
                     ? "Zatím je to jen návrh. Slibem se stane, až ho odešleš a zapečetí se."
                     : "Naplánuj si týden a pak odešli plánovač.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
            }
            .card()
        }
    }

    private func daySection(_ day: Date) -> some View {
        let tasks = (plan?.activeTasks ?? [])
            .filter { $0.scheduledDate.isSameDay(as: day) }
            .sorted { $0.dueDate == $1.dueDate ? $0.priority.rank > $1.priority.rank : $0.dueDate < $1.dueDate }
        let isPast = day.endOfDay <= Date.now
        let isToday = day.isSameDay(as: .now)

        return VStack(spacing: 8) {
            HStack {
                Text(day.shortDayText.uppercased())
                    .labelStyle(isToday ? Theme.textPrimary : Theme.textSecondary)
                Spacer()
                if !isPast {
                    Button {
                        editor = EditorRequest(date: day)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 32, height: 24)
                    }
                }
            }
            let events = calendarEvents.filter { $0.start < day.endOfDay && $0.end > day.startOfDay }
            if !events.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(events) { event in
                        Label(event.summary, systemImage: "calendar")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if tasks.isEmpty {
                Text("Žádné závazky")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        if index > 0 {
                            Divider().overlay(Theme.border)
                        }
                        WeekTaskRow(task: task)
                            .flightFrame(task.uid.uuidString)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if task.status == .pending, !task.isMissed(.now) {
                                    editor = EditorRequest(task: task)
                                } else {
                                    detailTask = task
                                }
                            }
                    }
                }
                .card(padding: 0)
            }
        }
    }
}

/// The handed-in plan ("plánovač") on its way to being sealed: a ring that empties over the hour.
private struct SealingCard: View {
    let plan: WeeklyPlan
    let submittedAt: Date
    let sealDate: Date
    let minimum: Int
    @State private var confirmsWithdraw = false
    @State private var reviewsSealNow = false
    /// Day of the overview whose tasks are listed underneath. Monday until the user picks another one.
    @State private var selectedDay: Date?

    private static let maxIconsPerDay = 3
    private static let ringSize: CGFloat = 148
    private static let ringWidth: CGFloat = 8

    var body: some View {
        VStack(spacing: 18) {
            Label("PLÁNOVAČ ČEKÁ NA ZAPEČETĚNÍ", systemImage: "calendar.badge.clock").labelStyle(Theme.orange)
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let total = sealDate.timeIntervalSince(submittedAt)
                let left = max(sealDate.timeIntervalSince(timeline.date), 0)
                ZStack {
                    Circle().stroke(Theme.cardRaised, lineWidth: Self.ringWidth)
                    Circle().trim(from: 0, to: total > 0 ? left / total : 0)
                        .stroke(Theme.orange, style: StrokeStyle(lineWidth: Self.ringWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: left)
                    VStack(spacing: 4) {
                        Image(systemName: left > 0 ? "lock.open.fill" : "lock.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.orange)
                        Text(FocusView.clock(left))
                            .font(.system(size: 30, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                        Text("DO ZAPEČETĚNÍ")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(width: Self.ringSize, height: Self.ringSize)
            }
            VStack(spacing: 6) {
                Text("Závazky v plánovači: \(plan.pledgeableTasks(sealDate).count)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                if closedCount > 0 {
                    Text("Už uzavřené úkoly: \(closedCount). Do závazku se nepočítají, jen do produktivity.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Zapečetí se sám v \(sealDate.timeText). Do té doby můžeš plán měnit bez postihu, nebo ho zapečetit hned.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if !PlanService.willSeal(plan, minimum: minimum) {
                    Text(plan.pledgeableTasks(sealDate).isEmpty
                         ? "Všechny úkoly tohoto týdne jsou už uzavřené (splněné, přeskočené nebo propadlé) a zpětně se k nim zavázat nedá. Přidej otevřený úkol, jinak se plánovač nezapečetí a vrátí se ti jako návrh."
                         : "Plánovač je pod minimem \(minimum) aktivit. Když ho nedoplníš, nezapečetí se a vrátí se ti jako návrh.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            overview
            VStack(spacing: 10) {
                Button {
                    reviewsSealNow = true
                } label: {
                    Label("ZAPEČETIT HNED", systemImage: "checkmark.seal.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!PlanService.canSealNow(plan, minimum: minimum))
                Button {
                    confirmsWithdraw = true
                } label: {
                    Label("STÁHNOUT PLÁNOVAČ", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(PrimaryButtonStyle(color: Theme.orange))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius)
            .stroke(Theme.orange.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])))
        .sheet(isPresented: $reviewsSealNow) {
            SealNowSheet(plan: plan, minimum: minimum)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Stáhnout plánovač?", isPresented: $confirmsWithdraw) {
            Button("Stáhnout", role: .destructive) { withAnimation { PlanService.withdraw(plan) } }
            Button("Zrušit", role: .cancel) {}
        } message: {
            Text("Plán bude zase jen návrh. Až ho odešleš znovu, hodina poběží od začátku.")
        }
    }
}

/// "Seal now": a last look at what is about to become a promise, then a second confirmation.
private struct SealNowSheet: View {
    @Environment(\.dismiss) private var dismiss
    let plan: WeeklyPlan
    let minimum: Int
    @State private var confirms = false

    private var tasks: [TaskItem] {
        plan.pledgeableTasks().sorted {
            $0.scheduledDate == $1.scheduledDate ? $0.dueDate < $1.dueDate : $0.scheduledDate < $1.scheduledDate
        }
    }

    private var days: [Date] { Array(Set(tasks.map { $0.scheduledDate.startOfDay })).sorted() }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Label("ZAPEČETIT HNED", systemImage: "checkmark.seal.fill").labelStyle(Theme.textPrimary)
                Text("Tohle se stane slibem")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Závazky: \(tasks.count) · \(minutes / 60) h \(minutes % 60) min · kritické: \(tasks.filter { $0.priority == .critical }.count)")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(Theme.screenPadding)
            .padding(.top, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(days, id: \.self) { day in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(day.shortDayText.uppercased()).labelStyle()
                            VStack(spacing: 0) {
                                ForEach(Array(tasks.filter { $0.scheduledDate.isSameDay(as: day) }.enumerated()), id: \.element.id) { index, task in
                                    if index > 0 { Divider().overlay(Theme.border) }
                                    HStack(spacing: 10) {
                                        Image(systemName: task.icon)
                                            .foregroundStyle(task.priority == .critical ? Theme.orange : Theme.textSecondary)
                                            .frame(width: 22)
                                        Text(task.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Theme.textPrimary)
                                            .lineLimit(1)
                                        Spacer()
                                        Text([task.deadline.map { "do \($0.timeText)" }, "\(task.plannedMinutes) min"].compactMap { $0 }.joined(separator: " · "))
                                            .font(.system(size: 12))
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                }
                            }
                            .card(padding: 0)
                        }
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
            }
            VStack(spacing: 10) {
                Text("Po zapečetění se každé odstranění, přesun nebo snížení úkolu zaznamená a odstraněný úkol se počítá jako porušený slib. Zbytek hodiny na úpravy bez postihu tím propadne.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("ZAPEČETIT TEĎ") { confirms = true }
                    .buttonStyle(PrimaryButtonStyle())
                Button("JEŠTĚ NE") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(Theme.screenPadding)
        }
        .screenBackground()
        .appAppearance()
        .alert("Opravdu zapečetit teď?", isPresented: $confirms) {
            Button("Zapečetit") {
                withAnimation(.spring(duration: 0.5)) { PlanService.sealNow(plan, minimum: minimum) }
                dismiss()
            }
            Button("Zrušit", role: .cancel) {}
        } message: {
            Text("Od této chvíle už plán nejde měnit bez postihu. Vrátit to nejde.")
        }
        .sensoryFeedback(.success, trigger: plan.isCommitted) { _, sealed in sealed }
    }

    private var minutes: Int { tasks.reduce(0) { $0 + $1.plannedMinutes } }
}

private extension SealingCard {
    func tasks(on day: Date) -> [TaskItem] {
        plan.committableTasks.filter { $0.scheduledDate.isSameDay(as: day) }
            .sorted { $0.dueDate == $1.dueDate ? $0.priority.rank > $1.priority.rank : $0.dueDate < $1.dueDate }
    }

    /// Tasks of the week that are already done or lost, so sealing leaves them out.
    var closedCount: Int { plan.committableTasks.count - plan.pledgeableTasks(sealDate).count }

    func isPledgeable(_ task: TaskItem) -> Bool {
        task.status == .pending && !task.dayHasPassed(sealDate)
    }

    func duration(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes) min" : (minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(minutes % 60)")
    }

    /// The whole week at a glance: one column a day with what is planned on it. One day is always open underneath, Monday first.
    var overview: some View {
        let days = (0..<7).map { plan.weekStart.addingDays($0) }
        let all = plan.committableTasks
        return VStack(spacing: 12) {
            HStack {
                Text("CO JE V PLÁNOVAČI").labelStyle()
                Spacer()
                Text("\(duration(all.reduce(0) { $0 + $1.plannedMinutes })) · kritické: \(all.filter { $0.priority == .critical }.count)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack(alignment: .top, spacing: 6) {
                ForEach(days, id: \.self) { day in
                    dayColumn(day)
                }
            }
            dayList(selectedDay ?? plan.weekStart)
        }
        .padding(.top, 4)
    }

    func dayColumn(_ day: Date) -> some View {
        let items = tasks(on: day)
        let isSelected = (selectedDay ?? plan.weekStart) == day
        return Button {
            withAnimation(.easeOut(duration: 0.2)) { selectedDay = day }
        } label: {
            VStack(spacing: 6) {
                Text(day.weekdayShortText.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(day.isSameDay(as: .now) ? Theme.textPrimary : Theme.textSecondary)
                VStack(spacing: 5) {
                    if items.isEmpty {
                        Image(systemName: "minus")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    ForEach(items.prefix(Self.maxIconsPerDay)) { task in
                        Image(systemName: task.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(!isPledgeable(task) ? Theme.textTertiary
                                             : (task.priority == .critical ? Theme.orange : Theme.textPrimary))
                            .frame(height: 16)
                    }
                    if items.count > Self.maxIconsPerDay {
                        Text("+\(items.count - Self.maxIconsPerDay)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 84)
                .background(isSelected ? Theme.orange.opacity(0.14) : Theme.cardRaised)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(isSelected ? Theme.orange : Theme.border, lineWidth: 1))
                Text(items.isEmpty ? " " : "\(items.count)×")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    func dayList(_ day: Date) -> some View {
        let items = tasks(on: day)
        return VStack(alignment: .leading, spacing: 8) {
            Text(day.longDayText).labelStyle(Theme.textPrimary)
            if items.isEmpty {
                Text("Žádné závazky")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)
            }
            ForEach(items) { task in
                HStack(spacing: 10) {
                    Image(systemName: task.icon)
                        .font(.system(size: 13))
                        .foregroundStyle(task.priority == .critical ? Theme.orange : Theme.textSecondary)
                        .frame(width: 20)
                    Text(task.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isPledgeable(task) ? Theme.textPrimary : Theme.textTertiary)
                        .lineLimit(1)
                    Spacer()
                    Text(isPledgeable(task)
                         ? [task.deadline.map { "do \($0.timeText)" }, duration(task.plannedMinutes)]
                            .compactMap { $0 }.joined(separator: " · ")
                         : (task.isDone ? "hotovo" : "uzavřeno"))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.cardRaised)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct WeekTaskRow: View {
    let task: TaskItem

    private var statusIcon: (name: String, color: Color) {
        let now = Date.now
        if task.isDone {
            if task.isPartial { return ("circle.lefthalf.filled", Theme.orange) }
            return ("checkmark.circle.fill", task.status == .completedLate ? Theme.orange : Theme.green)
        }
        if task.status == .excused { return ("minus.circle.fill", Theme.textTertiary) }
        if task.status != .pending || task.isMissed(now) { return ("xmark.circle.fill", Theme.red) }
        if task.isOverdue(now) { return ("exclamationmark.circle.fill", Theme.red) }
        return ("circle", Theme.textTertiary)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon.name)
                .foregroundStyle(statusIcon.color)
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(task.status == .pending ? Theme.textPrimary : Theme.textSecondary)
                HStack(spacing: 5) {
                    Image(systemName: task.icon)
                    Text(subtitle)
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if task.priority.rank >= TaskPriority.high.rank {
                Badge(text: task.priority.badge,
                      color: task.priority == .critical ? Theme.textPrimary : Theme.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var subtitle: String {
        var parts = [task.category.title, "\(task.plannedMinutes) min"]
        if let deadline = task.deadline { parts.append(deadline.timeText) }
        if task.moveCount > 0 { parts.append("přesunuto") }
        if task.isAddedAfterCommitment { parts.append("přidáno později") }
        return parts.joined(separator: " · ")
    }
}

/// Original plan vs. current plan, with the full log of changes made after committing.
private struct PlanChangesView: View {
    let plan: WeeklyPlan

    private var removed: [TaskItem] { plan.tasks.filter(\.isRemoved) }
    private var movedCount: Int { plan.committedTasks.filter { $0.moveCount > 0 }.count }
    private var addedCount: Int { plan.activeTasks.filter(\.isAddedAfterCommitment).count }
    private var edits: [CommitmentEdit] { plan.edits.sorted { $0.date > $1.date } }

    var body: some View {
        VStack(spacing: 10) {
            SectionLabel(text: "Původní vs. aktuální plán")
            HStack(spacing: 10) {
                MetricTile(value: "\(plan.committedTasks.count)", label: "Původní")
                MetricTile(value: "\(plan.activeTasks.count)", label: "Aktuální")
                MetricTile(value: "\(removed.count)", label: "Odstraněno",
                           color: removed.isEmpty ? Theme.textPrimary : Theme.red)
                MetricTile(value: "\(movedCount)", label: "Přesunuto",
                           color: movedCount == 0 ? Theme.textPrimary : Theme.orange)
            }
            if addedCount > 0 {
                Text("Přidáno po závazku: \(addedCount). Počítají se do produktivity, ne jako sliby.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !edits.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(edits.enumerated()), id: \.element.id) { index, edit in
                        if index > 0 {
                            Divider().overlay(Theme.border)
                        }
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(edit.taskTitle)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                    .strikethrough(edit.kind == .removed)
                                Text("\(edit.kind.title) · \(edit.detail)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(edit.kind.integrityPenalty > 0 ? Theme.orange : Theme.textSecondary)
                            }
                            Spacer()
                            Text(edit.date.stampText)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                    }
                }
                .card(padding: 0)
            }
        }
    }
}

/// The planning sheets and questions of the week screen, kept apart so the screen's body stays simple.
private struct PlanningDialogs: ViewModifier {
    let view: WeekView

    func body(content: Content) -> some View {
        view.planningDialogs(content)
    }
}
