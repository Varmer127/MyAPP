import SwiftUI
import SwiftData

struct CommitSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let plan: WeeklyPlan

    private var tasks: [TaskItem] { plan.activeTasks }

    private var categoryCounts: [(category: TaskCategory, count: Int)] {
        TaskCategory.allCases.compactMap { category in
            let count = tasks.filter { $0.category == category }.count
            return count > 0 ? (category, count) : nil
        }
    }

    private var plannedText: String {
        let minutes = tasks.reduce(0) { $0 + $1.plannedMinutes }
        return "\(minutes / 60) h \(String(format: "%02d", minutes % 60)) min planned"
    }

    private var criticalCount: Int { tasks.filter { $0.priority == .critical }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("WEEK \(plan.weekStart.weekNumber)").labelStyle()
                        Text("THIS WEEK I COMMIT TO:")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(categoryCounts, id: \.category) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("\(item.count)×")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(width: 48, alignment: .leading)
                                Text(item.category.title)
                                    .font(.system(size: 18))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(tasks.count)")
                            .font(.system(size: 64, weight: .heavy))
                            .foregroundStyle(Theme.textPrimary)
                        Text("TOTAL COMMITMENTS").labelStyle()
                        Text("\(plannedText) · \(criticalCount) critical")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 4)
                    }
                    Text("After this, removing, moving or downgrading a task is recorded. A removed task still counts as a broken promise.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(Theme.screenPadding)
                .padding(.top, 16)
            }
            VStack(spacing: 10) {
                Button("I COMMIT") {
                    PlanService.commit(plan)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("NOT YET") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(Theme.screenPadding)
        }
        .screenBackground()
        .preferredColorScheme(.dark)
    }
}
