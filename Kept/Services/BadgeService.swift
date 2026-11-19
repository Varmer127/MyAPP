import Foundation

/// How hard a badge is to earn. Rare and legendary ones are meant to take weeks.
enum BadgeTier: Int, Comparable {
    case common, rare, legendary

    static func < (lhs: BadgeTier, rhs: BadgeTier) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .common: String(localized: "BĚŽNÝ", bundle: .kept)
        case .rare: String(localized: "VZÁCNÝ", bundle: .kept)
        case .legendary: String(localized: "LEGENDÁRNÍ", bundle: .kept)
        }
    }
}

enum BadgeGroup: String, CaseIterable, Identifiable {
    case streak, seal, word, habit, gym, health

    var id: String { rawValue }

    var title: String {
        switch self {
        case .streak: String(localized: "Série", bundle: .kept)
        case .seal: String(localized: "Pečeť", bundle: .kept)
        case .word: String(localized: "Slovo", bundle: .kept)
        case .habit: String(localized: "Návyk", bundle: .kept)
        case .gym: String(localized: "Gym", bundle: .kept)
        case .health: String(localized: "Zdraví", bundle: .kept)
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
    var shownHow: String { isSecret && !isEarned ? String(localized: "Skrytý odznak. Prozradí se, až ho získáš.", bundle: .kept) : how }

    /// "Získáno", or how far along the user is ("5 / 14") when it can be counted. Nothing for an uncounted locked badge.
    var statusText: String {
        if isEarned { return String(localized: "Získáno", bundle: .kept) }
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
            make("streak7", String(localized: "Týden v kuse", bundle: .kept), "flame.fill", .streak, .common, String(localized: "Dodrž slovo 7 dní v řadě.", bundle: .kept),
                 earned: reached[7] == true, progress: (currentStreak, 7)),
            make("streak14", String(localized: "Dva týdny", bundle: .kept), "flame.fill", .streak, .common, String(localized: "Série 14 dní. Z rozhodnutí se stává zvyk.", bundle: .kept),
                 earned: reached[14] == true, progress: (currentStreak, 14)),
            make("streak30", String(localized: "Měsíc slova", bundle: .kept), "flame.fill", .streak, .rare, String(localized: "Série 30 dní.", bundle: .kept),
                 earned: reached[30] == true, progress: (currentStreak, 30)),
            make("streak60", String(localized: "Šedesát dní", bundle: .kept), "flame.fill", .streak, .rare, String(localized: "Série 60 dní.", bundle: .kept),
                 earned: reached[60] == true, progress: (currentStreak, 60)),
            make("streak100", String(localized: "Sto dní", bundle: .kept), "flame.fill", .streak, .legendary, String(localized: "Série 100 dní.", bundle: .kept),
                 earned: reached[100] == true, progress: (currentStreak, 100)),

            make("seal1", String(localized: "První pečeť", bundle: .kept), "checkmark.seal.fill", .seal, .common, String(localized: "Zapeceť svůj první týden.", bundle: .kept),
                 earned: !committed.isEmpty, progress: (committed.count, 1)),
            make("seal4", String(localized: "Čtyři pečeti", bundle: .kept), "checkmark.seal.fill", .seal, .rare, String(localized: "Čtyři zapečetěné týdny v řadě.", bundle: .kept),
                 earned: longestRun >= 4, progress: (longestRun, 4)),
            make("untouched", String(localized: "Bez couvnutí", bundle: .kept), "shield.fill", .seal, .rare,
                 String(localized: "Týden zapečetěný bez jediné změny po pečeti, s aspoň pěti slibů.", bundle: .kept), earned: untouched),
            make("seal12", String(localized: "Dvanáct pečetí", bundle: .kept), "checkmark.seal.fill", .seal, .legendary, String(localized: "Dvanáct zapečetěných týdnů celkem.", bundle: .kept),
                 earned: committed.count >= 12, progress: (committed.count, 12)),

            make("clean", String(localized: "Čistý týden", bundle: .kept), "checkmark.circle.fill", .word, .rare, String(localized: "Týden se sedmi a více sliby, všechny dodržené.", bundle: .kept),
                 earned: cleanWeek),
            make("critical", String(localized: "Kritická práce", bundle: .kept), "scope", .word, .rare, String(localized: "Týden, ve kterém splníš všechny aspoň tři kritické úkoly.", bundle: .kept),
                 earned: criticalWeek),
            make("honest", String(localized: "Upřímný", bundle: .kept), "pencil.and.list.clipboard", .word, .common, String(localized: "Deset nesplněných slibů poctivě vysvětlených.", bundle: .kept),
                 earned: honest >= 10, progress: (honest, 10)),
            make("goals", String(localized: "Cíle týdne", bundle: .kept), "target", .word, .rare, String(localized: "Týden, ve kterém splníš všechny týdenní cíle.", bundle: .kept), earned: goalsWeek),

            make("early", String(localized: "Ranní ptáče", bundle: .kept), "sunrise.fill", .habit, .rare, String(localized: "Splň osm úkolů před 9:00 během jednoho týdne.", bundle: .kept),
                 earned: early >= 8, progress: (early, 8)),
            make("comeback", String(localized: "Comeback", bundle: .kept), "arrow.uturn.up", .habit, .rare, String(localized: "Třikrát po dni pod 60 % hned druhý den na 80 % a víc.", bundle: .kept),
                 earned: comebacks >= 3, progress: (comebacks, 3)),
            make("back", String(localized: "Zpátky v sedle", bundle: .kept), "figure.walk", .habit, .common, String(localized: "Vrať se po pauze delší než pět dní a splň úkol.", bundle: .kept), earned: returned),
            make("month1", String(localized: "První měsíc", bundle: .kept), "calendar.badge.checkmark", .habit, .common,
                 String(localized: "Měsíc od prvního splněného úkolu v Kept.", bundle: .kept),
                 earned: monthsInApp >= 30, progress: (monthsInApp, 30)),
            make("diary", String(localized: "Reflexe", bundle: .kept), "book.closed.fill", .habit, .rare, String(localized: "Deset zápisů v deníku za sebou.", bundle: .kept),
                 earned: diaryBest >= 10, progress: (diaryBest, 10)),

            make("gym1", String(localized: "První trénink", bundle: .kept), "dumbbell.fill", .gym, .common, String(localized: "Splň první trénink.", bundle: .kept),
                 earned: workouts >= 1, progress: (workouts, 1)),
            make("gym25", String(localized: "Pravidelný", bundle: .kept), "dumbbell.fill", .gym, .rare, String(localized: "25 splněných tréninků.", bundle: .kept),
                 earned: workouts >= 25, progress: (workouts, 25)),
            make("gym100", String(localized: "Sto tréninků", bundle: .kept), "dumbbell.fill", .gym, .legendary, String(localized: "100 splněných tréninků.", bundle: .kept),
                 earned: workouts >= 100, progress: (workouts, 100)),
            make("night", String(localized: "Noční sova", bundle: .kept), "moon.stars.fill", .habit, .rare, String(localized: "Splň úkol po jedenácté večer nebo před čtvrtou ráno.", bundle: .kept),
                 earned: nightOwl, secret: true),
            make("lastminute", String(localized: "Na poslední chvíli", bundle: .kept), "timer", .habit, .rare, String(localized: "Splň úkol v posledních pěti minutách před deadlinem.", bundle: .kept),
                 earned: lastMinute, secret: true),
            make("allround", String(localized: "Všestranný", bundle: .kept), "square.grid.3x3.fill", .habit, .rare, String(localized: "Splň úkoly v pěti různých oblastech za jeden týden.", bundle: .kept),
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
            make("steps10k", String(localized: "Desítka", bundle: .kept), "figure.walk", .common, String(localized: "10 000 kroků za jeden den.", bundle: .kept),
                 have: health.maxSteps, need: 10_000),
            make("steps20k", String(localized: "Dvacítka", bundle: .kept), "figure.walk.motion", .rare, String(localized: "20 000 kroků za jeden den.", bundle: .kept),
                 have: health.maxSteps, need: 20_000),
            make("steps30k", String(localized: "Třicítka", bundle: .kept), "figure.hiking", .legendary, String(localized: "30 000 kroků za jeden den.", bundle: .kept),
                 have: health.maxSteps, need: 30_000),
            make("steps50k", String(localized: "Padesátka", bundle: .kept), "figure.climbing", .legendary, String(localized: "50 000 kroků za jeden den.", bundle: .kept),
                 have: health.maxSteps, need: 50_000),
            make("steps100k", String(localized: "Stovka", bundle: .kept), "mountain.2.fill", .legendary, String(localized: "100 000 kroků za jeden den.", bundle: .kept),
                 have: health.maxSteps, need: 100_000),
            make("run20k", String(localized: "Tři dvacítky v řadě", bundle: .kept), "bolt.fill", .legendary, String(localized: "Tři dny po sobě přes 20 000 kroků.", bundle: .kept),
                 have: health.run20k, need: 3),
            make("move7", String(localized: "Týden v pohybu", bundle: .kept), "calendar.badge.checkmark", .rare, String(localized: "Sedm dní po sobě aspoň 10 000 kroků.", bundle: .kept),
                 have: health.run10k, need: 7),
            make("move30", String(localized: "Měsíc v pohybu", bundle: .kept), "calendar", .legendary, String(localized: "Třicet dní po sobě aspoň 10 000 kroků.", bundle: .kept),
                 have: health.run10k, need: 30),
            make("km21", String(localized: "Půlmaraton", bundle: .kept), "map.fill", .rare, String(localized: "21 km chůze nebo běhu za jeden den.", bundle: .kept),
                 have: Int(health.maxKm), need: 21),
            make("km42", String(localized: "Maraton", bundle: .kept), "flag.checkered", .legendary, String(localized: "42 km chůze nebo běhu za jeden den.", bundle: .kept),
                 have: Int(health.maxKm), need: 42),
            make("week50", String(localized: "Týden na nohou", bundle: .kept), "point.topleft.down.to.point.bottomright.curvepath.fill", .rare,
                 String(localized: "50 km chůze nebo běhu za jeden týden.", bundle: .kept), have: Int(health.bestWeekKm), need: 50),
            make("kcal1000", String(localized: "Tisíc kalorií", bundle: .kept), "flame.fill", .rare, String(localized: "1 000 aktivních kalorií za jeden den.", bundle: .kept),
                 have: health.maxKcal, need: 1_000),
            make("train5", String(localized: "Pětkrát týdně", bundle: .kept), "figure.run", .rare, String(localized: "Pět dní s tréninkem za jeden týden. Počítá se Gym, Sport, tvoje aktivity označené jako trénink i tréninky ze Zdraví.", bundle: .kept),
                 have: health.bestWeekWorkouts, need: 5),
        ]
    }
}
