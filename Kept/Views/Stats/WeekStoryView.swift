import SwiftUI

/// Everything the weekly story tells, worked out from the week's history.
struct WeekStory {
    let weekStart: Date
    let done: Int
    let total: Int
    let percent: Int
    /// Change against the week before, in percentage points.
    let delta: Int?
    let bestDay: (name: String, percent: Int)?
    let hardest: (title: String, symbol: String, note: String, wasDone: Bool)?
    let diaryQuote: String?
    let streak: Int
    let dayValues: [Double]

    var weekNumber: Int { weekStart.weekNumber }

    /// Nil when the week has nothing closed to talk about.
    static func make(tasks: [TaskItem], diary: [DiaryEntry], weekStart: Date, now: Date = .now) -> WeekStory? {
        func week(_ start: Date) -> [TaskItem] {
            tasks.filter { !$0.isRemoved && $0.countsInScores && $0.scheduledDate.weekStart == start }
        }
        let current = week(weekStart)
        let closed = current.filter { $0.isClosed(now) }
        guard !closed.isEmpty else { return nil }
        let kept = ScoreEngine.promisesKept(closed, now: now) ?? ScoreEngine.productivity(closed, now: now) ?? 0
        let previousKept = ScoreEngine.promisesKept(week(weekStart.addingDays(-7)).filter { $0.isClosed(now) }, now: now)
        let scores = StatisticsService.dailyScores(tasks: tasks, from: weekStart, days: 7, now: now)
        let best = scores.compactMap { score in score.productivity.map { (day: score.day, value: $0) } }
            .max { $0.value < $1.value }
        let hardTask = current.filter { $0.moveCount > 0 }.max { $0.moveCount < $1.moveCount }
            ?? current.first { $0.isLost(now) }
        let weekDiary = diary.filter { $0.day >= weekStart && $0.day < weekStart.addingDays(7) }
            .sorted { $0.day > $1.day }
        let quote = weekDiary.compactMap { entry -> String? in
            [entry.wentWell, entry.answer, entry.gratitude, entry.doDifferently, entry.wentBadly]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty }
        }.first
        return WeekStory(
            weekStart: weekStart,
            done: closed.filter(\.isDone).count,
            total: current.count,
            percent: Int((kept * 100).rounded()),
            delta: previousKept.map { Int(((kept - $0) * 100).rounded()) },
            bestDay: best.map { ($0.day.weekdayText.capitalizedFirst, Int(($0.value * 100).rounded())) },
            hardest: hardTask.map { task in
                (task.title, task.icon,
                 task.moveCount > 0 ? "\(task.moveCount)× posunutý" + (task.isDone ? ", a přece splněný." : ".") : "Tenhle slib se nepovedl.",
                 task.isDone)
            },
            diaryQuote: quote.map { String($0.prefix(140)) },
            streak: ScoreEngine.dayStreak(tasks, now: now),
            dayValues: scores.map { $0.productivity ?? 0 }
        )
    }

    /// A made-up week for trying the story out when there is no real one yet. Used only by the developer test.
    static var demo: WeekStory {
        WeekStory(weekStart: Date.now.weekStart, done: 9, total: 11, percent: 82, delta: 6,
                  bestDay: ("Středa", 100),
                  hardest: ("Gym", "dumbbell.fill", "2× posunutý, a přece splněný.", true),
                  diaryQuote: "Dneska se mi chtělo nejmíň a stejně jsem to udělal. To je ten rozdíl.",
                  streak: 9, dayValues: [1, 0.6, 1, 0.75, 1, 0.5, 0])
    }

    /// The week this story is told about when it is offered: always the one that has just ended,
    /// from its end on, until it has been seen or the next week is over.
    static func offeredWeek(now: Date) -> Date? {
        now.weekStart.addingDays(-7)
    }
}

/// The story itself: a few full-screen cards, tapped through, ending with a card to share.
struct WeekStoryView: View {
    let story: WeekStory
    let onFinish: () -> Void
    @State private var index = 0
    @State private var shareImage: Image?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Slide { case total, bestDay, hardest, diary, share }

    private var slides: [Slide] {
        var list: [Slide] = [.total]
        if story.bestDay != nil { list.append(.bestDay) }
        if story.hardest != nil { list.append(.hardest) }
        if story.diaryQuote != nil { list.append(.diary) }
        list.append(.share)
        return list
    }

