import SwiftUI
import SwiftData

struct TaskEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [UserSettings]

    private let task: TaskItem?
    @State private var draft: TaskDraft
    @State private var usesCustomWeight = false
    @State private var confirmsRemoval = false

    private static let durationStep = 15
    private static let durationRange = 15...480

    init(task: TaskItem?, defaultDate: Date) {
        self.task = task
        _draft = State(initialValue: task.map(TaskDraft.init(task:)) ?? TaskDraft(date: defaultDate))
    }

    private var isCommitted: Bool { task?.isCommitted == true }

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
                        Text("This task is part of your commitment. Moving it, lowering its priority or weight, or changing its deadline is recorded and lowers your Commitment Integrity.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.orange)
                    }
                    .listRowBackground(Theme.card)
                }

                Section("Task") {
                    TextField("Title", text: $draft.title)
                    Picker("Category", selection: $draft.category) {
                        ForEach(TaskCategory.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Priority", selection: $draft.priority) {
                        ForEach(TaskPriority.allCases) { Text($0.title).tag($0) }
                    }
                }
                .listRowBackground(Theme.card)

                Section("When") {
                    DatePicker("Day", selection: $draft.date, in: dateRange, displayedComponents: .date)
                    Toggle("Use deadline", isOn: $draft.hasDeadline)
                    if draft.hasDeadline {
                        DatePicker("Deadline", selection: $draft.deadlineTime, displayedComponents: .hourAndMinute)
                    }
                    Stepper("Duration: \(draft.plannedMinutes) min", value: $draft.plannedMinutes,
                            in: Self.durationRange, step: Self.durationStep)
                }
                .listRowBackground(Theme.card)

                Section {
                    Toggle("Custom weight", isOn: $usesCustomWeight)
                    if usesCustomWeight {
                        Stepper("Weight: \(draft.weight)", value: $draft.weight, in: UserSettings.weightRange)
                    } else {
                        LabeledContent("Weight", value: "\(automaticWeight)")
                    }
                } header: {
                    Text("Points")
                } footer: {
                    Text("Weight decides how much this task moves your Productivity Score. By default it follows category and priority.")
                }
                .listRowBackground(Theme.card)

                Section("Why does this matter?") {
                    TextField("Your own reason — it will be used against you", text: $draft.why, axis: .vertical)
                        .lineLimit(2...5)
                }
                .listRowBackground(Theme.card)

                Section("Notes") {
                    TextField("Optional", text: $draft.notes, axis: .vertical)
                        .lineLimit(2...6)
                }
                .listRowBackground(Theme.card)

                if task != nil {
                    Section {
                        Button("Remove task", role: .destructive) { confirmsRemoval = true }
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(task == nil ? "New task" : "Edit task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(draft.trimmedTitle.isEmpty)
                }
            }
            .confirmationDialog(removalMessage, isPresented: $confirmsRemoval, titleVisibility: .visible) {
                Button(isCommitted ? "Break this promise" : "Delete", role: .destructive, action: remove)
            }
            .onAppear {
                if let task {
                    usesCustomWeight = task.weight != automaticWeight
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var removalMessage: String {
        isCommitted
            ? "You committed to this. Removing it counts as a broken promise and stays in your history."
            : "This task isn't committed yet, so it will simply be deleted."
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
