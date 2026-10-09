import SwiftUI

struct TaskCard: View {
    let task: TaskItem
    let now: Date
    /// Failure-memory line shown when this task keeps being failed.
    var warning: String?
    var onTap: () -> Void = {}
    var onDone: () -> Void = {}
    var onFail: () -> Void = {}
    var onFocus: () -> Void = {}
    var onPartial: () -> Void = {}

    private static let deadlineWarningWindow: TimeInterval = 3600

    private var isMissed: Bool { task.isMissed(now) }
    private var isOverdue: Bool { task.isOverdue(now) }
    private var isApproaching: Bool {
        guard task.status == .pending, let deadline = task.deadline else { return false }
        return now <= deadline && deadline.timeIntervalSince(now) <= Self.deadlineWarningWindow
    }

    private var isFocusing: Bool { task.status == .pending && task.activeFocusSession != nil }

    private var accent: Color {
        if task.isPartial { return Theme.orange }
        if task.isDone { return Theme.green }
        if isOverdue || task.status == .failed || task.status == .skipped { return Theme.red }
        if isApproaching || isFocusing { return Theme.orange }
        return .clear
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            badges
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    if task.isDone {
                        Image(systemName: task.isPartial ? "circle.lefthalf.filled" : "checkmark.circle.fill")
                            .foregroundStyle(task.isPartial ? Theme.orange : Theme.green)
                            .symbolEffect(.bounce, options: .nonRepeating, value: task.isDone)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Text(task.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(task.status == .pending ? Theme.textPrimary : Theme.textSecondary)
                }
                HStack(spacing: 6) {
                    Image(systemName: task.category.symbol)
                    Text(metadata)
                }
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
            }
            if let warning, task.status == .pending {
                Text(warning)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.red)
                    .fixedSize(horizontal: false, vertical: true)
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
        if task.isPartial {
            items.append(("Částečně \(Int((task.completionShare * 100).rounded())) %", Theme.orange))
        }
        if task.priority == .critical {
            items.append((TaskPriority.critical.badge, task.status == .pending ? Theme.textPrimary : Theme.textSecondary))
        } else if task.priority == .high {
            items.append((TaskPriority.high.badge, Theme.textSecondary))
        }
        if task.moveCount > 0 { items.append(("Přesunuto", Theme.textSecondary)) }
        if task.isAddedAfterCommitment { items.append(("Přidáno později", Theme.textSecondary)) }
        if task.isRecovery { items.append(("Recovery", Theme.orange)) }
        if task.requiresProof, task.status == .pending { items.append(("Důkaz", Theme.textSecondary)) }
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

    /// The running focus timer, ticking right on the card. Tapping it opens the full-screen timer.
    private func liveTimer(_ session: FocusSession) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let remaining = session.remaining(at: timeline.date)
            let isOvertime = remaining < 0
            // Running over the plan is neutral, unless a deadline is set — then it means falling behind.
            let isBehind = isOvertime && task.deadline != nil
            let highlighted = session.isPaused || isBehind
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.isPaused ? "FOCUS POZASTAVEN" : (isBehind ? "NESTÍHÁŠ PLÁN" : (isOvertime ? "NAD PLÁN" : "FOCUS BĚŽÍ")))
                        .labelStyle(highlighted ? Theme.orange : Theme.textSecondary)
                    Text("\(isOvertime ? "+" : "")\(FocusView.clock(abs(remaining)))")
                        .font(.system(size: 34, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                Button {
                    FocusView.togglePause(session, title: task.title)
                } label: {
                    timerIcon(session.isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.plain)
                timerIcon("arrow.up.left.and.arrow.down.right")
            }
            .padding(14)
            .background(Theme.cardRaised)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
            .contentShape(Rectangle())
            .onTapGesture(perform: onFocus)
        }
    }

    /// The running workout stopwatch: total time, or the current rest between sets.
    private func gymTimer(_ session: FocusSession) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let rest = session.pausedSince.map { timeline.date.timeIntervalSince($0) }
            let total = session.active(at: timeline.date) + session.paused(at: timeline.date)
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rest == nil ? "TRÉNINK BĚŽÍ" : "PAUZA")
                        .labelStyle(rest == nil ? Theme.textSecondary : Theme.orange)
                    Text(FocusView.clock(rest ?? total))
                        .font(.system(size: 34, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                timerIcon("arrow.up.left.and.arrow.down.right")
            }
            .padding(14)
            .background(Theme.cardRaised)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
            .contentShape(Rectangle())
            .onTapGesture(perform: onFocus)
        }
    }

    private func timerIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .frame(width: 44, height: 44)
            .background(Theme.card)
            .clipShape(Circle())
    }

    private var actions: some View {
        VStack(spacing: 10) {
            // With a focus timer the main action is to start working; DONE moves to the second row.
            let isGym = task.category == .gym
            let offersFocus = (task.usesFocus || isFocusing || isGym) && !isMissed
            if offersFocus {
                if let session = task.activeFocusSession {
                    if isGym {
                        gymTimer(session)
                    } else {
                        liveTimer(session)
                    }
                } else {
                    Button(isGym ? "SPUSTIT TRÉNINK" : "SPUSTIT FOCUS", action: onFocus)
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            HStack(spacing: 8) {
                // Colour follows the outcome each button leads to: green done, orange partial or late, red giving up.
                if offersFocus {
                    Button("HOTOVO", action: onDone)
                        .buttonStyle(SecondaryButtonStyle(textColor: Theme.green))
                } else {
                    Button(isMissed ? "SPLNĚNO POZDĚ" : "HOTOVO", action: onDone)
                        .buttonStyle(PrimaryButtonStyle(color: isMissed ? Theme.orange : Theme.green))
                }
                if !isMissed {
                    Button("ČÁSTEČNĚ", action: onPartial)
                        .buttonStyle(SecondaryButtonStyle(textColor: Theme.orange))
                }
                Button(isMissed ? "BEZ VÝMLUV" : "PŘESKOČIT", action: onFail)
                    .buttonStyle(SecondaryButtonStyle(textColor: Theme.red))
            }
        }
    }
}
