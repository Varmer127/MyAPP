import SwiftUI
import SwiftData

/// Moves a task to another day without any penalty, using up one of the month's few allowances.
struct PostponeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let task: TaskItem
    let remaining: Int
    let limit: Int

    @State private var day = Date.now.startOfDay.addingDays(1)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ODKLAD BEZ POSTIHU").labelStyle()
                        Text(task.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Tento měsíc ti zbývá \(remaining) z \(limit). Odložený úkol se nepočítá jako selhání ani jako změna plánu.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    HStack(spacing: 10) {
                        quickDay("Zítra", offset: 1)
                        quickDay("Pozítří", offset: 2)
                    }
                    DatePicker("Jiný den", selection: $day, in: Date.now.startOfDay.addingDays(1)..., displayedComponents: .date)
                        .card()
                }
                .padding(Theme.screenPadding)
                .padding(.top, 16)
            }
            VStack(spacing: 10) {
                Button("ODLOŽIT NA \(day.shortDayText.uppercased())") {
                    PlanService.postpone(task, to: day, in: context)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("ZRUŠIT") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(Theme.screenPadding)
        }
        .screenBackground()
        .preferredColorScheme(.dark)
    }

    private func quickDay(_ title: String, offset: Int) -> some View {
        let target = Date.now.startOfDay.addingDays(offset)
        let isSelected = day.isSameDay(as: target)
        return Button(title.uppercased()) { day = target }
            .buttonStyle(SecondaryButtonStyle(textColor: isSelected ? .black : Theme.textPrimary))
            .background(isSelected ? Color.white : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
