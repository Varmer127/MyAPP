import SwiftUI
import SwiftData

/// Plans the same task on several days of a week in a few taps.
struct QuickPlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var tasks: [TaskItem]
    @Query private var settingsList: [UserSettings]
    let weekStart: Date
    /// Closes the sheet and opens the review of the week's plan.
    var onReview: () -> Void = {}

    @State private var category: TaskCategory = .gym
    @State private var title = TaskCategory.gym.suggestionTitle
    @State private var priority: TaskPriority = .medium
    @State private var minutes = TaskCategory.gym.suggestionMinutes
    @State private var selectedDays: Set<Date> = []

    private static let durationOptions = [15, 30, 45, 60, 90, 120, 180, 240, 300, 360]
    private static let daysInWeek = 7
    private static let categoryChipHeight: CGFloat = 48

    private var days: [Date] { (0..<Self.daysInWeek).map { weekStart.addingDays($0) } }
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isCustomTitle: Bool { category == .other && (settingsList.first?.customActivities ?? []).contains(trimmedTitle) }
    @State private var confirmsDuplicate = false
    // What gets added flies from its day into the review button, which counts the plan.
    @State private var flights: [PlanFlight] = []
    @State private var flightFrames = FlightFrameStore()
    @State private var reviewPulse = 0
    @State private var landedCount = 0

    private var weekTaskCount: Int {
        tasks.filter { !$0.isRemoved && $0.scheduledDate >= weekStart && $0.scheduledDate < weekStart.addingDays(7) }.count
    }

    private var takenSelected: [Date] { selectedDays.filter(isTaken).sorted() }
    private var canSave: Bool { !trimmedTitle.isEmpty && !selectedDays.isEmpty }

    /// The day already holds a task with this title, so planning it again would only duplicate it.
    private func isTaken(_ day: Date) -> Bool {
        let key = trimmedTitle.activityKey
        return !key.isEmpty && tasks.contains {
            !$0.isRemoved && $0.scheduledDate.isSameDay(as: day) && $0.title.activityKey == key
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TÝDEN \(weekStart.weekNumber)").labelStyle()
                            Text("Rychlé plánování")
                                .scaledFont(.title, weight: .bold)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        Spacer()
                        Button("Zavřít") { dismiss() }
                            .scaledFont(.body, weight: .semibold)
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 40)
                            .background(Theme.cardRaised)
                            .clipShape(Capsule())
                    }
                    group("Co") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                            ForEach(settingsList.first?.enabledCategories ?? TaskCategory.allCases) { option in
                                chip(option.title, symbol: option.icon, isSelected: category == option && !isCustomTitle) { select(option) }
                            }
                            // The user's own activities are planned under "Ostatní" with their own name.
                            ForEach(settingsList.first?.customActivities ?? [], id: \.self) { name in
                                chip(name, symbol: ActivityIcons.shared.symbol(forCustom: name), isSelected: category == .other && trimmedTitle == name) {
                                    category = .other
                                    title = name
                                }
                            }
                        }
                        TextField("Název", text: $title)
                            .scaledFont(.body)
                            .card()
                    }
                    group("Které dny") {
                        HStack(alignment: .top, spacing: 6) {
                            ForEach(days, id: \.self) { day in
                                let isPast = day.endOfDay <= Date.now
                                let taken = isTaken(day)
                                VStack(spacing: 4) {
                                    chip(day.weekdayShortText.uppercased(), isSelected: selectedDays.contains(day)) {
                                        selectedDays.formSymmetricDifference([day])
                                    }
                                    .flightFrame(Self.frameKey(day))
                                    .disabled(isPast)
                                    .opacity(isPast ? 0.3 : 1)
                                    if taken {
                                        Text("už máš")
                                            .scaledFont(.caption, weight: .semibold)
                                            .foregroundStyle(Theme.orange)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    }
                                }
                            }
                        }
                        if days.contains(where: isTaken) {
                            Text("„\(trimmedTitle)“ už v označené dny máš. Přidat ho tam můžeš i podruhé, zeptám se tě.")
                                .scaledFont(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    group("Priorita") {
                        Picker("Priorita", selection: $priority) {
                            ForEach(TaskPriority.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    group("Délka") {
                        Picker("Délka", selection: $minutes) {
                            ForEach(Self.durationOptions, id: \.self) { Text(Self.durationText($0)).tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 110)
                    }
                }
                .padding(Theme.screenPadding)
                .padding(.top, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            VStack(spacing: 10) {
                Button(selectedDays.isEmpty ? "VYBER DNY" : "PŘIDAT DO PLÁNU · \(selectedDays.count)×") {
                    if takenSelected.isEmpty { save() } else { confirmsDuplicate = true }
                }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave)
                Button(weekTaskCount > 0 ? "ZKONTROLOVAT PLÁN · \(weekTaskCount)" : "ZKONTROLOVAT PLÁN", action: onReview)
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(weekTaskCount == 0)
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
                    .scaleEffect(reviewPulse % 2 == 1 ? 1.05 : 1)
                    .shadow(color: Theme.green.opacity(reviewPulse % 2 == 1 ? 0.5 : 0), radius: 14)
                    .flightFrame(FlightFramesKey.commitButton)
            }
            .padding(Theme.screenPadding)
        }
        .screenBackground()
        .appAppearance()
        .onPreferenceChange(FlightFramesKey.self) { flightFrames.frames = $0 }
        .overlay {
            GeometryReader { proxy in
                let origin = proxy.frame(in: .global).origin
                ZStack {
                    ForEach(flights) { FlyingIcon(flight: $0, origin: origin) }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .sensoryFeedback(.success, trigger: reviewPulse) { _, new in new % 2 == 1 }
        .alert("„\(trimmedTitle)“ už v ten den máš", isPresented: $confirmsDuplicate) {
            Button("Přidat znovu") { save() }
            Button("Zrušit", role: .cancel) {}
        } message: {
            Text("Naplánované už je: \(takenSelected.map(\.shortDayText).joined(separator: ", ")) Opravdu ho tam chceš podruhé? Třeba když jdeš do gymu dvakrát za den.")
        }
    }

    private static func durationText(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        return minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(minutes % 60) min"
    }

    private func group(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label.uppercased()).labelStyle()
            content()
        }
    }

    private func chip(_ text: String, symbol: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol).scaledFont(.heading)
                }
                Text(text)
            }
                .scaledFont(.body, weight: .semibold)
                .foregroundStyle(isSelected ? Theme.onPrimary : Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: symbol == nil ? nil : Self.categoryChipHeight)
                .padding(.vertical, 11)
                .padding(.horizontal, 6)
                .background(isSelected ? Theme.textPrimary : Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// Switching category replaces the title and length only while they still hold the previous defaults.
    private func select(_ option: TaskCategory) {
        if trimmedTitle.isEmpty || trimmedTitle == category.suggestionTitle {
            title = option.suggestionTitle
        }
        if minutes == category.suggestionMinutes {
            minutes = option.suggestionMinutes
        }
        category = option
    }

    /// Adds the tasks and stays open with the days cleared, so the next category can follow straight away.
    private static func frameKey(_ day: Date) -> String { "day-\(Int(day.timeIntervalSince1970))" }

    /// Each new task's icon flies from its day into the review button, which then pulses and counts.
    private func flyIntoReview(_ days: [Date], icon: String) {
        guard let target = flightFrames.frames[FlightFramesKey.commitButton] else { return }
        let stagger = 0.07
        let launched = days.enumerated().compactMap { index, day -> PlanFlight? in
            guard let frame = flightFrames.frames[Self.frameKey(day)] else { return nil }
            return PlanFlight(icon: icon, from: CGPoint(x: frame.midX, y: frame.midY),
                              to: CGPoint(x: target.midX, y: target.midY), delay: Double(index) * stagger)
        }
        if !reduceMotion { flights.append(contentsOf: launched) }
        let ids = Set(launched.map(\.id))
        let landing = reduceMotion || launched.isEmpty ? 0 : PlanFlight.duration + Double(launched.count - 1) * stagger
        Task {
            try? await Task.sleep(for: .seconds(landing))
            flights.removeAll { ids.contains($0.id) }
            withAnimation(.spring(duration: 0.3)) {
                reviewPulse += 1
                landedCount = days.count
            }
            try? await Task.sleep(for: .seconds(0.35))
            withAnimation(.spring(duration: 0.4)) { reviewPulse += 1 }
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeOut(duration: 0.3)) { landedCount = 0 }
        }
    }

    private func save() {
        let added = selectedDays.sorted()
        let icon = category == .other && isCustomTitle ? ActivityIcons.shared.symbol(forCustom: trimmedTitle) : category.icon
        defer { flyIntoReview(added, icon: icon) }
        let settings = UserSettings.current(in: context)
        for day in selectedDays.sorted() {
            var draft = TaskDraft(date: day)
            draft.title = trimmedTitle
            draft.category = category
            draft.priority = priority
            draft.plannedMinutes = minutes
            draft.weight = settings.defaultWeight(category: category, priority: priority)
            PlanService.save(draft, to: nil, in: context)
        }
        selectedDays = []
    }
}
