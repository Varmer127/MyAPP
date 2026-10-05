import SwiftUI
import SwiftData

/// Evening confrontation with the day: what was promised vs. what was done.
struct RealityCheckView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var tasks: [TaskItem]
    @State private var excuse: ExcuseRequest?
    @State private var isEndingDay = false

    private var today: [TaskItem] {
        tasks.filter { !$0.isRemoved && $0.scheduledDate.isSameDay(as: .now) }
    }
    private var remaining: [TaskItem] {
        today.filter { $0.status == .pending }.sorted { $0.priority.rank > $1.priority.rank }
    }
    private var completed: Int { today.filter(\.isDone).count }
    private var rate: Double? { today.isEmpty ? nil : Double(completed) / Double(today.count) }

    private var verdict: String {
        guard let rate else { return "Dnes jsi neměl žádný závazek." }
        if remaining.isEmpty, rate == 1 { return "Dnes jsi dodržel slovo." }
        return "Je \(rate.percentText) výkon, který odpovídá tomu, kam se chceš dostat?"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("VEČERNÍ BILANCE").labelStyle(Theme.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rate.percentText)
                            .font(.system(size: 72, weight: .heavy))
                            .foregroundStyle(Theme.performanceColor(rate))
                        Text("DNES DODRŽENÉ SLIBY").labelStyle()
                    }
                    HStack(spacing: 10) {
                        MetricTile(value: "\(today.count)", label: "Slíbil jsi")
                        MetricTile(value: "\(completed)", label: "Splněno")
                        MetricTile(value: "\(remaining.count)", label: "Zbývá",
                                   color: remaining.isEmpty ? Theme.textPrimary : Theme.red)
                    }
                    Text(verdict)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    if !remaining.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Stále otevřené")
                            ForEach(remaining) { task in
                                Text(task.title)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                        }
                    }
                }
                .padding(Theme.screenPadding)
                .padding(.top, 24)
            }
            VStack(spacing: 10) {
                if remaining.isEmpty {
                    Button("ZAVŘÍT") { dismiss() }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("NAPRAVIT TO") { dismiss() }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("UKONČIT DEN") {
                        isEndingDay = true
                        explainNext()
                    }
                    .buttonStyle(SecondaryButtonStyle(textColor: Theme.red))
                }
            }
            .padding(Theme.screenPadding)
        }
        .screenBackground()
        .preferredColorScheme(.dark)
        // Ending the day walks every open task through No Excuses, one after another.
        // Cancelling one of them stops the walk and leaves the rest open.
        .fullScreenCover(item: $excuse, onDismiss: continueEndingDay) {
            NoExcusesView(task: $0.task, kind: .missed)
        }
    }

    private func explainNext() {
        if let next = remaining.first {
            excuse = ExcuseRequest(task: next, kind: .missed)
        } else {
            isEndingDay = false
        }
    }

    private func continueEndingDay() {
        guard isEndingDay else { return }
        explainNext()
    }
}
