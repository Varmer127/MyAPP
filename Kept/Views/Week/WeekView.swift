import SwiftUI
import SwiftData

struct WeekView: View {
    @Query(sort: \WeeklyPlan.weekStart) var plans: [WeeklyPlan]

    @Query var tasks: [TaskItem]

    @Query var settingsList: [UserSettings]

    @Binding var showsNextWeek: Bool

    @State var editor: EditorRequest?

    @State var planToCommit: WeeklyPlan?

    @State var showsQuickPlan = false

    @State var detailTask: TaskItem?

    /// Events of the shown week from the iPhone calendar, when that is switched on.
    @State var calendarEvents: [CalendarService.Event] = []

    @Environment(\.modelContext) var context

    @Environment(\.scenePhase) var scenePhase

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Newly planned tasks fly into the send button, so it is clear the plan still has to be sent.
    @State var knownTaskIDs: Set<UUID> = []

    @State var knownWeekStart: Date?

    @State var flights: [PlanFlight] = []

    /// Not observed: the frames change on every scroll and only matter when something flies.
    @State var flightFrames = FlightFrameStore()

    @State var commitPulse = 0

    @State var landedCount = 0

    /// Where the next flight starts instead of the rows, for example the copy tile.
    @State var flightOrigin: CGPoint?

    @State var confirmsCopy = false

    @State var restDayLimitHit = false

    /// Watched only so the week is drawn again when a rest day is set or cleared.
    @AppStorage(RestDays.storageKey) var restDaysRaw = ""

    @State var nothingToCopy = false

    @State var confirmsReset = false

    @State var goalsExpanded = false

    /// Last week's plan, offered as a starting point until the shown week is handed in.
    /// The week can still take tasks copied from the one before.
    var canCopyWeek: Bool {
        plan?.isCommitted != true && plan?.isSealing != true && Date.now < weekStart.addingDays(7)
    }

    var planToCopy: WeeklyPlan? {
        guard canCopyWeek,
              let previous = plans.first(where: { $0.weekStart == weekStart.addingDays(-7) }),
              !previous.committableTasks.isEmpty else { return nil }
        return previous
    }

    var weekStart: Date { Date.now.weekStart.addingDays(showsNextWeek ? 7 : 0) }

    var plan: WeeklyPlan? { plans.first { $0.weekStart == weekStart } }

    var days: [Date] { (0..<7).map { weekStart.addingDays($0) } }

    var goals: [WeeklyGoal] {
        let settings = settingsList.first
        return SuggestionService.goals(tasks: tasks, weekStart: weekStart) {
            settings?.weeklyTarget(for: $0) ?? $0.defaultWeeklyTarget
        }
    }

    var weeklyTotal: (planned: Int, done: Int, minimum: Int)? {
        let minimum = settingsList.first?.minimumWeeklyTasks ?? UserSettings.defaultMinimumWeeklyTasks
        guard minimum > 0 else { return nil }
        let week = (plan?.committableTasks ?? [])
        return (week.count, week.filter(\.isDone).count, minimum)
    }

    var canCommit: Bool {
        guard let plan else { return false }
        return !plan.isCommitted && !plan.isSealing && !plan.pledgeableTasks().isEmpty && Date.now < plan.weekEnd
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                    header
                    statusCard
                    if Date.now < weekStart.addingDays(7), plan?.isCommitted != true, plan?.isSealing != true {
                        PlanStartCard(previousWeek: weekStart.addingDays(-7).weekNumber,
                                      onQuick: { showsQuickPlan = true },
                                      onSingle: { editor = EditorRequest(date: max(Date.now, weekStart)) },
                                      onCopy: { if planToCopy == nil { nothingToCopy = true } else { confirmsCopy = true } },
                                      onReset: resettableTasks.isEmpty ? nil : { confirmsReset = true })
                    }
                    if foldsSummary {
                        // Sealed: the goals and the review sit together in one card instead of two.
                        VStack(spacing: 0) {
                            goalsSummaryRow
                            if showsReviewLink {
                                Divider().overlay(Theme.border)
                                reviewLink
                            }
                        }
                        .card(padding: 0)
                    } else {
                        if !goals.isEmpty || weeklyTotal != nil {
                            WeeklyGoalsCard(goals: goals, total: weeklyTotal)
                                .onTapGesture { if plan?.isCommitted == true { withAnimation { goalsExpanded = false } } }
                        }
                        if showsReviewLink {
                            reviewLink.card()
                        }
                    }
                    VStack(spacing: 20) {
                        ForEach(daySegments) { segment in
                            switch segment {
                            case .day(let day): daySection(day)
                            case .quiet(let run): quietRow(run)
                            }
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
                                    .scaledFont(.caption, weight: .heavy)
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


    func planningDialogs<Content: View>(_ content: Content) -> some View {
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
        .alert("Odpočinkové dny jsou vyčerpané", isPresented: $restDayLimitHit) {
            Button("Rozumím", role: .cancel) {}
        } message: {
            Text("V jednom měsíci jdou naplánovat dva. Odpočinek, který si vybereš předem, série neublíží. Další by už byl jen způsob, jak se vyhnout práci.")
        }
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

    enum DaySegment: Identifiable {
        case day(Date)
        case quiet([Date])

        var id: Date {
            switch self {
            case .day(let day): day
            case .quiet(let run): run[0]
            }
        }
    }

    // MARK: Planning flight


}