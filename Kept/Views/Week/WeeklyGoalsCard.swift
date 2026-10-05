import SwiftUI

/// Progress towards the weekly targets ("Gym 2 / 4").
struct WeeklyGoalsCard: View {
    let goals: [WeeklyGoal]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CÍLE TÝDNE").labelStyle()
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
