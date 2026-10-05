import SwiftUI

/// Short briefing shown at the top of Today each morning until dismissed.
struct MorningBriefCard: View {
    let tasks: [TaskItem]
    let todayTasks: [TaskItem]
    let promisesKeptThisWeek: Double?
    let streak: Int
    let now: Date
    let onDismiss: () -> Void

    private var open: [TaskItem] { todayTasks.filter { $0.status == .pending } }
    private var highPriority: Int { open.filter { $0.priority.rank >= TaskPriority.high.rank }.count }
    private var deadlines: Int { open.filter { $0.deadline != nil }.count }
    private var criticalFocus: String? { open.first { $0.priority == .critical }?.title }

    private var yesterday: Double? {
        let day = now.startOfDay.addingDays(-1)
        return ScoreEngine.productivity(tasks.filter { $0.scheduledDate.isSameDay(as: day) }, now: now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("RANNÍ PŘEHLED").labelStyle()
            HStack(alignment: .top, spacing: 24) {
                figure("\(todayTasks.count)", "závazky")
                figure("\(highPriority)", "vysoká priorita")
                figure("\(deadlines)", "deadliny")
            }
            VStack(alignment: .leading, spacing: 6) {
                if let criticalFocus {
                    line("Hlavní fokus", criticalFocus)
                }
                line("Dodržené sliby tento týden", promisesKeptThisWeek.percentText)
                line("Aktuální série", String.days(streak))
            }
            Text(NotificationTemplates.morningSentence(yesterday: yesterday, seed: now.daySeed))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Button("ZAČÍT DEN", action: onDismiss)
                .buttonStyle(SecondaryButtonStyle())
        }
        .card()
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
        }
    }
}
