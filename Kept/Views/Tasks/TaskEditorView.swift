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
    /// The extra options are open by default, with one clear button to fold them away.
    @State private var showsMore = true
    @State private var editing: Property?
    @State private var showsDatePicker = false
    @FocusState private var titleFocused: Bool

    /// The little editor that opens under the row of chips.
    private enum Property { case deadline, duration, priority }

    private static let minimumDuration = 15
    private static let maximumMinutes = 16 * 60
    private static let quickDurations = [15, 30, 45, 60, 90, 120]
    private static let stripDays = 6

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
                        .scaledFont(.caption, weight: .semibold)
                    ForEach(clashes) { Text($0.summary).scaledFont(.caption) }
                }
                .foregroundStyle(Theme.orange)
            } else if !events.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Ten den máš v kalendáři", systemImage: "calendar")
                        .scaledFont(.caption, weight: .semibold)
                    ForEach(events) { Text($0.summary).scaledFont(.caption) }
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

    // MARK: Layout

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isCommitted { committedNote }
                    titleField
                    dayStrip
                    propertyChips
                    if let editing { editor(for: editing) }
                    calendarRows
                    categoryRow
                    customActivityRow
                    moreSection
                    if task != nil { removeButton }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            addButton
        }
        .screenBackground()
        .appAppearance()
        .presentationDragIndicator(.visible)
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
            if let task { usesCustomWeight = task.weight != automaticWeight }
            if task == nil { titleFocused = true }
        }
    }

    private var header: some View {
        HStack {
            Text(task == nil ? "NOVÝ SLIB" : "UPRAVIT SLIB")
                .labelStyle()
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .scaledFont(.body, weight: .semibold)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(Theme.cardRaised)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Zavřít")
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 22)
        .padding(.bottom, 6)
    }

    private var committedNote: some View {
        Text("Tento úkol je součástí tvého závazku. Přesun, snížení priority nebo váhy a změna deadlinu se zaznamenají a sníží věrnost plánu.")
            .scaledFont(.caption)
            .foregroundStyle(Theme.orange)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Co slibuješ?", text: $draft.title, axis: .vertical)
                .scaledFont(.title, weight: .heavy)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1...3)
                .focused($titleFocused)
                .submitLabel(.done)
            if isDuplicate {
                Label("„\(draft.trimmedTitle)“ už v tento den máš naplánované", systemImage: "exclamationmark.circle.fill")
                    .scaledFont(.caption, weight: .semibold)
                    .foregroundStyle(Theme.orange)
            }
        }
    }

    // MARK: Day

    /// The next days as one tap each; any other day opens a calendar.
    private var stripDates: [Date] {
        let today = Date.now.startOfDay
        var days = (0..<Self.stripDays).map { today.addingDays($0) }.filter { dateRange.contains($0) }
        if !days.contains(where: { $0.isSameDay(as: draft.date) }) {
            days.insert(draft.date, at: 0)
            days.sort()
        }
        return days
    }

    private var dayStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(stripDates, id: \.self) { day in
                        let isOn = day.isSameDay(as: draft.date)
                        Button {
                            Haptics.light()
                            draft.date = day
                            showsDatePicker = false
                        } label: {
                            VStack(spacing: 2) {
                                Text(day.isSameDay(as: .now) ? "Dnes" : day.formatted(.dateTime.weekday(.abbreviated).locale(.app)).localizedCapitalized)
                                    .scaledFont(.caption)
                                Text(day.formatted(.dateTime.day().locale(.app)))
                                    .scaledFont(.heading, weight: .bold)
                            }
                            .frame(width: 54, height: 58)
                            .foregroundStyle(isOn ? Theme.onPrimary : Theme.textPrimary)
                            .background(isOn ? Theme.textPrimary : Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isOn ? Theme.textPrimary : Theme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(day.longDayText)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                    Button { withAnimation { showsDatePicker.toggle() } } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "calendar").scaledFont(.heading)
                            Text("Jiný").scaledFont(.caption)
                        }
                        .frame(width: 54, height: 58)
                        .foregroundStyle(Theme.textPrimary)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(showsDatePicker ? Theme.textPrimary : Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Vybrat jiný den")
                }
            }
            if showsDatePicker {
                DatePicker("Den", selection: $draft.date, in: dateRange, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(Theme.textPrimary)
                    .padding(8)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: Chips and their editors

    private var propertyChips: some View {
        FlowLayout(spacing: 8) {
            chip(.deadline, "clock", draft.hasDeadline ? "do \(draft.deadlineTime.timeText)" : "bez deadlinu")
            chip(.duration, "hourglass", durationText)
            chip(.priority, "flag", draft.priority.title)
        }
    }

    private func chip(_ property: Property, _ symbol: String, _ text: String) -> some View {
        let isOpen = editing == property
        return Button {
            Haptics.light()
            withAnimation(.easeOut(duration: 0.2)) { editing = isOpen ? nil : property }
        } label: {
            Label(text, systemImage: symbol)
                .scaledFont(.body, weight: .semibold)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.card)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isOpen ? Theme.textPrimary : Theme.border, lineWidth: isOpen ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOpen ? .isSelected : [])
    }

    @ViewBuilder
    private func editor(for property: Property) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            switch property {
            case .deadline:
                Text("DEADLINE").labelStyle()
                Toggle(isOn: $draft.hasDeadline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Použít deadline").scaledFont(.body, weight: .semibold).foregroundStyle(Theme.textPrimary)
                        Text("Úkol se ohlásí před koncem.").scaledFont(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
                .tint(Theme.green)
                if draft.hasDeadline {
                    DatePicker("Hotovo do", selection: $draft.deadlineTime, displayedComponents: .hourAndMinute)
                        .tint(Theme.textPrimary)
                }
            case .duration:
                Text("DÉLKA").labelStyle()
                FlowLayout(spacing: 8) {
                    ForEach(Self.quickDurations, id: \.self) { minutes in
                        let isOn = draft.plannedMinutes == minutes
                        Button { draft.plannedMinutes = minutes; Haptics.light() } label: {
                            Text(Self.durationLabel(minutes))
                                .scaledFont(.body, weight: .semibold)
                                .foregroundStyle(isOn ? Theme.onPrimary : Theme.textPrimary)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(isOn ? Theme.textPrimary : Theme.cardRaised)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Stepper("Přesně: \(durationText)", value: $draft.plannedMinutes,
                        in: Self.minimumDuration...Self.maximumMinutes, step: 15)
                    .scaledFont(.body)
                    .foregroundStyle(Theme.textPrimary)
            case .priority:
                Text("PRIORITA").labelStyle()
                Picker("Priorita", selection: $draft.priority) {
                    ForEach(TaskPriority.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("Váha úkolu vychází z priority a kategorie, dole ji můžeš nastavit ručně.")
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private static func durationLabel(_ minutes: Int) -> String {
        switch minutes {
        case ..<60: "\(minutes) min"
        case 60: "1 h"
        case 90: "1,5 h"
        default: "\(minutes / 60) h"
        }
    }

    // MARK: Category

    private var categoryRow: some View {
        categoryScroller.scrollHintBar()
    }

    private var categoryScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categoryOptions) { category in
                    let isOn = draft.category == category
                    Button { Haptics.light(); draft.category = category } label: {
                        VStack(spacing: 5) {
                            Image(systemName: category.icon)
                                .scaledFont(.heading)
                                .frame(width: 48, height: 48)
                                .foregroundStyle(isOn ? Theme.onPrimary : Theme.textPrimary)
                                .background(isOn ? Theme.textPrimary : Theme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(isOn ? Theme.textPrimary : Theme.border, lineWidth: 1))
                            Text(category.title)
                                .scaledFont(.caption)
                                .foregroundStyle(isOn ? Theme.textPrimary : Theme.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(width: 66)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(category.title)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }

    /// The user's own activities as one-tap shortcuts, only when adding.
    @ViewBuilder
    private var customActivityRow: some View {
        if task == nil, let custom = settingsList.first?.customActivities, !custom.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(custom, id: \.self) { name in
                        let isOn = draft.title == name
                        Button {
                            draft.title = name
                            draft.category = .other
                        } label: {
                            Label(name, systemImage: ActivityIcons.shared.symbol(forCustom: name))
                                .scaledFont(.body, weight: .semibold)
                                .foregroundStyle(isOn ? Theme.onPrimary : Theme.textPrimary)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(isOn ? Theme.textPrimary : Theme.cardRaised)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: More options

    private var moreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().overlay(Theme.border)
            Button {
                Haptics.light()
                withAnimation(.easeInOut(duration: 0.25)) { showsMore.toggle() }
            } label: {
                HStack {
                    Text("Další možnosti")
                        .scaledFont(.body, weight: .semibold)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(showsMore ? "Skrýt" : "Zobrazit")
                        .scaledFont(.body)
                        .foregroundStyle(Theme.textSecondary)
                    Image(systemName: "chevron.down")
                        .scaledFont(.caption, weight: .semibold)
                        .foregroundStyle(Theme.textSecondary)
                        .rotationEffect(.degrees(showsMore ? 180 : 0))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(showsMore ? "Zobrazeno" : "Skryto")
            if showsMore { moreContent }
        }
    }

    private var moreContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Text("BODY A REŽIM").labelStyle()
                weightRow
                Divider().overlay(Theme.border)
                switchRow("Focus timer", "Stopky při plnění úkolu.", $draft.usesFocus)
                Divider().overlay(Theme.border)
                switchRow("Vyžadovat důkaz", "Fotka nebo poznámka před splněním.", $draft.requiresProof)
                if task == nil {
                    Divider().overlay(Theme.border)
                    switchRow("Recovery úkol", "Práce navíc po špatném dni: přidá bonus, ale původní selhání nesmaže.", $draft.isRecovery)
                }
            }
            .padding(14)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))

            textCard("SÁZKA", "Co se stane, když to nesplníš", "Např. „večer bez seriálu“. Po selhání se tě aplikace zeptá, jestli jsi ji dodržel.", $draft.stake, 1...3)
            textCard("KDY TO ZAČNEŠ", "Např. když dopiju kávu, začnu číst", "Pevný spouštěč, ne „někdy dnes“. Věta se ukáže v upozornění.", $draft.cue, 1...3)
            textCard("PROČ NA TOM ZÁLEŽÍ", "Tvůj vlastní důvod, bude použit proti tobě", nil, $draft.why, 2...5)
            textCard("POZNÁMKY", "Volitelné", nil, $draft.notes, 2...6)
        }
        .transition(.opacity)
    }

    private var weightRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Váha").scaledFont(.body, weight: .semibold).foregroundStyle(Theme.textPrimary)
                    Text("Jak moc úkol hýbe produktivitou.").scaledFont(.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Text(usesCustomWeight ? "\(draft.weight)" : "\(automaticWeight)")
                    .scaledFont(.heading, weight: .bold)
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
            }
            Picker("Váha", selection: $usesCustomWeight) {
                Text("Automaticky").tag(false)
                Text("Vlastní").tag(true)
            }
            .pickerStyle(.segmented)
            if usesCustomWeight {
                Stepper("Váha: \(draft.weight)", value: $draft.weight, in: UserSettings.weightRange)
                    .scaledFont(.body)
                    .foregroundStyle(Theme.textPrimary)
            }
        }
    }

    private func switchRow(_ title: LocalizedStringKey, _ subtitle: LocalizedStringKey, _ isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).scaledFont(.body, weight: .semibold).foregroundStyle(Theme.textPrimary)
                Text(subtitle).scaledFont(.caption).foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Theme.green)
    }

    private func textCard(_ label: LocalizedStringKey, _ placeholder: LocalizedStringKey, _ hint: LocalizedStringKey?,
                          _ text: Binding<String>, _ lines: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).labelStyle()
            TextField(placeholder, text: text, axis: .vertical)
                .lineLimit(lines)
                .scaledFont(.body)
                .foregroundStyle(Theme.textPrimary)
            if let hint {
                Text(hint)
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: Buttons

    private var addButton: some View {
        Button(task == nil ? "PŘIDAT DO PLÁNU" : "ULOŽIT") {
            isDuplicate ? (confirmsDuplicate = true) : save()
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(draft.trimmedTitle.isEmpty)
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Theme.background)
    }

    private var removeButton: some View {
        Button("Odstranit úkol", role: .destructive) { confirmsRemoval = true }
            .scaledFont(.body, weight: .semibold)
            .foregroundStyle(Theme.red)
            .frame(maxWidth: .infinity, minHeight: 44)
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
            if task.isCommitted { Haptics.warning() }
            PlanService.remove(task, in: context)
        }
        dismiss()
    }
}
