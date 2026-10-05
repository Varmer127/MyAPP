import SwiftUI

struct TaskCard: View {
    let task: TaskItem
    let now: Date
    var onTap: () -> Void = {}
    var onDone: () -> Void = {}
    var onFail: () -> Void = {}

    private static let deadlineWarningWindow: TimeInterval = 3600

    private var isMissed: Bool { task.isMissed(now) }
    private var isOverdue: Bool { task.isOverdue(now) }
    private var isApproaching: Bool {
        guard task.status == .pending, let deadline = task.deadline else { return false }
        return now <= deadline && deadline.timeIntervalSince(now) <= Self.deadlineWarningWindow
    }

    private var accent: Color {
        if task.isDone { return Theme.green }
        if isOverdue || task.status == .failed || task.status == .skipped { return Theme.red }
        if isApproaching { return Theme.orange }
        return .clear
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            badges
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    if task.isDone {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
                    }
                    Text(task.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(task.status == .pending ? Theme.textPrimary : Theme.textSecondary)
                }
                Text(metadata)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            if task.status == .pending {
                actions
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .overlay(alignment: .leading) {
            Rectangle().fill(accent).frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.border, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    @ViewBuilder
    private var badges: some View {
        let items = badgeItems
        if !items.isEmpty {
            HStack(spacing: 6) {
                ForEach(items, id: \.text) { Badge(text: $0.text, color: $0.color) }
            }
        }
    }

    private var badgeItems: [(text: String, color: Color)] {
        var items: [(String, Color)] = []
        switch task.status {
        case .completedLate: items.append(("Pozdě", Theme.orange))
        case .skipped: items.append(("Přeskočeno", Theme.red))
        case .failed: items.append(("Nesplněno", Theme.red))
        case .pending:
            if isMissed {
                items.append(("Nesplněno: \(task.scheduledDate.weekdayText)", Theme.red))
            } else if isOverdue {
                items.append(("Po termínu \(overdueText)", Theme.red))
            }
        case .completed: break
        }
        if task.priority == .critical {
            items.append((TaskPriority.critical.badge, task.status == .pending ? Theme.textPrimary : Theme.textSecondary))
        } else if task.priority == .high {
            items.append((TaskPriority.high.badge, Theme.textSecondary))
        }
        if task.moveCount > 0 { items.append(("Přesunuto", Theme.textSecondary)) }
        if task.isAddedAfterCommitment { items.append(("Přidáno později", Theme.textSecondary)) }
        return items
    }

    private var overdueText: String {
        let minutes = max(Int(now.timeIntervalSince(task.dueDate) / 60), 1)
        return minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h \(minutes % 60) min"
    }

    private var metadata: String {
        var parts = [task.category.title, "\(task.plannedMinutes) min"]
        if let deadline = task.deadline {
            parts.append("Deadline \(deadline.timeText)")
        }
        if let workout = task.workoutSummary {
            parts.append(workout)
        }
        return parts.joined(separator: " · ")
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button(isMissed ? "SPLNĚNO POZDĚ" : "HOTOVO", action: onDone)
                .buttonStyle(PrimaryButtonStyle())
            Button(isMissed ? "BEZ VÝMLUV" : "PŘESKOČIT", action: onFail)
                .buttonStyle(SecondaryButtonStyle(textColor: isMissed ? Theme.red : Theme.textPrimary))
        }
    }
}
