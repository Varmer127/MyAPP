import SwiftUI
import SwiftData

/// End-of-week self-reflection: an animated recap of what was done, then a rating and a journal entry.
struct ReflectionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var tasks: [TaskItem]
    @Query private var reflections: [WeekReflection]
    let weekStart: Date

    /// How many recap elements are visible so far; rises step by step to stage the reveal.
    @State private var stage = 0
    @State private var shownDone = 0
    @State private var satisfaction = 0
    @State private var text = ""

    private static let stepDelay: Duration = .milliseconds(450)
    private static let countDelay: Duration = .milliseconds(60)

    private var week: [TaskItem] {
        tasks.filter { $0.scheduledDate.weekStart == weekStart && !$0.isRemoved && !$0.isRecovery }
    }
    private var done: [TaskItem] { week.filter(\.isDone) }
    private var existing: WeekReflection? { reflections.first { $0.weekStart == weekStart } }

    /// "Gym 4×" rows, most frequent first.
    private var categoryCounts: [(category: TaskCategory, done: Int, total: Int)] {
        TaskCategory.allCases.compactMap { category in
            let inCategory = week.filter { $0.category == category }
            return inCategory.isEmpty ? nil : (category, inCategory.filter(\.isDone).count, inCategory.count)
        }.sorted { $0.done > $1.done }
    }

    /// Stage at which the rating and the journal appear: after the header, the total and every category row.
    private var questionStage: Int { categoryCounts.count + 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SEBEREFLEXE · TÝDEN \(weekStart.weekNumber)").labelStyle()
                        Text("\(weekStart.dayMonthText) – \(weekStart.addingDays(6).dayMonthText)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    if stage >= 1 {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(shownDone)")
                                    .font(.system(size: 72, weight: .heavy))
                                    .foregroundStyle(Theme.textPrimary)
                                    .contentTransition(.numericText())
                                Text("z \(week.count)")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Text("SPLNĚNO TENTO TÝDEN").labelStyle()
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    VStack(spacing: 14) {
                        ForEach(Array(categoryCounts.enumerated()), id: \.element.category) { index, item in
                            if stage >= index + 2 {
                                categoryRow(item)
                                    .transition(.opacity.combined(with: .move(edge: .leading)))
                            }
                        }
                    }
                    if stage >= questionStage {
                        question
                            .transition(.opacity)
                    }
                }
                .padding(Theme.screenPadding)
                .padding(.top, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            VStack(spacing: 10) {
                Button("ULOŽIT DO DENÍČKU", action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(satisfaction == 0)
                Button("POZDĚJI") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(Theme.screenPadding)
        }
        .screenBackground()
        .preferredColorScheme(.dark)
        .task { await reveal() }
        .onAppear {
            if let existing {
                satisfaction = existing.satisfaction
                text = existing.text
            }
        }
    }

    private func categoryRow(_ item: (category: TaskCategory, done: Int, total: Int)) -> some View {
        VStack(spacing: 6) {
            HStack {
                Label(item.category.title, systemImage: item.category.symbol)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(item.done)×")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("z \(item.total)")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            ThinBar(value: Double(item.done) / Double(item.total),
                    color: item.done == item.total ? Theme.green : Theme.textPrimary)
        }
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Jak jsi se sebou spokojený?")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        satisfaction = value
                    } label: {
                        Text("\(value)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(satisfaction == value ? .black : Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(satisfaction == value ? Color.white : Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(satisfaction == 0 ? "1 = vůbec, 5 = naprosto" : WeekReflection.satisfactionLabels[satisfaction - 1])
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
            Text("DENÍČEK").labelStyle().padding(.top, 6)
            TextField("Co se povedlo, co ne a co uděláš příští týden jinak?", text: $text, axis: .vertical)
                .lineLimit(5...14)
                .font(.system(size: 16))
                .card()
        }
    }

    /// Reveals the recap one element at a time and counts the total up.
    private func reveal() async {
        for step in 1...questionStage {
            try? await Task.sleep(for: Self.stepDelay)
            withAnimation(.easeOut(duration: 0.35)) { stage = step }
            if step == 1 {
                for value in 0...done.count {
                    withAnimation(.easeOut(duration: 0.1)) { shownDone = value }
                    try? await Task.sleep(for: Self.countDelay)
                }
            }
        }
    }

    private func save() {
        let now = Date.now
        let reflection = existing ?? WeekReflection(weekStart: weekStart)
        if existing == nil {
            context.insert(reflection)
        }
        let closed = week.filter { $0.isClosed(now) }
        reflection.satisfaction = satisfaction
        reflection.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        reflection.doneCount = done.count
        reflection.totalCount = week.count
        reflection.promisesKept = ScoreEngine.promisesKept(closed, now: now)
        reflection.productivity = ScoreEngine.productivity(closed, now: now)
        dismiss()
    }
}

/// Wraps a week so it can drive `fullScreenCover(item:)`.
struct ReflectionRequest: Identifiable {
    let weekStart: Date
    var id: Date { weekStart }

    private static let sundayFromHour = 18
    private static let catchUpDays = 2

    /// The week that is waiting for a reflection right now: this week from Sunday evening,
    /// or last week during the first days of the new one if it was skipped.
    static func pending(tasks: [TaskItem], reflections: [WeekReflection], now: Date = .now) -> ReflectionRequest? {
        let thisWeek = now.weekStart
        let daysIntoWeek = Calendar.app.dateComponents([.day], from: thisWeek, to: now.startOfDay).day ?? 0
        let candidate: Date
        if daysIntoWeek == 6, now.minutesIntoDay >= sundayFromHour * 60 {
            candidate = thisWeek
        } else if daysIntoWeek < catchUpDays {
            candidate = thisWeek.addingDays(-7)
        } else {
            return nil
        }
        let hasTasks = tasks.contains { $0.scheduledDate.weekStart == candidate && !$0.isRemoved }
        let isWritten = reflections.contains { $0.weekStart == candidate }
        return hasTasks && !isWritten ? ReflectionRequest(weekStart: candidate) : nil
    }
}
