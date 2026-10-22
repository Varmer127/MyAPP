import SwiftUI

/// What the month that just ended has to say: how much was kept, the best week, the longest run, the strongest area.
struct MonthStory: Identifiable {
    let monthStart: Date
    let done: Int
    let total: Int
    let percent: Int
    /// Change against the month before, in percentage points.
    let delta: Int?
    let bestWeek: (number: Int, percent: Int)?
    let longestRun: Int
    let topCategory: (title: String, symbol: String, done: Int)?

    var id: Date { monthStart }

    /// The month this story is told about when it is offered: the one that has just ended, during the first days of a new one.
    static func offeredMonth(now: Date) -> Date? {
        guard Calendar.app.component(.day, from: now) <= 5 else { return nil }
        return Calendar.app.date(byAdding: .month, value: -1, to: now.startOfMonth)?.startOfMonth
    }

    /// Nil when the month has nothing closed to talk about.
    static func make(tasks: [TaskItem], monthStart: Date, now: Date = .now) -> MonthStory? {
        let calendar = Calendar.app
        func month(_ start: Date) -> [TaskItem] {
            tasks.filter { !$0.isRemoved && $0.countsInScores && calendar.isDate($0.scheduledDate, equalTo: start, toGranularity: .month) }
        }
        let current = month(monthStart)
        let closed = current.filter { $0.isClosed(now) }
        guard !closed.isEmpty else { return nil }
        let kept = ScoreEngine.promisesKept(closed, now: now) ?? ScoreEngine.productivity(closed, now: now) ?? 0
        let before = calendar.date(byAdding: .month, value: -1, to: monthStart)?.startOfMonth
        let previousKept = before.flatMap { ScoreEngine.promisesKept(month($0).filter { $0.isClosed(now) }, now: now) }

        let byWeek = Dictionary(grouping: closed) { $0.scheduledDate.weekStart }
        let bestWeek = byWeek.compactMap { start, items in
            ScoreEngine.productivity(items, now: now).map { (start: start, value: $0) }
        }.max { $0.value < $1.value }

        let byDay = Dictionary(grouping: closed) { $0.scheduledDate.startOfDay }
        var run = 0, longest = 0
        for day in byDay.keys.sorted() {
            if let score = ScoreEngine.productivity(byDay[day] ?? [], now: now), score >= ScoreEngine.Config.streakThreshold {
                run += 1
                longest = max(longest, run)
            } else {
                run = 0
            }
        }

        let byCategory = Dictionary(grouping: closed.filter(\.isDone)) { $0.category }
        let top = byCategory.max { $0.value.count < $1.value.count }
        return MonthStory(
            monthStart: monthStart, done: closed.filter(\.isDone).count, total: current.count,
            percent: Int((kept * 100).rounded()),
            delta: previousKept.map { Int(((kept - $0) * 100).rounded()) },
            bestWeek: bestWeek.map { ($0.start.weekNumber, Int(($0.value * 100).rounded())) },
            longestRun: longest,
            topCategory: top.map { ($0.key.title, $0.key.symbol, $0.value.count) })
    }
}

/// The month story: a few full-screen cards, tapped through.
struct MonthStoryView: View {
    let story: MonthStory
    let onFinish: () -> Void
    @State private var index = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Slide { case total, bestWeek, run, category }

    private var slides: [Slide] {
        var list: [Slide] = [.total]
        if story.bestWeek != nil { list.append(.bestWeek) }
        if story.longestRun > 1 { list.append(.run) }
        if story.topCategory != nil { list.append(.category) }
        return list
    }

    var body: some View {
        let slides = slides
        let slide = slides[min(index, slides.count - 1)]
        let isLast = index >= slides.count - 1
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    ForEach(0..<slides.count, id: \.self) { step in
                        Capsule().fill(step <= index ? Theme.textPrimary : Theme.cardRaised).frame(height: 4)
                    }
                }
                .padding(.top, 8)
                HStack {
                    Text(story.monthStart.monthYearText.uppercased()).labelStyle()
                    Spacer()
                    Button("Zavřít", action: onFinish)
                        .scaledFont(.body, weight: .semibold)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(minHeight: 44)
                }
                .padding(.top, 6)
                Spacer(minLength: 0)
                content(for: slide)
                    .id(index)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                Spacer(minLength: 0)
                if isLast {
                    Button("DÁL", action: onFinish).buttonStyle(PrimaryButtonStyle())
                } else {
                    Text("Klepni pro další")
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 24)
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 12)
        }
        .contentShape(Rectangle())
        .onTapGesture { location in
            guard !isLast || location.x < 110 else { return }
            advance(by: location.x < 110 ? -1 : 1, count: slides.count)
        }
        .sensoryFeedback(.selection, trigger: index)
    }

    private func advance(by step: Int, count: Int) {
        let next = min(max(index + step, 0), count - 1)
        guard next != index else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) { index = next }
    }

    @ViewBuilder
    private func content(for slide: Slide) -> some View {
        switch slide {
        case .total:
            VStack(alignment: .leading, spacing: 10) {
                Text("\(story.done)")
                    .scaledFont(110, weight: .black)
                    .foregroundStyle(Theme.textPrimary)
                Text("slibů z \(story.total) jsi dodržel.")
                    .scaledFont(.title, weight: .heavy)
                    .foregroundStyle(Theme.textPrimary)
                Text(story.delta.map { $0 >= 0 ? "\(story.percent) %, o \($0) % víc než měsíc předtím" : "\(story.percent) %, o \(-$0) % méně než měsíc předtím" } ?? "\(story.percent) %")
                    .scaledFont(.body, weight: .bold)
                    .foregroundStyle((story.delta ?? 0) >= 0 ? Theme.green : Theme.orange)
            }
        case .bestWeek:
            VStack(alignment: .leading, spacing: 14) {
                Text("NEJLEPŠÍ TÝDEN").labelStyle()
                Text("Týden \(story.bestWeek?.number ?? 0)")
                    .scaledFont(.hero, weight: .black)
                    .foregroundStyle(Theme.textPrimary)
                Text("\(story.bestWeek?.percent ?? 0) % splněno.")
                    .scaledFont(.heading)
                    .foregroundStyle(Theme.textSecondary)
            }
        case .run:
            VStack(alignment: .leading, spacing: 14) {
                Text("NEJDELŠÍ SÉRIE V MĚSÍCI").labelStyle()
                Text("\(story.longestRun)")
                    .scaledFont(110, weight: .black)
                    .foregroundStyle(Theme.orange)
                Text("dní v řadě jsi držel slovo.")
                    .scaledFont(.heading, weight: .heavy)
                    .foregroundStyle(Theme.textPrimary)
            }
        case .category:
            VStack(alignment: .leading, spacing: 14) {
                Text("NEJSILNĚJŠÍ OBLAST").labelStyle()
                Image(systemName: story.topCategory?.symbol ?? "circle")
                    .scaledFont(.title)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 64, height: 64)
                    .background(Theme.cardRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                Text(story.topCategory?.title ?? "")
                    .scaledFont(.hero, weight: .black)
                    .foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.6)
                Text("\(story.topCategory?.done ?? 0)× splněno. Tady ti to šlo nejvíc.")
                    .scaledFont(.heading)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}
