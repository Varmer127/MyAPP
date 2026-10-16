import SwiftUI
import SwiftData

/// Plans the same task on several days of a week in a few taps.
struct QuickPlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var tasks: [TaskItem]
    let weekStart: Date

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
    @State private var confirmsDuplicate = false

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
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TÝDEN \(weekStart.weekNumber)").labelStyle()
                        Text("Rychlé plánování")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    group("Co") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                            ForEach(TaskCategory.allCases) { option in
                                chip(option.title, symbol: option.symbol, isSelected: category == option) { select(option) }
                            }
                        }
                        TextField("Název", text: $title)
                            .font(.system(size: 16))
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
                                    .disabled(isPast)
                                    .opacity(isPast ? 0.3 : 1)
                                    if taken {
                                        Text("už máš")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(Theme.orange)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    }
                                }
                            }
                        }
                        if days.contains(where: isTaken) {
                            Text("„\(trimmedTitle)“ už v označené dny máš. Přidat ho tam můžeš i podruhé, zeptám se tě.")
                                .font(.system(size: 12))
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
                Button(selectedDays.isEmpty ? "VYBER DNY" : "PŘIDAT \(selectedDays.count)×") {
                    if takenSelected.isEmpty { save() } else { confirmsDuplicate = true }
                }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave)
                Button("HOTOVO") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(Theme.screenPadding)
        }
        .screenBackground()
        .appAppearance()
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
                    Image(systemName: symbol).font(.system(size: 17))
                }
                Text(text)
            }
                .font(.system(size: 14, weight: .semibold))
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
    private func save() {
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
