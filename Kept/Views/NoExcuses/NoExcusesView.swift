import SwiftUI
import SwiftData

/// Mandatory three-step flow before a task can be skipped or a missed task closed.
struct NoExcusesView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FailureRecord.date, order: .reverse) private var history: [FailureRecord]

    let task: TaskItem
    let kind: FailureKind

    @State private var step: Step = .reason
    @State private var reason: FailureReason?
    @State private var critique = ""
    @State private var prevention = ""

    private static let minimumCritiqueLength = 20
    private static let minimumPreventionLength = 10

    private enum Step: Int, CaseIterable {
        case reason, critique, prevention

        var title: String {
            switch self {
            case .reason: "PROČ JSI SELHAL?"
            case .critique: "SEBEKRITIKA"
            case .prevention: "CO UDĚLÁŠ JINAK?"
            }
        }
    }

    private var previousFailures: [FailureRecord] {
        let key = FailureRecord.key(for: task.title)
        return history.filter { $0.titleKey == key }
    }

    private var critiqueLength: Int { critique.trimmingCharacters(in: .whitespacesAndNewlines).count }
    private var preventionLength: Int { prevention.trimmingCharacters(in: .whitespacesAndNewlines).count }

    private var canContinue: Bool {
        switch step {
        case .reason: reason != nil
        case .critique: critiqueLength >= Self.minimumCritiqueLength
        case .prevention: preventionLength >= Self.minimumPreventionLength
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heading
                    switch step {
                    case .reason: reasonStep
                    case .critique: critiqueStep
                    case .prevention: preventionStep
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            Button(step == .prevention ? "BERU TO NA SEBE" : "POKRAČOVAT", action: advance)
                .buttonStyle(PrimaryButtonStyle(color: step == .prevention ? Theme.red : .white,
                                                textColor: step == .prevention ? .white : .black))
                .disabled(!canContinue)
                .padding(Theme.screenPadding)
        }
        .screenBackground()
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.rawValue) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? Theme.red : Theme.cardRaised)
                    .frame(height: 3)
            }
            Button {
                if let previous = Step(rawValue: step.rawValue - 1) {
                    step = previous
                } else {
                    dismiss()
                }
            } label: {
                Text(step == .reason ? "Zrušit" : "Zpět")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.leading, 10)
        }
        .padding(Theme.screenPadding)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(kind == .missed ? "NESPLNĚNO · \(task.scheduledDate.weekdayText.uppercased())" : "PŘESKAKUJEŠ")
                .labelStyle(Theme.red)
            Text(task.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(step.title).labelStyle()
                .padding(.top, 6)
        }
    }

    private var reasonStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let last = previousFailures.first {
                memoryCard(last)
            }
            if !task.stake.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TVOJE SÁZKA").labelStyle(Theme.orange)
                    Text("„\(task.stake)“")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Vsadil ses sám se sebou. Zeptám se tě, jestli jsi ji dodržel.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
                .card()
            }
            if !task.why.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ŘEKL JSI, ŽE NA TOM ZÁLEŽÍ, PROTOŽE").labelStyle()
                    Text("„\(task.why)“")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textPrimary)
                }
                .card()
            }
            ForEach(FailureReason.allCases) { option in
                Button {
                    reason = option
                } label: {
                    HStack {
                        Text(option.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        if reason == option {
                            Image(systemName: "checkmark").foregroundStyle(Theme.red)
                        }
                    }
                    .padding(16)
                    .background(reason == option ? Theme.cardRaised : Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(reason == option ? Theme.red.opacity(0.6) : Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func memoryCard(_ last: FailureRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("UŽ \(previousFailures.count)× NESPLNĚNO").labelStyle(Theme.red)
            Text("Minule (\(last.date.weekdayText) \(last.date.dayMonthText)) jsi zvolil „\(last.reason.title)“ a napsal:")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
            Text("„\(last.critique)“")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textPrimary)
            if !last.prevention.isEmpty {
                Text("Slíbil jsi: „\(last.prevention)“")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .card()
    }

    private var critiqueStep: some View {
        textStep(prompt: "Proč se to doopravdy stalo?", text: $critique,
                 length: critiqueLength, minimum: Self.minimumCritiqueLength)
    }

    private var preventionStep: some View {
        textStep(prompt: "Co zabrání tomu, aby se to opakovalo?", text: $prevention,
                 length: preventionLength, minimum: Self.minimumPreventionLength)
    }

    private func textStep(prompt: String, text: Binding<String>, length: Int, minimum: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(prompt)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            TextField("Buď upřímný. Nikdo jiný to nečte.", text: text, axis: .vertical)
                .lineLimit(5...12)
                .font(.system(size: 16))
                .card()
            Text(length >= minimum ? "Znaků: \(length)" : "Chybí ještě znaků: \(minimum - length)")
                .font(.system(size: 12))
                .foregroundStyle(length >= minimum ? Theme.textTertiary : Theme.orange)
        }
    }

    private func advance() {
        if let next = Step(rawValue: step.rawValue + 1) {
            withAnimation(.easeInOut(duration: 0.2)) { step = next }
            return
        }
        guard let reason else { return }
        let record = FailureRecord(
            task: task,
            kind: kind,
            reason: reason,
            critique: critique.trimmingCharacters(in: .whitespacesAndNewlines),
            prevention: prevention.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        context.insert(record)
        task.status = kind == .skipped ? .skipped : .failed
        task.completedAt = nil
        dismiss()
    }
}
