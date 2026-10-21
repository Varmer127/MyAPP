import SwiftUI
import SwiftData

struct TaskEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [UserSettings]
    @Query private var allTasks: [TaskItem]
    @State private var confirmsDuplicate = false

    private let task: TaskItem?
    @State private var draft: TaskDraft
    @State private var usesCustomWeight = false
    @State private var confirmsRemoval = false
    @State private var showsDurationPicker = false

    private static let minuteOptions = [0, 15, 30, 45]
    private static let minimumDuration = 15
    private static let maximumHours = 16

    init(task: TaskItem?, defaultDate: Date, suggestion: TaskCategory? = nil, isRecovery: Bool = false) {
        self.task = task
        var draft = task.map(TaskDraft.init(task:)) ?? TaskDraft(date: defaultDate)
        if task == nil, let suggestion {
            draft.title = suggestion.suggestionTitle
            draft.category = suggestion
            draft.plannedMinutes = suggestion.suggestionMinutes
            draft.fromSuggestion = true
        }
        if task == nil {
            draft.isRecovery = isRecovery
        }
        _draft = State(initialValue: draft)
    }

    private var hoursBinding: Binding<Int> {
        Binding(get: { draft.plannedMinutes / 60 },
                set: { draft.plannedMinutes = max(Self.minimumDuration, $0 * 60 + draft.plannedMinutes % 60) })
    }

    private var minutesBinding: Binding<Int> {
        Binding(get: { draft.plannedMinutes % 60 },
                set: { draft.plannedMinutes = max(Self.minimumDuration, draft.plannedMinutes / 60 * 60 + $0) })
    }

    private var durationText: String {
        let hours = draft.plannedMinutes / 60
        let minutes = draft.plannedMinutes % 60
        if hours == 0 { return "\(minutes) min" }
        return minutes == 0 ? "\(hours) h" : "\(hours) h \(minutes) min"
    }

    private var isCommitted: Bool { task?.isCommitted == true }

    /// What the iPhone calendar already holds on the chosen day. With a deadline, the task is assumed
    /// to run in the planned time right before it, and events overlapping that are flagged as clashes.
    @ViewBuilder
    private var calendarRows: some View {
        if settingsList.first?.calendarEnabled == true {
            let events = CalendarService.events(on: draft.date)
            let end = draft.date.settingTime(from: draft.deadlineTime)
            let clashes = draft.hasDeadline
                ? CalendarService.conflicts(start: end.addingTimeInterval(TimeInterval(-draft.plannedMinutes * 60)), end: end, in: events)
                : []
            if !clashes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Kryje se s kalendářem", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .semibold))
                    ForEach(clashes) { Text($0.summary).font(.system(size: 13)) }
                }
                .foregroundStyle(Theme.orange)
            } else if !events.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Ten den máš v kalendáři", systemImage: "calendar")
                        .font(.system(size: 13, weight: .semibold))
                    ForEach(events) { Text($0.summary).font(.system(size: 13)) }
                }
                .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var automaticWeight: Int {
        if let settings = settingsList.first {
            return settings.defaultWeight(category: draft.category, priority: draft.priority)
        }
        return UserSettings.weight(points: draft.priority.basePoints, multiplier: draft.category.defaultMultiplier)
    }

    /// A committed task can only move within its own week, and never into the past.
    private var dateRange: ClosedRange<Date> {
        let today = Date.now.startOfDay
        guard let task, task.isCommitted, let plan = task.plan else {
            return min(today, draft.date)...Date.distantFuture
        }
        let lower = min(task.scheduledDate, max(today, plan.weekStart))
        return lower...max(plan.lastDay, lower)
    }

    var body: some View {
        NavigationStack {
            Form {
                if isCommitted {
                    Section {
                        Text("Tento úkol je součástí tvého závazku. Přesun, snížení priority nebo váhy a změna deadlinu se zaznamenají a sníží věrnost plánu.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.orange)
                    }
                    .listRowBackground(Theme.card)
                }

                Section("Úkol") {
                    TextField("Název", text: $draft.title)
                    Picker("Kategorie", selection: $draft.category) {
                        ForEach(categoryOptions) { Label($0.title, systemImage: $0.icon).tag($0) }
                    }
                    if task == nil, let custom = settingsList.first?.customActivities, !custom.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(custom, id: \.self) { name in
                                    Button {
                                        draft.title = name
                                        draft.category = .other
                                    } label: {
                                        Label(name, systemImage: ActivityIcons.shared.symbol(forCustom: name))
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(draft.title == name ? Theme.onPrimary : Theme.textPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(draft.title == name ? Theme.textPrimary : Theme.cardRaised)
                                    .clipShape(Capsule())
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    Picker("Priorita", selection: $draft.priority) {
                        ForEach(TaskPriority.allCases) { Text($0.title).tag($0) }
                    }
                }
                .listRowBackground(Theme.card)

                Section("Kdy") {
                    DatePicker("Den", selection: $draft.date, in: dateRange, displayedComponents: .date)
                    if isDuplicate {
                        Label("„\(draft.trimmedTitle)“ už v tento den máš naplánované", systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.orange)
                    }
                    Toggle("Použít deadline", isOn: $draft.hasDeadline)
                        .tint(Theme.textSecondary)
                    if draft.hasDeadline {
                        DatePicker("Deadline", selection: $draft.deadlineTime, displayedComponents: .hourAndMinute)
                    }
                    Button {
                        withAnimation { showsDurationPicker.toggle() }
                    } label: {
                        LabeledContent("Délka", value: durationText)
                    }
                    .foregroundStyle(Theme.textPrimary)
                    calendarRows
                    if showsDurationPicker {
                        HStack(spacing: 0) {
                            Picker("Hodiny", selection: hoursBinding) {
                                ForEach(0...Self.maximumHours, id: \.self) { Text("\($0) h").tag($0) }
                            }
                            Picker("Minuty", selection: minutesBinding) {
                                ForEach(Self.minuteOptions, id: \.self) { Text("\($0) min").tag($0) }
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 130)
                    }
                }
                .listRowBackground(Theme.card)

                Section {
                    Toggle("Vlastní váha", isOn: $usesCustomWeight)
                        .tint(Theme.textSecondary)
                    if usesCustomWeight {
                        Stepper("Váha: \(draft.weight)", value: $draft.weight, in: UserSettings.weightRange)
                    } else {
                        LabeledContent("Váha", value: "\(automaticWeight)")
                    }
                } header: {
                    Text("Body")
                } footer: {
                    Text("Váha určuje, jak moc úkol hýbe produktivitou. Ve výchozím stavu vychází z kategorie a priority.")
                }
                .listRowBackground(Theme.card)

                Section {
                    Toggle("Focus timer", isOn: $draft.usesFocus)
                        .tint(Theme.textSecondary)
                    Toggle("Vyžadovat důkaz", isOn: $draft.requiresProof)
                        .tint(Theme.textSecondary)
                    if task == nil {
                        Toggle("Recovery úkol", isOn: $draft.isRecovery)
                            .tint(Theme.textSecondary)
                    }
                } header: {
                    Text("Režim")
                } footer: {
                    Text("Důkaz = fotka nebo poznámka před splněním. Recovery úkol je práce navíc po špatném dni: přidá bonus, ale původní selhání nesmaže.")
                }
                .listRowBackground(Theme.card)

                Section {
                    TextField("Co se stane, když to nesplníš", text: $draft.stake, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("Sázka")
                } footer: {
                    Text("Např. „večer bez seriálu“. Po selhání se tě aplikace zeptá, jestli jsi ji dodržel.")
                }
                .listRowBackground(Theme.card)

                Section("Proč na tom záleží?") {
                    TextField("Tvůj vlastní důvod — bude použit proti tobě", text: $draft.why, axis: .vertical)
                        .lineLimit(2...5)
                }
                .listRowBackground(Theme.card)

                Section("Poznámky") {
                    TextField("Volitelné", text: $draft.notes, axis: .vertical)
                        .lineLimit(2...6)
                }
                .listRowBackground(Theme.card)

                if task != nil {
                    Section {
                        Button("Odstranit úkol", role: .destructive) { confirmsRemoval = true }
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(task == nil ? "Nový úkol" : "Upravit úkol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušit") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(task == nil ? "Přidat do plánu" : "Uložit") { isDuplicate ? (confirmsDuplicate = true) : save() }
                        .disabled(draft.trimmedTitle.isEmpty)
                }
            }
            .alert("„\(draft.trimmedTitle)“ už v ten den máš", isPresented: $confirmsDuplicate) {
                Button("Přidat znovu", action: save)
                Button("Zrušit", role: .cancel) {}
            } message: {
                Text("\(draft.date.longDayText) ji už máš naplánovanou. Opravdu ji tam chceš ještě jednou? Třeba když jdeš do gymu dvakrát za den.")
            }
            .confirmationDialog(removalMessage, isPresented: $confirmsRemoval, titleVisibility: .visible) {
                Button(isCommitted ? "Porušit slib" : "Smazat", role: .destructive, action: remove)
            }
            .onAppear {
                if let task {
                    usesCustomWeight = task.weight != automaticWeight
                }
            }
        }
        .appAppearance()
    }

    private var removalMessage: String {
        isCommitted
            ? "K tomuhle ses zavázal. Odstranění se počítá jako porušený slib a zůstane v historii."
            : "Úkol ještě není součástí závazku, takže se prostě smaže."
    }

    /// The user's categories, plus the one this task already has.
    private var categoryOptions: [TaskCategory] {
        let enabled = settingsList.first?.enabledCategories ?? TaskCategory.allCases
        return TaskCategory.allCases.filter { enabled.contains($0) || $0 == draft.category }
    }

    /// Another task with the same title already sits on the chosen day.
    private var isDuplicate: Bool {
        let key = draft.trimmedTitle.activityKey
        return !key.isEmpty && allTasks.contains {
            $0 !== task && !$0.isRemoved && $0.scheduledDate.isSameDay(as: draft.date) && $0.title.activityKey == key
        }
    }

    private func save() {
        if !usesCustomWeight {
            draft.weight = automaticWeight
        }
        PlanService.save(draft, to: task, in: context)
        dismiss()
    }

    private func remove() {
        if let task {
            PlanService.remove(task, in: context)
        }
        dismiss()
    }
}