    var body: some View {
        let slides = slides
        let slide = slides[min(index, slides.count - 1)]
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    ForEach(0..<slides.count, id: \.self) { step in
                        Capsule()
                            .fill(step <= index ? Theme.textPrimary : Theme.cardRaised)
                            .frame(height: 4)
                    }
                }
                .padding(.top, 8)
                HStack {
                    Text("TVŮJ TÝDEN \(story.weekNumber)").labelStyle()
                    Spacer()
                    Button("Zavřít", action: onFinish)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(minHeight: 44)
                }
                .padding(.top, 6)
                Spacer(minLength: 0)
                content(for: slide)
                    .id(index)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                Spacer(minLength: 0)
                Text(slide == .share ? "" : "Klepni pro další")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, minHeight: 24)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 12)
        }
        .contentShape(Rectangle())
        .onTapGesture { location in
            guard slide != .share else { return }
            advance(by: location.x < 110 ? -1 : 1, count: slides.count)
        }
        .sensoryFeedback(.selection, trigger: index)
        .task {
            let renderer = ImageRenderer(content: WeekStoryShareCard(story: story).environment(\.colorScheme, .dark))
            renderer.scale = 3
            if let image = renderer.uiImage { shareImage = Image(uiImage: image) }
        }
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
                (Text("\(story.done)").font(.system(size: 110, weight: .black))
                 + Text(" / \(story.total)").font(.system(size: 48, weight: .black)).foregroundColor(Theme.textTertiary))
                    .foregroundStyle(Theme.textPrimary)
                Text("slibů jsi dodržel.")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                Text(story.delta.map { "\(story.percent) %, \($0 >= 0 ? "o" : "o") \(abs($0)) % \($0 >= 0 ? "víc" : "méně") než minule" } ?? "\(story.percent) %")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle((story.delta ?? 0) >= 0 ? Theme.green : Theme.orange)
            }
        case .bestDay:
            VStack(alignment: .leading, spacing: 14) {
                Text("NEJLEPŠÍ DEN").labelStyle()
                Text(story.bestDay?.name ?? "")
                    .font(.system(size: 60, weight: .black))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(story.bestDay?.percent ?? 0) % splněno.")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.textSecondary)
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(Array(story.dayValues.enumerated()), id: \.offset) { index, value in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(value == story.dayValues.max() && value > 0 ? Theme.green : Theme.cardRaised)
                                .frame(height: max(value * 140, 6))
                            Text(["P", "Ú", "S", "Č", "P", "S", "N"][index])
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 170, alignment: .bottom)
                    }
                }
                .padding(.top, 8)
            }
        case .hardest:
            VStack(alignment: .leading, spacing: 14) {
                Text("NEJTĚŽŠÍ SLIB").labelStyle()
                Image(systemName: story.hardest?.symbol ?? "circle")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 64, height: 64)
                    .background(Theme.cardRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                Text(story.hardest?.title ?? "")
                    .font(.system(size: 50, weight: .black))
                    .foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                Text(story.hardest?.note ?? "")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.textSecondary)
                if story.hardest?.wasDone == true {
                    Text("Neustoupil jsi.")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Theme.orange)
                }
            }
        case .diary:
            VStack(alignment: .leading, spacing: 16) {
                Text("Z TVÉHO DENÍKU").labelStyle()
                Text("„\(story.diaryQuote ?? "")“")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Tohle sis tenhle týden napsal. Zůstává jen tvoje.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
            }
        case .share:
            VStack(spacing: 16) {
                WeekStoryShareCard(story: story)
                    .scaleEffect(0.92)
                if let shareImage {
                    ShareLink(item: shareImage, preview: SharePreview("Kept – týden \(story.weekNumber)", image: shareImage)) {
                        Text("SDÍLET KARTU")
                            .font(.system(size: 15, weight: .heavy))
                            .tracking(0.8)
                            .foregroundStyle(Theme.onPrimary)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(Theme.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                Button("Hotovo", action: onFinish)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(minHeight: 44)
            }
        }
    }
}

/// The card that is shared: no task names, only the numbers of the week.
struct WeekStoryShareCard: View {
    let story: WeekStory

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white).frame(width: 84, height: 84)
                CheckStroke()
                    .stroke(Color.black, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                    .frame(width: 44, height: 34)
                    .offset(y: -5)
                Capsule().fill(Color(red: 0.19, green: 0.82, blue: 0.35)).frame(width: 38, height: 5).offset(y: 26)
            }
            Text("TÝDEN \(story.weekNumber)")
                .font(.system(size: 12, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(Color(white: 0.6))
            Text("Držel jsem slovo.")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(.white)
            Text("\(story.percent) %")
                .font(.system(size: 56, weight: .black))
                .foregroundStyle(Color(red: 0.19, green: 0.82, blue: 0.35))
            Text("\(story.done) z \(story.total) slibů" + (story.streak > 1 ? " · série \(story.streak) dní" : ""))
                .font(.system(size: 13))
                .foregroundStyle(Color(white: 0.6))
        }
        .padding(28)
        .frame(width: 300)
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
