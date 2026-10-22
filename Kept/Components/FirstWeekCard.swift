import SwiftUI

/// The first days with the app as five small steps, the first two already done when the guide is finished.
/// A list that starts partly filled gets finished far more often than one that starts empty.
struct FirstWeekCard: View {
    let tasks: [TaskItem]
    let plans: [WeeklyPlan]
    let streak: Int
    let onboardedAt: Date?
    let onOpenWeek: () -> Void
    @AppStorage("firstWeekDismissed") private var dismissed = false

    private struct Step: Identifiable {
        let id: Int
        let title: LocalizedStringKey
        let isDone: Bool
    }

    private var steps: [Step] {
        [
            Step(id: 0, title: "Nastavil sis Kept", isDone: onboardedAt != nil),
            Step(id: 1, title: "Přidal sis první slib", isDone: !tasks.isEmpty),
            Step(id: 2, title: "Zapečetil sis první týden", isDone: plans.contains(where: \.isCommitted)),
            Step(id: 3, title: "Dodržel jsi první slib", isDone: tasks.contains(where: \.isDone)),
            Step(id: 4, title: "Držel jsi slovo 3 dny v řadě", isDone: streak >= 3),
        ]
    }

    /// Shown for two weeks after the guide, until everything is done or it is hidden.
    static func isShown(onboardedAt: Date?, now: Date = .now) -> Bool {
        guard let onboardedAt else { return false }
        return now.timeIntervalSince(onboardedAt) < 14 * 86_400
    }

    var body: some View {
        let steps = steps
        let done = steps.filter(\.isDone).count
        if !dismissed, done < steps.count, Self.isShown(onboardedAt: onboardedAt) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("PRVNÍ TÝDEN · \(done) Z \(steps.count)").labelStyle(Theme.textPrimary)
                    Spacer()
                    Button {
                        withAnimation { dismissed = true }
                    } label: {
                        Image(systemName: "xmark")
                            .scaledFont(.caption, weight: .bold)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .padding(.trailing, -12)
                    .padding(.vertical, -12)
                    .accessibilityLabel("Skrýt")
                }
                ThinBar(value: Double(done) / Double(steps.count), color: Theme.green)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(steps) { step in
                        let isNext = step.id == steps.first(where: { !$0.isDone })?.id
                        HStack(spacing: 10) {
                            Image(systemName: step.isDone ? "checkmark.circle.fill" : (isNext ? "circle.dotted" : "circle"))
                                .foregroundStyle(step.isDone ? Theme.green : (isNext ? Theme.textPrimary : Theme.textTertiary))
                            Text(step.title)
                                .scaledFont(.body, weight: isNext ? .semibold : .regular)
                                .foregroundStyle(step.isDone ? Theme.textSecondary : Theme.textPrimary)
                                .strikethrough(step.isDone, color: Theme.textTertiary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityValue(step.isDone ? "splněno" : "čeká")
                    }
                }
                if steps.first(where: { !$0.isDone })?.id == 2 {
                    Button("ZAPEČETIT TÝDEN", action: onOpenWeek)
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
            .card()
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }
}
