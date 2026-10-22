import Foundation

/// How hard a badge is to earn. Rare and legendary ones are meant to take weeks.
enum BadgeTier: Int, Comparable {
    case common, rare, legendary

    static func < (lhs: BadgeTier, rhs: BadgeTier) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .common: "BĚŽNÝ"
        case .rare: "VZÁCNÝ"
        case .legendary: "LEGENDÁRNÍ"
        }
    }
}

enum BadgeGroup: String, CaseIterable, Identifiable {
    case streak, seal, word, habit, gym

    var id: String { rawValue }

    var title: String {
        switch self {
        case .streak: "Série"
        case .seal: "Pečeť"
        case .word: "Slovo"
        case .habit: "Návyk"
        case .gym: "Gym"
        }
    }
}

struct Achievement: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let group: BadgeGroup
    let tier: BadgeTier
    /// What it takes, in one sentence.
    let how: String
    let isEarned: Bool
    /// How far along the user is, for badges that can be counted.
    let progress: (current: Int, target: Int)?

    /// "Získáno", or how far along the user is ("5 / 14") when it can be counted. Nothing for an uncounted locked badge.
    var statusText: String {
        if isEarned { return "Získáno" }
        guard let progress else { return "" }
        return "\(min(progress.current, progress.target)) / \(progress.target)"
    }
}

