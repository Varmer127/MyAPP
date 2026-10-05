import SwiftUI
import SwiftData

struct CommitSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [UserSettings]
    @Query private var allTasks: [TaskItem]
    let plan: WeeklyPlan

    private var minimum: Int { settingsList.first?.minimumWeeklyTasks ?? UserSettings.defaultMinimumWeeklyTasks }
    private var missingActivities: Int { max(0, minimum - tasks.count) }

    /// The minimum is a hard rule for a week planned ahead (up to the end of its Monday).
    /// A week that is already running can still be committed, with a warning.
    private var minimumBlocksCommit: Bool {
        missingActivities > 0 && Date.now < plan.weekStart.addingDays(1)
    }

    /// Weekly targets the plan does not cover.
    private var shortfalls: [(category: TaskCategory, planned: Int, target: Int)] {
        let settings = settingsList.first
        return TaskCategory.allCases.compactMap { category in
            let target = settings?.weeklyTarget(for: category) ?? category.defaultWeeklyTarget
            let planned = tasks.filter { $0.category == category }.count
            return planned < target ? (category, planned, target) : nil
        }
    }

    private var tasks: [TaskItem] { plan.committableTasks }

    private var categoryCounts: [(category: TaskCategory, count: Int)] {
        TaskCategory.allCases.compactMap { category in
            let count = tasks.filter { $0.category == category }.count
            return count > 0 ? (category, count) : nil
        }
    }

    private var plannedText: String {
        let minutes = tasks.reduce(0) { $0 + $1.plannedMinutes }
        return "Naplánováno \(minutes / 60) h \(String(format: "%02d", minutes % 60)) min"
    }

    private var criticalCount: Int { tasks.filter { $0.priority == .critical }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TÝDEN \(plan.weekStart.weekNumber)").labelStyle()
                        Text("TENTO TÝDEN SE ZAVAZUJI K:")
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
                                Label(item.category.title, systemImage: item.category.symbol)
                                    .font(.system(size: 18))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(tasks.count)")
                            .font(.system(size: 64, weight: .heavy))
                            .foregroundStyle(Theme.textPrimary)
                        Text("ZÁVAZKŮ CELKEM").labelStyle()
                        Text("\(plannedText) · kritické: \(criticalCount)")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 4)
                    }
                    if missingActivities > 0 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("POD MINIMEM").labelStyle(minimumBlocksCommit ? Theme.red : Theme.orange)
                            Text("Minimum je \(minimum) aktivit týdně, v plánu máš \(tasks.count). Chybí \(missingActivities).")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textPrimary)
                            Text(minimumBlocksCommit
                                 ? "Dokud je nedoplníš, zavázat se nejde."
                                 : "Týden už běží, takže se zavázat můžeš i tak.")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    if !shortfalls.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("POD TÝDENNÍM CÍLEM").labelStyle(Theme.orange)
                            ForEach(shortfalls, id: \.category) { item in
                                Text("\(item.category.title): v plánu \(item.planned), cíl \(item.target)")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                        }
                    }
                    let advice = PatternDetectionService.planningAdvice(planned: tasks, history: allTasks,
                                                                        weekStart: plan.weekStart)
                    if !advice.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NEŽ SE ZAVÁŽEŠ").labelStyle(Theme.orange)
                            ForEach(advice, id: \.self) { line in
                                Text(line)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    Text("Od této chvíle se každé odstranění, přesun nebo snížení úkolu zaznamená. Odstraněný úkol se dál počítá jako porušený slib.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(Theme.screenPadding)
                .padding(.top, 16)
            }
            VStack(spacing: 10) {
                Button("ZAVAZUJI SE") {
                    PlanService.commit(plan)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(minimumBlocksCommit)
                Button("JEŠTĚ NE") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(Theme.screenPadding)
        }
        .screenBackground()
        .preferredColorScheme(.dark)
    }
}
