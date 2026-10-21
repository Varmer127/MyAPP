import AppIntents
import SwiftUI
import WidgetKit

// All of these read the same snapshot the app writes, through the Today widget's timeline.

// MARK: Gym

/// The running workout with its stopwatch and rest button, or this week's training when none runs.
struct GymWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KeptGym", provider: TodayProvider()) { entry in
            GymWidgetView(entry: entry)
                .containerBackground(WidgetStyle.background, for: .widget)
        }
        .configurationDisplayName("Kept – gym")
        .description("Stopky tréninku s pauzou, nebo kolikrát jsi byl tento týden v gymu.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

struct GymWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    private var snapshot: WidgetSnapshot? { entry.snapshot }
    private var gym: WidgetSnapshot.Gym? { snapshot?.gym }
    private var thisWeek: Int {
        guard let snapshot, snapshot.day.weekStartForWidget == entry.date.weekStartForWidget else { return 0 }
        return snapshot.gymThisWeek ?? 0
    }
    private var target: Int { snapshot?.gymTarget ?? 0 }

    var body: some View {
        switch family {
        case .accessoryCircular:
            if let gym {
                VStack(spacing: 1) {
                    Image(systemName: gym.restStart == nil ? "dumbbell.fill" : "pause.fill").font(.system(size: 11))
                    timer(gym).font(.system(size: 12, weight: .semibold)).multilineTextAlignment(.center)
                }
            } else {
                Gauge(value: Double(min(thisWeek, max(target, 1))), in: 0...Double(max(target, 1))) {
                    Image(systemName: "dumbbell.fill")
                } currentValueLabel: {
                    Text("\(thisWeek)")
                }
                .gaugeStyle(.accessoryCircularCapacity)
            }
        case .accessoryRectangular:
            if let gym {
                VStack(alignment: .leading, spacing: 1) {
                    Text(restLabel(gym)).font(.caption2)
                    Text(gym.startDate, style: .timer).font(.title3.weight(.bold)).monospacedDigit()
                    Text(gym.workout).font(.caption).lineLimit(1)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gym · \(thisWeek)\(target > 0 ? " / \(target)" : "") tento týden").font(.headline)
                    Text(lastText).font(.caption)
                }
            }
        case .systemMedium:
            if let gym {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        WidgetStyle.label("TRÉNINK · \(gym.workout.uppercased())")
                            .lineLimit(1)
                        Text(gym.startDate, style: .timer)
                            .font(.system(size: 36, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(WidgetStyle.text)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        restInfo(gym)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    restButton(gym)
                        .frame(width: 112)
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    weekSummary
                    VStack(alignment: .leading, spacing: 6) {
                        WidgetStyle.label("POSLEDNĚ")
                        Text(lastText)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(WidgetStyle.text)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                        Text("Trénink spustíš u úkolu Gym v aplikaci.")
                            .font(.system(size: 11))
                            .foregroundStyle(WidgetStyle.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        default:
            if let gym {
                VStack(alignment: .leading, spacing: 4) {
                    WidgetStyle.label("TRÉNINK")
                    Text(gym.startDate, style: .timer)
                        .font(.system(size: 30, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(WidgetStyle.text)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    restInfo(gym)
                    Spacer(minLength: 0)
                    restButton(gym)
                }
            } else {
                weekSummary
            }
        }
    }

    private var lastText: String {
        guard let last = snapshot?.lastGym else { return "Zatím žádný trénink" }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: last),
                                                   to: Calendar.current.startOfDay(for: entry.date)).day ?? 0
        switch days {
        case ..<1: return "Dnes"
        case 1: return "Včera"
        default: return "Před \(days) dny"
        }
    }

    private var weekSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                WidgetStyle.label("GYM TENTO TÝDEN")
                Spacer(minLength: 0)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(WidgetStyle.secondary)
            }
            Text(target > 0 ? "\(thisWeek) / \(target)" : "\(thisWeek)×")
                .font(.system(size: 40, weight: .heavy))
                .foregroundStyle(target > 0 && thisWeek >= target ? WidgetStyle.green : WidgetStyle.text)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Spacer(minLength: 0)
            if target > 0 {
                HStack(spacing: 4) {
                    ForEach(0..<target, id: \.self) { index in
                        Capsule()
                            .fill(index < thisWeek ? WidgetStyle.green : WidgetStyle.track)
                            .frame(height: 6)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func isOver(_ gym: WidgetSnapshot.Gym) -> Bool {
        guard let end = gym.restEnd else { return false }
        return end <= entry.date
    }

    private func restLabel(_ gym: WidgetSnapshot.Gym) -> String {
        gym.restStart == nil ? "TRÉNINK BĚŽÍ" : (isOver(gym) ? "JDI NA DALŠÍ SÉRII" : "PAUZA")
    }

    @ViewBuilder
    private func timer(_ gym: WidgetSnapshot.Gym) -> some View {
        if let start = gym.restStart, let end = gym.restEnd, !isOver(gym) {
            Text(timerInterval: start...end, countsDown: true).monospacedDigit()
        } else {
            Text(gym.startDate, style: .timer).monospacedDigit()
        }
    }

    @ViewBuilder
    private func restInfo(_ gym: WidgetSnapshot.Gym) -> some View {
        if let start = gym.restStart, let end = gym.restEnd {
            let over = isOver(gym)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    WidgetStyle.label(over ? "DALŠÍ SÉRIE" : "PAUZA", color: over ? WidgetStyle.green : WidgetStyle.orange)
                    if !over {
                        Text(timerInterval: start...end, countsDown: true)
                            .font(.system(size: 13, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(WidgetStyle.text)
                    }
                }
                ProgressView(timerInterval: start...end, countsDown: false, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                    .tint(over ? WidgetStyle.green : WidgetStyle.orange)
            }
        } else {
            Text("Pauza \(WidgetStyle.clock(Double(gym.restSeconds)))")
                .font(.system(size: 12))
                .foregroundStyle(WidgetStyle.secondary)
        }
    }

    private func restButton(_ gym: WidgetSnapshot.Gym) -> some View {
        let resting = gym.restStart != nil
        return Button(intent: GymRestIntent(start: !resting)) {
            Label(resting ? "DALŠÍ SÉRIE" : "PAUZA", systemImage: resting ? "forward.fill" : "timer")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(resting ? Color.black : WidgetStyle.onText)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(resting ? (isOver(gym) ? WidgetStyle.green : WidgetStyle.orange) : WidgetStyle.text)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: Streak

/// The day streak as a flame and a number.
struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KeptStreak", provider: TodayProvider()) { entry in
            StreakWidgetView(entry: entry)
                .containerBackground(WidgetStyle.background, for: .widget)
        }
        .configurationDisplayName("Kept – série")
        .description("Kolik dní v řadě držíš slovo.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryInline])
    }
}

struct StreakWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    private var streak: Int { entry.snapshot?.streak ?? 0 }
    private var today: WidgetSnapshot? { entry.today }
    private var isDayDone: Bool { (today?.total ?? 0) > 0 && today?.done == today?.total }

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("Série \(streak) \(streak == 1 ? "den" : (2...4).contains(streak) ? "dny" : "dní")", systemImage: "flame.fill")
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "flame.fill").font(.system(size: 14))
                Text("\(streak)").font(.system(size: 20, weight: .bold))
            }
        default:
            VStack(alignment: .leading, spacing: 4) {
                WidgetStyle.label("SÉRIE")
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(streak > 0 ? WidgetStyle.orange : WidgetStyle.secondary)
                    Text("\(streak)")
                        .font(.system(size: 48, weight: .heavy))
                        .foregroundStyle(WidgetStyle.text)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                Text(streak == 1 ? "den v řadě" : (2...4).contains(streak) ? "dny v řadě" : "dní v řadě")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WidgetStyle.text)
                Spacer(minLength: 0)
                Text(isDayDone ? "Dnešek splněn" : (today?.total ?? 0) > 0 ? "Dnes zbývá \((today?.total ?? 0) - (today?.done ?? 0))" : "Dnes nic v plánu")
                    .font(.system(size: 11))
                    .foregroundStyle(isDayDone ? WidgetStyle.green : WidgetStyle.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: Week

/// This week day by day: how much of each day's plan got done.
struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KeptWeek", provider: TodayProvider()) { entry in
            WeekWidgetView(entry: entry)
                .containerBackground(WidgetStyle.background, for: .widget)
        }
        .configurationDisplayName("Kept – týden")
        .description("Splněné úkoly po dnech a dodržené sliby tohoto týdne.")
        .supportedFamilies([.systemMedium])
    }
}

struct WeekWidgetView: View {
    let entry: TodayEntry

    private static let weekdays = ["Po", "Út", "St", "Čt", "Pá", "So", "Ne"]

    private var days: [WidgetSnapshot.Day] {
        guard let snapshot = entry.snapshot, snapshot.day.weekStartForWidget == entry.date.weekStartForWidget else { return [] }
        return snapshot.week ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                WidgetStyle.label("TENTO TÝDEN")
                Spacer(minLength: 0)
                if let kept = entry.snapshot?.promisesKept, !days.isEmpty {
                    Text("Dodržené sliby \(Int((kept * 100).rounded())) %")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WidgetStyle.text)
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    let day = index < days.count ? days[index] : nil
                    let isToday = day.map { Calendar.current.isDate($0.date, inSameDayAs: entry.date) } ?? false
                    VStack(spacing: 5) {
                        bar(day, isToday: isToday)
                        Text(day.map { $0.total > 0 ? "\($0.done)/\($0.total)" : "–" } ?? "–")
                            .font(.system(size: 10, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(WidgetStyle.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(Self.weekdays[index])
                            .font(.system(size: 11, weight: isToday ? .heavy : .semibold))
                            .foregroundStyle(isToday ? WidgetStyle.text : WidgetStyle.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func bar(_ day: WidgetSnapshot.Day?, isToday: Bool) -> some View {
        let value = day.map { $0.total > 0 ? Double($0.done) / Double($0.total) : 0 } ?? 0
        let isPast = day.map { $0.date < Calendar.current.startOfDay(for: entry.date) } ?? false
        let complete = day.map { $0.total > 0 && $0.done == $0.total } ?? false
        let color = complete ? WidgetStyle.green : (isPast && value < 1 && (day?.total ?? 0) > 0 ? WidgetStyle.orange : WidgetStyle.text)
        return GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 5).fill(WidgetStyle.track)
                RoundedRectangle(cornerRadius: 5)
                    .fill(color)
                    .frame(height: proxy.size.height * value)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(isToday ? WidgetStyle.text : .clear, lineWidth: 1.5))
    }
}

// MARK: Next task

/// The next task of the day with its icon and, when it allows it, a button to complete it.
struct NextTaskWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KeptNextTask", provider: TodayProvider()) { entry in
            NextTaskWidgetView(entry: entry)
                .containerBackground(WidgetStyle.background, for: .widget)
        }
        .configurationDisplayName("Kept – další úkol")
        .description("Co máš dnes na řadě. Jednoduché úkoly splníš rovnou z plochy.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

struct NextTaskWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    private var today: WidgetSnapshot? { entry.today }
    private var emptyText: String { (today?.total ?? 0) == 0 ? "Dnes nic v plánu" : "Všechno hotovo" }

    var body: some View {
        if family == .accessoryRectangular {
            VStack(alignment: .leading, spacing: 2) {
                Text("Další úkol").font(.caption2)
                Label(today?.nextTitle ?? emptyText, systemImage: today?.nextIcon ?? "checkmark")
                    .font(.headline)
                    .lineLimit(2)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    WidgetStyle.label("DALŠÍ ÚKOL")
                    Spacer(minLength: 0)
                    Text("\(today?.done ?? 0)/\(today?.total ?? 0)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(WidgetStyle.secondary)
                }
                if let title = today?.nextTitle {
                    Image(systemName: today?.nextIcon ?? "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(WidgetStyle.text)
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(WidgetStyle.text)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    if let id = today?.nextCompletableID {
                        Button(intent: CompleteTaskIntent(taskID: id)) {
                            Label("HOTOVO", systemImage: "checkmark")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(Color.black)
                                .frame(maxWidth: .infinity, minHeight: 32)
                                .background(WidgetStyle.green)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Spacer(minLength: 0)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle((today?.total ?? 0) > 0 ? WidgetStyle.green : WidgetStyle.secondary)
                    Text(emptyText)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(WidgetStyle.text)
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: Reliability

/// The reliability score as a ring, for the lock screen and a small tile.
struct ScoreWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KeptScore", provider: TodayProvider()) { entry in
            ScoreWidgetView(entry: entry)
                .containerBackground(WidgetStyle.background, for: .widget)
        }
        .configurationDisplayName("Kept – spolehlivost")
        .description("Tvoje skóre spolehlivosti jako kroužek.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryInline])
    }
}

struct ScoreWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    private var score: Int? { entry.snapshot?.score }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Spolehlivost \(score.map(String.init) ?? "–")")
        case .accessoryCircular:
            Gauge(value: Double(score ?? 0), in: 0...100) {
                Text("SP")
            } currentValueLabel: {
                Text(score.map(String.init) ?? "–")
            }
            .gaugeStyle(.accessoryCircular)
        default:
            VStack(spacing: 8) {
                WidgetStyle.label("SPOLEHLIVOST")
                ZStack {
                    Circle().stroke(WidgetStyle.track, lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: Double(score ?? 0) / 100)
                        .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(score.map(String.init) ?? "–")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(WidgetStyle.text)
                        .minimumScaleFactor(0.6)
                }
                .padding(4)
            }
        }
    }

    private var color: Color {
        guard let score else { return WidgetStyle.secondary }
        if score >= 80 { return WidgetStyle.green }
        if score >= 50 { return WidgetStyle.orange }
        return Color(red: 1, green: 0.27, blue: 0.23)
    }
}

extension Date {
    /// Monday of this date's week, the way the app counts weeks.
    var weekStartForWidget: Date {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)) ?? self
    }
}
