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
    case streak, seal, word, habit, gym, health

    var id: String { rawValue }

    var title: String {
        switch self {
        case .streak: "Série"
        case .seal: "Pečeť"
        case .word: "Slovo"
        case .habit: "Návyk"
        case .gym: "Gym"
        case .health: "Zdraví"
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
    /// A hidden badge shows as a question mark until it is earned, so it is a surprise and not a goal.
    var isSecret = false

    var shownName: String { isSecret && !isEarned ? "???" : name }
    var shownSymbol: String { isSecret && !isEarned ? "questionmark" : symbol }
    var shownHow: String { isSecret && !isEarned ? "Skrytý odznak. Prozradí se, až ho získáš." : how }

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
                         targets: (TaskCategory) -> Int, health: HealthStats = .stored, now: Date = .now) -> [Achievement] {
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
        // Days since the first completed task, to the day.
        let monthsInApp = sortedDone.first.map { max(0, Calendar.app.dateComponents([.day], from: $0, to: now.startOfDay).day ?? 0) } ?? 0
        let diaryDays = Array(Set(diary.map { $0.day.startOfDay })).sorted()
        var diaryRun = 0, diaryBest = 0
        for (index, day) in diaryDays.enumerated() {
            diaryRun = index > 0 && diaryDays[index - 1].addingDays(1) == day ? diaryRun + 1 : 1
            diaryBest = max(diaryBest, diaryRun)
        }

        // Gym
        let workouts = live.filter { $0.category == .gym && $0.isDone }.count

        func make(_ id: String, _ name: String, _ symbol: String, _ group: BadgeGroup, _ tier: BadgeTier, _ how: String,
                  earned: Bool, progress: (Int, Int)? = nil, secret: Bool = false) -> Achievement {
            Achievement(id: id, name: name, symbol: symbol, group: group, tier: tier, how: how, isEarned: earned,
                  progress: progress.map { (current: $0.0, target: $0.1) }, isSecret: secret)
        }

        // Hidden badges
        let nightOwl = doneTasks.contains { task in
            guard let at = task.completedAt else { return false }
            let hour = Calendar.app.component(.hour, from: at)
            return hour >= 23 || hour < 4
        }
        let lastMinute = doneTasks.contains { task in
            guard let at = task.completedAt, let deadline = task.deadline else { return false }
            return at <= deadline && deadline.timeIntervalSince(at) <= 5 * 60
        }
        let allRounder = Dictionary(grouping: doneTasks) { $0.completedAt?.weekStart ?? .distantPast }
            .values.contains { Set($0.map(\.category)).count >= 5 }

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
            make("month1", "První měsíc", "calendar.badge.checkmark", .habit, .common,
                 "Měsíc od prvního splněného úkolu v Kept.",
                 earned: monthsInApp >= 30, progress: (monthsInApp, 30)),
            make("diary", "Reflexe", "book.closed.fill", .habit, .rare, "Deset zápisů v deníku za sebou.",
                 earned: diaryBest >= 10, progress: (diaryBest, 10)),

            make("gym1", "První trénink", "dumbbell.fill", .gym, .common, "Splň první trénink.",
                 earned: workouts >= 1, progress: (workouts, 1)),
            make("gym25", "Pravidelný", "dumbbell.fill", .gym, .rare, "25 splněných tréninků.",
                 earned: workouts >= 25, progress: (workouts, 25)),
            make("gym100", "Sto tréninků", "dumbbell.fill", .gym, .legendary, "100 splněných tréninků.",
                 earned: workouts >= 100, progress: (workouts, 100)),
            make("night", "Noční sova", "moon.stars.fill", .habit, .rare, "Splň úkol po jedenácté večer nebo před čtvrtou ráno.",
                 earned: nightOwl, secret: true),
            make("lastminute", "Na poslední chvíli", "timer", .habit, .rare, "Splň úkol v posledních pěti minutách před deadlinem.",
                 earned: lastMinute, secret: true),
            make("allround", "Všestranný", "square.grid.3x3.fill", .habit, .rare, "Splň úkoly v pěti různých oblastech za jeden týden.",
                 earned: allRounder, secret: true),
        ] + healthBadges(health)
    }

    /// Badges earned from what Apple Health records. They stay locked until Health is connected.
    static func healthBadges(_ health: HealthStats) -> [Achievement] {
        func make(_ id: String, _ name: String, _ symbol: String, _ tier: BadgeTier, _ how: String,
                  have: Int, need: Int) -> Achievement {
            Achievement(id: id, name: name, symbol: symbol, group: .health, tier: tier, how: how,
                        isEarned: have >= need, progress: (current: have, target: need))
        }
        return [
            make("steps10k", "Desítka", "figure.walk", .common, "10 000 kroků za jeden den.",
                 have: health.maxSteps, need: 10_000),
            make("steps20k", "Dvacítka", "figure.walk.motion", .rare, "20 000 kroků za jeden den.",
                 have: health.maxSteps, need: 20_000),
            make("steps30k", "Třicítka", "figure.hiking", .legendary, "30 000 kroků za jeden den.",
                 have: health.maxSteps, need: 30_000),
            make("steps50k", "Padesátka", "figure.climbing", .legendary, "50 000 kroků za jeden den.",
                 have: health.maxSteps, need: 50_000),
            make("steps100k", "Stovka", "mountain.2.fill", .legendary, "100 000 kroků za jeden den.",
                 have: health.maxSteps, need: 100_000),
            make("run20k", "Tři dvacítky v řadě", "bolt.fill", .legendary, "Tři dny po sobě přes 20 000 kroků.",
                 have: health.run20k, need: 3),
            make("move7", "Týden v pohybu", "calendar.badge.checkmark", .rare, "Sedm dní po sobě aspoň 10 000 kroků.",
                 have: health.run10k, need: 7),
            make("move30", "Měsíc v pohybu", "calendar", .legendary, "Třicet dní po sobě aspoň 10 000 kroků.",
                 have: health.run10k, need: 30),
            make("km21", "Půlmaraton", "map.fill", .rare, "21 km chůze nebo běhu za jeden den.",
                 have: Int(health.maxKm), need: 21),
            make("km42", "Maraton", "flag.checkered", .legendary, "42 km chůze nebo běhu za jeden den.",
                 have: Int(health.maxKm), need: 42),
            make("week50", "Týden na nohou", "point.topleft.down.to.point.bottomright.curvepath.fill", .rare,
                 "50 km chůze nebo běhu za jeden týden.", have: Int(health.bestWeekKm), need: 50),
            make("kcal1000", "Tisíc kalorií", "flame.fill", .rare, "1 000 aktivních kalorií za jeden den.",
                 have: health.maxKcal, need: 1_000),
            make("train5", "Pětkrát týdně", "figure.run", .rare, "Pět dní s tréninkem za jeden týden. Počítá se Gym, Sport, tvoje aktivity označené jako trénink i tréninky ze Zdraví.",
                 have: health.bestWeekWorkouts, need: 5),
        ]
    }
}
