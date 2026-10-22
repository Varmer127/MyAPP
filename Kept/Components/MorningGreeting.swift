import SwiftUI

/// When the morning moment appears: in the morning (local time of the phone), after the app was left alone for a while,
/// and only once a day. The rule lives here so it can be read and changed in one place.
enum MorningMoment {
    /// 3:00 to 10:30.
    static let window = (3 * 60)...(10 * 60 + 30)
    /// Away for longer than this counts as a new start of the day.
    static let awayAfter: TimeInterval = 4 * 3600

    static func isDue(now: Date, lastActive: Date?, lastGreetedDay: Date?, onboardedAt: Date?) -> Bool {
        guard window.contains(now.minutesIntoDay) else { return false }
        // Never on the day the guide was finished: the user just met the app.
        guard let onboardedAt, onboardedAt.startOfDay < now.startOfDay else { return false }
        if let lastGreetedDay, lastGreetedDay.isSameDay(as: now) { return false }
        guard let lastActive else { return true }
        return now.timeIntervalSince(lastActive) > awayAfter
    }
}

/// A new week or a new month is a natural moment for a fresh start. On those mornings the greeting says so
/// instead of the usual line: a look back in one sentence and a clean page ahead.
enum FreshStart {
    case week(lastDone: Int, lastTotal: Int)
    case month

    /// The kind of morning it is today, if it is one: the first of a month wins over a Monday.
    static func today(tasks: [TaskItem], now: Date) -> FreshStart? {
        if Calendar.app.component(.day, from: now) == 1 { return .month }
        guard Calendar.app.component(.weekday, from: now) == 2 else { return nil }
        let last = tasks.filter { !$0.isRemoved && $0.countsInScores && $0.scheduledDate.weekStart == now.weekStart.addingDays(-7) }
        return .week(lastDone: last.filter(\.isDone).count, lastTotal: last.count)
    }
}

/// The first screen of the day: a greeting by name, today's promise in one glance and a single way to start.
struct MorningGreeting: View {
    let name: String
    let tasks: [TaskItem]
    let streak: Int
    let openFromBefore: Int
    var freshStart: FreshStart?
    let onStart: () -> Void
    let onAdd: () -> Void
    var onPlanWeek: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0

    private var open: [TaskItem] {
        tasks.filter { $0.status == .pending }.sorted { $0.dueDate < $1.dueDate }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 40)
                Text(Date.now.longDayText.uppercased())
                    .labelStyle()
                    .modifier(Reveal(isOn: step >= 1, reduceMotion: reduceMotion))
                Text(greeting)
                    .scaledFont(38, weight: .heavy)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                    .modifier(Reveal(isOn: step >= 1, reduceMotion: reduceMotion))
                Text(headline)
                    .scaledFont(.heading, weight: .semibold)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 10)
                    .modifier(Reveal(isOn: step >= 2, reduceMotion: reduceMotion))
                if !open.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(open.prefix(4)) { task in
                            HStack(spacing: 12) {
                                Image(systemName: task.icon)
                                    .scaledFont(.body)
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(width: 36, height: 36)
                                    .background(Theme.cardRaised)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                Text(task.title)
                                    .scaledFont(.body, weight: .semibold)
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                if let deadline = task.deadline {
                                    Text(deadline.timeText)
                                        .scaledFont(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                            .padding(10)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        if open.count > 4 {
                            Text("a další \(open.count - 4)")
                                .scaledFont(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(.top, 22)
                    .modifier(Reveal(isOn: step >= 3, reduceMotion: reduceMotion))
                } else {
                    EmptyStateArt(kind: .plan)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                        .modifier(Reveal(isOn: step >= 3, reduceMotion: reduceMotion))
                }
                if let line = streakLine {
                    Label(line.text, systemImage: "flame.fill")
                        .scaledFont(.body, weight: .semibold)
                        .foregroundStyle(line.isAlive ? Theme.orange : Theme.textSecondary)
                        .padding(.top, 18)
                        .modifier(Reveal(isOn: step >= 3, reduceMotion: reduceMotion))
                }
                Spacer()
                VStack(spacing: 10) {
                    if case .week = freshStart {
                        Button("NAPLÁNOVAT TÝDEN", action: onPlanWeek)
                            .buttonStyle(PrimaryButtonStyle())
                        Button("Teď ne", action: onStart)
                            .scaledFont(.body)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(minHeight: 44)
                    } else if open.isEmpty {
                        Button("PŘIDAT DNEŠNÍ SLIB", action: onAdd)
                            .buttonStyle(PrimaryButtonStyle())
                        Button("Teď ne", action: onStart)
                            .scaledFont(.body)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(minHeight: 44)
                    } else {
                        Button("JDU NA TO", action: onStart)
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }
                .modifier(Reveal(isOn: step >= 4, reduceMotion: reduceMotion))
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 24)
        }
        .task {
            for next in 1...4 {
                try? await Task.sleep(for: .milliseconds(next == 1 ? 150 : 280))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { step = next }
            }
        }
    }

    private var greeting: String {
        switch freshStart {
        case .week: name.isEmpty ? "Nový týden. Čistá tabule." : "Nový týden, \(name). Čistá tabule."
        case .month: name.isEmpty ? "Nový měsíc. Čistá tabule." : "Nový měsíc, \(name). Čistá tabule."
        case nil: name.isEmpty ? "Dobré ráno." : "Dobré ráno, \(name)."
        }
    }

    private var headline: String {
        if case let .week(done, total) = freshStart {
            return total > 0 ? "Minulý týden jsi dodržel \(done) z \(total) slibů. Teď to můžeš zopakovat, nebo přidat." : "Minulý týden nic nebylo. Dnes se dá začít."
        }
        if case .month = freshStart { return "Dnes začíná nový měsíc. Co sis na něj slíbil?" }
        let count = open.count
        if count == 0 {
            return openFromBefore > 0 ? "Dnes nic v plánu, ale z minula čeká \(openFromBefore) otevřených." : "Dnes máš prázdno."
        }
        let word = count == 1 ? "věc" : (2...4).contains(count) ? "věci" : "věcí"
        return "Dnes slibuješ \(count) \(word)."
    }

    private var streakLine: (text: String, isAlive: Bool)? {
        if streak > 0 { return ("Série \(streak) \(streak == 1 ? "den" : (2...4).contains(streak) ? "dny" : "dní"). Dnes ji prodloužíš.", true) }
        return ("Dnes můžeš začít novou sérii.", false)
    }
}

/// A short fade-and-rise used to bring the parts of a screen in one after another.
private struct Reveal: ViewModifier {
    let isOn: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isOn || reduceMotion ? 1 : 0)
            .offset(y: isOn || reduceMotion ? 0 : 14)
    }
}