/// Which badges the user has earned, worked out from the history every time. Nothing is stored,
/// so a badge can never be out of step with what really happened.
enum BadgeService {
    static func evaluate(tasks: [TaskItem], plans: [WeeklyPlan], failures: [FailureRecord], diary: [DiaryEntry],
                         targets: (TaskCategory) -> Int, now: Date = .now) -> [Achievement] {
        let live = tasks.filter { !$0.isRemoved }
        let byDay = Dictionary(grouping: live) { $0.scheduledDate.startOfDay }
        let committed = plans.filter(\.isCommitted).sorted { $0.weekStart < $1.weekStart }
        let finished = committed.filter { $0.weekEnd <= now }

        // Streak
        let reached = Dictionary(uniqueKeysWithValues: StreakService.milestones(tasks, now: now).map { ($0.days, $0.reachedOn != nil) })
        let currentStreak = ScoreEngine.dayStreak(tasks, now: now)

        // Seals
        var longestRun = 0, run = 0
        var previous: Date?
        for plan in committed {
            run = previous.map { $0.addingDays(7) == plan.weekStart } == true ? run + 1 : 1
            longestRun = max(longestRun, run)
            previous = plan.weekStart
        }
        let untouched = finished.contains { $0.edits.isEmpty && $0.committableTasks.count >= 5 }

        // Word
        let cleanWeek = finished.contains { plan in
            let week = plan.committableTasks
            return week.count >= 7 && ScoreEngine.promisesKept(week, now: now) == 1
        }
        let criticalWeek = finished.contains { plan in
            let critical = plan.committableTasks.filter { $0.priority == .critical }
            return critical.count >= 3 && critical.allSatisfy(\.isDone)
        }
        let honest = failures.filter { !$0.critique.trimmingCharacters(in: .whitespaces).isEmpty }.count
        let weekStarts = Set(live.map { $0.scheduledDate.weekStart }).filter { $0.addingDays(7) <= now }
        let goalsWeek = weekStarts.contains { start in
            let goals = SuggestionService.goals(tasks: tasks, weekStart: start, now: now.addingDays(14), target: targets)
            return !goals.isEmpty && goals.allSatisfy(\.isMet)
        }

        // Habit
        let doneTasks = live.filter { $0.isDone && $0.completedAt != nil }
        let earlyByWeek = Dictionary(grouping: doneTasks.filter { Calendar.app.component(.hour, from: $0.completedAt ?? .now) < 9 }) {
            ($0.completedAt ?? .now).weekStart
        }
        let early = earlyByWeek.values.map(\.count).max() ?? 0

        let scores: [(day: Date, value: Double)] = byDay.keys.sorted().compactMap { day in
            ScoreEngine.productivity(byDay[day] ?? [], now: now).map { (day, $0) }
        }
        var comebacks = 0
        for (index, entry) in scores.enumerated() where index + 1 < scores.count {
            if entry.value < 0.6, scores[index + 1].value >= 0.8, scores[index + 1].day == entry.day.addingDays(1) { comebacks += 1 }
        }
        let backDays = doneTasks.compactMap { $0.completedAt?.startOfDay }
        let sortedDone = Array(Set(backDays)).sorted()
        var returned = false
        for (index, day) in sortedDone.enumerated() where index > 0 {
            if Calendar.app.dateComponents([.day], from: sortedDone[index - 1], to: day).day ?? 0 >= 5 { returned = true }
        }
        let diaryDays = Array(Set(diary.map { $0.day.startOfDay })).sorted()
        var diaryRun = 0, diaryBest = 0
        for (index, day) in diaryDays.enumerated() {
            diaryRun = index > 0 && diaryDays[index - 1].addingDays(1) == day ? diaryRun + 1 : 1
            diaryBest = max(diaryBest, diaryRun)
        }

        // Gym
        let workouts = live.filter { $0.category == .gym && $0.isDone }.count

        func make(_ id: String, _ name: String, _ symbol: String, _ group: BadgeGroup, _ tier: BadgeTier, _ how: String,
                  earned: Bool, progress: (Int, Int)? = nil) -> Achievement {
            Achievement(id: id, name: name, symbol: symbol, group: group, tier: tier, how: how, isEarned: earned,
                  progress: progress.map { (current: $0.0, target: $0.1) })
        }

        return [
            make("streak7", "Týden v kuse", "flame.fill", .streak, .common, "Dodrž slovo 7 dní v řadě.",
                 earned: reached[7] == true, progress: (currentStreak, 7)),
            make("streak14", "Dva týdny", "flame.fill", .streak, .common, "Série 14 dní. Z rozhodnutí se stává zvyk.",
                 earned: reached[14] == true, progress: (currentStreak, 14)),
            make("streak30", "Měsíc slova", "flame.fill", .streak, .rare, "Série 30 dní.",
                 earned: reached[30] == true, progress: (currentStreak, 30)),
            make("streak60", "Šedesát dní", "flame.fill", .streak, .rare, "Série 60 dní.",
                 earned: reached[60] == true, progress: (currentStreak, 60)),
            make("streak100", "Sto dní", "flame.fill", .streak, .legendary, "Série 100 dní.",
                 earned: reached[100] == true, progress: (currentStreak, 100)),

            make("seal1", "První pečeť", "checkmark.seal.fill", .seal, .common, "Zapeceť svůj první týden.",
                 earned: !committed.isEmpty, progress: (committed.count, 1)),
            make("seal4", "Čtyři pečeti", "checkmark.seal.fill", .seal, .rare, "Čtyři zapečetěné týdny v řadě.",
                 earned: longestRun >= 4, progress: (longestRun, 4)),
            make("untouched", "Bez couvnutí", "shield.fill", .seal, .rare,
                 "Týden zapečetěný bez jediné změny po pečeti, s aspoň pěti slibů.", earned: untouched),
            make("seal12", "Dvanáct pečetí", "checkmark.seal.fill", .seal, .legendary, "Dvanáct zapečetěných týdnů celkem.",
                 earned: committed.count >= 12, progress: (committed.count, 12)),

            make("clean", "Čistý týden", "checkmark.circle.fill", .word, .rare, "Týden se sedmi a více sliby, všechny dodržené.",
                 earned: cleanWeek),
            make("critical", "Kritická práce", "scope", .word, .rare, "Týden, ve kterém splníš všechny aspoň tři kritické úkoly.",
                 earned: criticalWeek),
            make("honest", "Upřímný", "pencil.and.list.clipboard", .word, .common, "Deset nesplněných slibů poctivě vysvětlených.",
                 earned: honest >= 10, progress: (honest, 10)),
            make("goals", "Cíle týdne", "target", .word, .rare, "Týden, ve kterém splníš všechny týdenní cíle.", earned: goalsWeek),

            make("early", "Ranní ptáče", "sunrise.fill", .habit, .rare, "Splň osm úkolů před 9:00 během jednoho týdne.",
                 earned: early >= 8, progress: (early, 8)),
            make("comeback", "Comeback", "arrow.uturn.up", .habit, .rare, "Třikrát po dni pod 60 % hned druhý den na 80 % a víc.",
                 earned: comebacks >= 3, progress: (comebacks, 3)),
            make("back", "Zpátky v sedle", "figure.walk", .habit, .common, "Vrať se po pauze delší než pět dní a splň úkol.", earned: returned),
            make("diary", "Reflexe", "book.closed.fill", .habit, .rare, "Deset zápisů v deníku za sebou.",
                 earned: diaryBest >= 10, progress: (diaryBest, 10)),

            make("gym1", "První trénink", "dumbbell.fill", .gym, .common, "Splň první trénink.",
                 earned: workouts >= 1, progress: (workouts, 1)),
            make("gym25", "Pravidelný", "dumbbell.fill", .gym, .rare, "25 splněných tréninků.",
                 earned: workouts >= 25, progress: (workouts, 25)),
            make("gym100", "Stovka", "dumbbell.fill", .gym, .legendary, "100 splněných tréninků.",
                 earned: workouts >= 100, progress: (workouts, 100)),
        ]
    }
}
