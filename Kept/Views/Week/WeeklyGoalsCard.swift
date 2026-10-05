import SwiftUI

/// Progress towards the weekly targets ("Gym 2 / 4").
struct WeeklyGoalsCard: View {
    let goals: [WeeklyGoal]
    /// All activities of the week against the weekly minimum; nil when the minimum is off.
    var total: (planned: Int, done: Int, minimum: Int)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CÍLE TÝDNE").labelStyle()
            if let total {
                let isShort = total.planned < total.minimum
                VStack(spacing: 6) {
                    HStack {
                        Text("Aktivity celkem")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(isShort ? "v plánu jen \(total.planned)" : "v plánu \(total.planned)")
                            .font(.system(size: 12))
                            .foregroundStyle(isShort ? Theme.orange : Theme.textSecondary)
                        Spacer()
                        Text("\(total.done) / \(total.minimum)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    ThinBar(value: Double(total.done) / Double(total.minimum),
                            color: total.done >= total.minimum ? Theme.green : Theme.textPrimary)
                }
            }
            ForEach(goals) { goal in
                VStack(spacing: 6) {
                    HStack {
                        Text(goal.category.title)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textPrimary)
                        if goal.planned > 0, !goal.isMet {
                            Text("+\(goal.planned) v plánu")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Text("\(goal.done) / \(goal.target)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    ThinBar(value: Double(goal.done) / Double(goal.target),
                            color: goal.isMet ? Theme.green : Theme.textPrimary)
                }
            }
        }
        .card()
    }
}
