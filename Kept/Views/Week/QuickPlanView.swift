import SwiftUI
import SwiftData

/// Plans the same task on several days of a week in a few taps.
struct QuickPlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let weekStart: Date

    @State private var category: TaskCategory = .gym
    @State private var title = TaskCategory.gym.suggestionTitle
    @State private var priority: TaskPriority = .medium
    @State private var minutes = TaskCategory.gym.suggestionMinutes
    @State private var selectedDays: Set<Date> = []

    private static let durationOptions = [15, 30, 45, 60, 90, 120, 180, 240, 300, 360]
    private static let daysInWeek = 7

    private var days: [Date] { (0..<Self.daysInWeek).map { weekStart.addingDays($0) } }
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedTitle.isEmpty && !selectedDays.isEmpty }

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
                                chip(option.title, isSelected: category == option) { select(option) }
                            }
                        }
                        TextField("Název", text: $title)
                            .font(.system(size: 16))
                            .card()
                    }
                    group("Které dny") {
                        HStack(spacing: 6) {
                            ForEach(days, id: \.self) { day in
                                let isPast = day.endOfDay <= Date.now
                                chip(day.weekdayShortText.uppercased(), isSelected: selectedDays.contains(day)) {
                                    selectedDays.formSymmetricDifference([day])
                                }
                                .disabled(isPast)
                                .opacity(isPast ? 0.3 : 1)
                            }
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
                Button(selectedDays.isEmpty ? "VYBER DNY" : "PŘIDAT \(selectedDays.count)×", action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave)
                Button("HOTOVO") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(Theme.screenPadding)
        }
        .screenBackground()
        .preferredColorScheme(.dark)
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

    private func chip(_ text: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? .black : Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .padding(.horizontal, 6)
                .background(isSelected ? Color.white : Theme.card)
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
