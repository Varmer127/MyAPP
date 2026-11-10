import Foundation

enum NotificationTone: String, CaseIterable, Identifiable {
    case normal, strict, savage

    var id: String { rawValue }
    var title: String {
        switch self {
        case .normal: "Normální"
        case .strict: "Přísný"
        case .savage: "Drsný"
        }
    }

    /// Highest escalation level this tone is allowed to reach.
    var maxLevel: Int {
        switch self {
        case .normal: 2
        case .strict: 3
        case .savage: 4
        }
    }

    var summary: String {
        switch self {
        case .normal: "Věcný a neutrální."
        case .strict: "Přímý a konfrontační."
        case .savage: "Tvrdý. Míří na tvoje chování, nikdy na tebe jako člověka."
        }
    }
}

/// All notification copy. Placeholders: {task}, {time}, {why}, {n}, {days}.
///
/// How it is written (the reasoning is in docs/NOTIFICATIONS.md):
/// - The title carries the news, usually the task's name, so the body never has to bend that name into a Czech case
///   or agree with its gender. Sentence case, no shouting.
/// - One concrete next step per message, short enough for the two lines of a banner (80 characters).
/// - Gender-neutral Czech: no past-tense "-l/-la" forms or adjectives about the user.
/// - Normal and Strict talk about the behaviour and the next step, never shame: kindness after a slip
///   brings people back more reliably than self-criticism.
/// - Task reminders can arrive before or after the deadline, so they never claim which side of it they are on.
/// Savage copy attacks laziness, procrastination and broken promises — never appearance, health or self-worth.
enum NotificationTemplates {
    // MARK: Task escalation, by level. The task's name is the title.

    /// Level 0 — preparation, 30 minutes before the task should start.
    static let prep = [
        "Za 30 minut začínáš. Dodělej, co máš rozdělané.",
        "Start za půl hodiny. Připrav si všechno, ať pak jen začneš.",
        "Za 30 minut je to na řadě. Tvůj plán, tvoje slovo.",
        "Půl hodiny do startu. Zavři, co by tě rozptylovalo.",
        "Za 30 minut to začíná. Nachystej se, ať se pak dobře rozjíždí.",
        "Start za půl hodiny. Žádné překvapení, máš to v plánu.",
    ]

    /// Level 1 — the task should be starting now.
    static let start = [
        "Teď je ta chvíle. Stačí začít, zbytek se rozjede.",
        "Je {time}, čas začít. Prvních pět minut je nejtěžších.",
        "Naplánováno na teď. Pusť se do toho.",
        "Start. Udělej první malý krok, třeba jen otevři, co potřebuješ.",
        "Tenhle čas je vyhrazený právě na tohle. Jdeš na to?",
        "Je to na řadě. Na všechno ostatní teď klidně zapomeň.",
    ]

    /// Level 2 — direct. May arrive before or after the deadline.
    static let direct = [
        "Je {time} a pořád to čeká. Začni aspoň na pět minut.",
        "Ještě to není hotové. Jaký je první krok? Udělej jen ten.",
        "Je {time}. Pořád otevřené, pořád to jde dotáhnout.",
        "Slovo pořád platí. Pusť se do toho teď.",
        "Pořád čeká. Začni malým kouskem, rozjede se to.",
        "Je {time}. Odlož telefon a jdi na to.",
    ]

    /// Level 3 — strict. About the behaviour, not the person. May arrive before or after the deadline.
    static let strict = [
        "Je {time} a hotovo není. Přestaň vyjednávat a začni.",
        "Odkládání není plán. Začni teď, i bez nálady.",
        "Tohle je tvůj slib. Drž ho, i když se nechce.",
        "Každá minuta odkladu je rozhodnutí. Rozhodni se jinak.",
        "Nečekej na motivaci. Ta přijde, až začneš.",
        "Výmluvu můžeš sepsat potom. Teď to udělej.",
        "Je {time}. Cokoli teď děláš, počká. Tohle ne.",
        "Skóre i série čekají právě na tohle. Dotáhni to.",
        "Nesplněno už {n}× za poslední dobu. Dnes to zlom.",
        "Disciplína je udělat to, i když se nechce. Teď.",
        "Za hodinu ti bude líp, když začneš teď.",
        "Přestaň to odsouvat. Pět minut a jedeš.",
    ]

    /// Level 4 — savage.
    static let savage = [
        "Zase se chováš jako líný hovado. Otevři {task} a začni.",
        "Furt meleš o tom, čeho chceš dosáhnout. Tak kde je ta práce? {task}.",
        "Zamysli se nad svým životem. Tohle je přesně to chování, které tě drží na místě. {task}.",
        "Dal sis závazek a zase před ním utíkáš. {task}.",
        "Chceš výsledky lidí, kteří makají, ale dnes se tak nechováš. {task}.",
        "Kolikrát ještě budeš říkat, že začneš později? {task}.",
        "Další výmluva ti žádný výsledek nevytvoří. {task}.",
        "Nikdo tě nepřijde zachránit. Udělej tu práci. {task}.",
        "Včera sis slíbil, že se to nebude opakovat. A co děláš dnes? {task}.",
        "Je {time}. {task} pořád nic. Tohle je flákání, ne odpočinek.",
        "Tvoje plány jsou velké. Tvoje dnešní chování je ubohé. {task}.",
        "Přesně takhle vypadá den, který tě nikam neposune. {task} leží ladem.",
        "Mluvit umíš. Makat dnes očividně ne. {task}.",
        "{task} jsi nesplnil už {n}×. To není smůla, to je vzorec.",
        "Scrolluješ, nebo pracuješ? Odpověď znáš. {task}.",
        "Lenost tě stojí víc, než si přiznáváš. {task}. Hned.",
        "Tohle není únava. Tohle je vyhýbání se práci. {task}.",
        "Sliby sám sobě lámeš nejsnáz. Dokaž opak. {task}.",
        "Za rok budeš přesně tam, kde jsi teď, jestli budeš dál vynechávat {task}.",
        "Deadline je pryč a ty pořád nic. Zvedni se a udělej {task}.",
        "Nejsi zaneprázdněný. Jen prokrastinuješ. {task}.",
        "Tvoje slovo dnes nemá žádnou hodnotu. Změň to. {task}.",
        "Přestaň si lhát, že to uděláš potom. Potom neexistuje. {task}.",
        "Takhle se disciplinovaný člověk nechová. {task} čeká.",
        "Zatímco ty hledáš motivaci, někdo jiný už maká. {task}.",
        "Zvedni tu prdel. Nikdo za tebe ten život neodmaká. {task}.",
        "Chceš lepší život, ale nejsi ochotný obětovat ani hodinu? Prober se. {task}.",
        "Pohodlí tě nikam nedostane. {task}. Teď.",
        "Výmluvy nikoho nezajímají. {task}.",
    ]

    /// Short, loud headlines used as the notification title in the savage tone.
    /// The task-specific sentence follows in the body.
    static let punchlines = [
        "GET THE FUCK UP.",
        "DO THE FUCKING WORK.",
        "STAY HARD.",
        "NO ONE IS COMING.",
        "EARN YOUR COMFORT.",
        "STOP BEING SOFT.",
        "DISCIPLINE OVER FEELINGS.",
        "PROVE IT. RIGHT NOW.",
        "HUNT OR BE HUNTED.",
        "NO EXCUSES.",
        "YOU SAID YOU WOULD.",
        "KEEP YOUR WORD.",
        "DO IT TIRED.",
        "COMFORT IS A TRAP.",
        "NOBODY CARES. WORK HARDER.",
        "ZVEDNI SE.",
        "MAKEJ.",
        "SLÍBIL JSI TO.",
    ]

    /// Strict copy that quotes the user's own "Why does this matter?".
    static let whyStrict = [
        "Tvoje slova: „{why}“ Tohle k tomu vede.",
        "„{why}“ To je tvůj důvod. Dokaž si ho.",
        "Na tomhle ti záleží: „{why}“ Tak do toho.",
        "Proč to děláš? „{why}“ Pamatuj na to a začni.",
    ]

    /// Savage copy that quotes the user's own "Why does this matter?".
    static let whySavage = [
        "Říkal jsi: „{why}“ Dnes jsi pro to zase neudělal nic. {task}.",
        "„{why}“ — hezká slova. Kde je práce? {task}.",
        "Tvrdil jsi: „{why}“ Tvoje chování říká opak. {task}.",
        "„{why}“ Tohle si chceš dál jen říkat, nebo to i udělat? {task}.",
        "Kdyby ti na „{why}“ opravdu záleželo, {task} by byl hotový.",
    ]

    // MARK: Sunday planning

    /// First reminders are the same for every tone; later ones sharpen.
    /// None of them counts hours: the first one can come at whatever hour the user chose.
    private static let sundayOpening = [
        "Neděle je ideální chvíle na plán. Deset minut a týden máš srovnaný.",
        "Příští týden zatím nemá plán. Pojď ho poskládat.",
        "Co chceš příští týden opravdu dotáhnout? Napiš si to.",
        "Týden s plánem se drží líp. Stačí pár úkolů.",
    ]

    private static let sundayLater: [NotificationTone: [String]] = [
        .normal: [
            "Plán na příští týden pořád chybí. Zabere to deset minut.",
            "Stačí tři úkoly a týden má směr.",
            "Ještě je neděle. Naplánuj si týden, ať zítra víš, kam jdeš.",
            "Plán čeká. Klidně začni jedním úkolem.",
            "Týden bez plánu se těžko drží. Pojď ho udělat.",
            "Večer se blíží a plán týdne pořád není.",
            "Neděle končí. Poslední chvíle naplánovat týden v klidu.",
            "Poslední dnešní připomínka: naplánuj si týden.",
        ],
        .strict: [
            "Bez plánu nemáš co dodržet. Otevři Týden.",
            "Odkládáš i plánování. Deset minut, teď.",
            "Zítra začíná týden a nevíš, co v něm uděláš.",
            "Plán je první slib týdne. Dej ho.",
            "Pořád nic. Naplánuj si týden, dokud je čas.",
            "Zítra ráno už nebude klid na plánování. Teď.",
            "Neděle končí a příští týden je prázdný.",
            "Poslední výzva. Bez plánu jdeš do týdne naslepo.",
        ],
        .savage: [
            "Ani naplánovat týden se ti nechce? Deset minut. Hned.",
            "Celý den víš, že to máš udělat. A furt nic. Naplánuj si týden.",
            "Chceš výsledky a nezvládneš ani plán? Otevři Týden.",
            "Takhle začíná každý promarněný týden. Naplánuj ho.",
            "Flákáš i plánování. Co teprve práci? Začni.",
            "Zítra se probudíš bez plánu a budeš se divit, že nic nestíháš.",
            "Neděle je skoro pryč. Tvůj týden je prázdný papír. Tvoje volba.",
            "Poslední připomínka. Jestli to neuděláš, příští týden si prohrál předem.",
        ],
    ]

    static func sunday(tone: NotificationTone, index: Int) -> String {
        if index < sundayOpening.count { return sundayOpening[index] }
        let later = sundayLater[tone] ?? []
        guard !later.isEmpty else { return sundayOpening[0] }
        return later[min(index - sundayOpening.count, later.count - 1)]
    }

    // MARK: Day nudges, morning brief, reality check

    /// Aggregated reminders during the day, sharpening from first to last.
    static let dayNudge: [NotificationTone: [String]] = [
        .normal: [
            "Na dnes zbývá: {n}. Vyber jeden a pusť se do něj.",
            "Půlka dne za tebou. Zbývá: {n}. Který dáš teď?",
            "Večer se blíží. Zbývá: {n}. Pořád je čas to dotáhnout.",
        ],
        .strict: [
            "Na dnes zbývá: {n}. Začni tím nejtěžším.",
            "Pořád čeká: {n}. Co z toho uděláš během hodiny?",
            "Den končí. Nesplněné sliby: {n}. Dotáhni aspoň jeden.",
        ],
        .savage: [
            "Poledne. Otevřené závazky: {n}. A ty ses ještě pořádně nerozjel.",
            "Slíbil sis to a pořád to leží. Otevřeno: {n}. Přestaň se flákat.",
            "Den je skoro pryč. Nesplněné sliby: {n}. Tohle chceš večer vidět?",
        ],
    ]

    static let morningGood = [
        "Dnes to zopakuj.",
        "Tak vypadá dodržené slovo. Znovu.",
        "Nenech to být výjimkou.",
    ]

    static let morningAverage = [
        "Chybělo málo, dnes to dotáhni.",
        "Dnes o jeden úkol víc.",
        "Dobrý základ, dnes přidej.",
    ]

    /// After a bad day the morning offers a fresh start, not a reproach.
    static let morningBad = [
        "Nový den, čistý start.",
        "Včerejšek nezměníš, dnešek ano.",
        "Začni tím nejmenším a rozjeď se.",
    ]

    static let morningNeutral = [
        "Začni tím nejdůležitějším.",
        "Jeden úkol po druhém. Hezký den.",
        "Dnešní plán je tvůj. Jdeš na to.",
    ]

    static let realityCheck: [NotificationTone: [String]] = [
        .normal: [
            "Jak dnešek dopadl? Zabere to minutu.",
            "Čas na večerní bilanci. Co dnes vyšlo?",
            "Uzavři den, dokud se dá ještě něco dotáhnout.",
        ],
        .strict: [
            "Den končí. Dodrženo, nebo ne? Otevři bilanci.",
            "Čas pravdy. Podívej se na dnešek bez výmluv.",
            "Večerní bilance čeká. Kolik slibů dnes platí?",
        ],
        .savage: [
            "Večerní bilance. Dnešní sliby: {n}. Podívej se, kolik jsi jich zase nedodržel.",
            "Čas pravdy. Dnes ses flákal, nebo makal? Otevři to.",
            "Den je pryč. Čísla nelžou. Otevři večerní bilanci.",
        ],
    ]

    // MARK: Day streak

    /// The evening of a day that is about to break the streak. {days} = its length, e.g. "5 dní".
    static let streakAtRisk: [NotificationTone: [String]] = [
        .normal: [
            "Série {days} skončí o půlnoci. Stačí dodělat dnešek.",
            "Ještě pár hodin a série {days} jede dál. Dotáhni dnešek.",
        ],
        .strict: [
            "Série {days} je v ohrožení. O půlnoci padne.",
            "{days} v řadě. Dnes to nezahazuj, dotáhni to.",
        ],
        .savage: [
            "Série {days} dnes umře na tvoji lenost. Zvedni se a dodělej to.",
            "{days} práce a dnes to zahodíš kvůli pohodlí? Dodělej dnešek.",
        ],
    ]

    /// The morning after the streak broke.
    static let streakLost: [NotificationTone: [String]] = [
        .normal: [
            "Série {days} skončila. Nevadí, dnes začíná nová.",
            "Série {days} se přerušila. Jeden den nic nemaže, vrať se dnes.",
        ],
        .strict: [
            "Série {days} skončila. Dnes začni znovu, hned ráno.",
            "{days} v řadě a včera pauza. Nenech z toho vzniknout zvyk.",
        ],
        .savage: [
            "Série {days} je v háji. Včera ses na to vykašlal. Dnes to koukej napravit.",
            "{days} v řadě jsi zahodil za jediný den. Dnes ukaž, že to byla výjimka.",
        ],
    ]

    /// Later reminders while the streak stays at zero, in order. {n} = days without a streak.
    static let streakFollowUp: [NotificationTone: [String]] = [
        .normal: [
            "Dní bez série: {n}. Stačí jeden splněný den a plamínek zase hoří.",
            "Dní bez série: {n}. Začni jedním malým úkolem na dnes.",
            "Dní bez série: {n}. Kdykoli se vrátíš, Kept tu je.",
        ],
        .strict: [
            "Dní bez série: {n}. Jeden výpadek je chyba, dva začátek zvyku.",
            "Dní bez série: {n}. Přestaň to odkládat a naplánuj si dnešek.",
            "Dní bez série: {n}. Takhle se to vzdává potichu. Vrať se.",
        ],
        .savage: [
            "Dní bez série: {n}. Plamínek nehoří a ty děláš, že to nevidíš.",
            "Dní bez série: {n}. Schováváš se před vlastními sliby. Otevři to.",
            "Dní bez série: {n}. Přesně takhle vypadá, když to člověk vzdá. Dokaž opak.",
        ],
    ]

    /// The last one, a week after the break. After it the app stays quiet about the streak.
    static let streakFinal: [NotificationTone: String] = [
        .normal: "Týden bez série. Víc už psát nebudu. Až budeš chtít začít znovu, Kept tu je.",
        .strict: "Týden bez série. Dál už to připomínat nebudu. Rozhodnutí je na tobě.",
        .savage: "Týden bez série. Připomínky zjevně nefungují, tak končím. Vrať se, až to budeš myslet vážně.",
    ]

    static let streakRepairHint = "Starou sérii můžeš ještě vykoupit za body."
    static let streakRepairLastDay = "Dnes naposledy můžeš starou sérii vykoupit za body."

    /// Yesterday's result for the title ("včera 67 %") and a short sentence for the end of the body.
    static func morning(yesterday: Double?, seed: Int) -> (percent: Int?, sentence: String) {
        guard let yesterday else { return (nil, pick(morningNeutral, seed: seed)) }
        let pool: [String]
        if yesterday >= 0.8 {
            pool = morningGood
        } else if yesterday >= 0.6 {
            pool = morningAverage
        } else {
            pool = morningBad
        }
        return (Int((yesterday * 100).rounded()), pick(pool, seed: seed))
    }

    // MARK: Assembly

    /// `namesTask`: the title is not the task's name (the savage headline), so the body has to say which task it is.
    static func taskMessage(level: Int, title: String, time: String, why: String, failures: Int, seed: Int,
                            namesTask: Bool = false) -> String {
        var pool: [String]
        switch level {
        case ...0: pool = prep
        case 1: pool = start
        case 2: pool = direct
        case 3: pool = strict
        default: pool = savage
        }
        // The failure-count lines only make sense with a real history.
        if failures < 2 {
            pool = pool.filter { !$0.contains("{n}") }
        }
        // Every third high-level reminder throws the user's own motivation back at them.
        if level >= 3, !why.isEmpty, seed % 3 == 0 {
            pool = level == 3 ? whyStrict : whySavage
        }
        var template = pick(pool, seed: seed)
        if namesTask, !template.contains("{task}") {
            template = "{task}: " + template
        }
        return template
            .replacingOccurrences(of: "{task}", with: title)
            .replacingOccurrences(of: "{time}", with: time)
            .replacingOccurrences(of: "{why}", with: why)
            .replacingOccurrences(of: "{n}", with: "\(failures)")
    }

    /// Preparation and start with the user's own "when, then" plan, which says more than a clock time does.
    /// The task's name is the title, so the body is only the plan.
    static func cueMessage(level: Int, cue: String) -> String {
        level <= 0 ? "Za chvíli to začíná. Tvůj plán: \(cue)" : "Je čas. Tvůj plán: \(cue)"
    }

    static func pick(_ pool: [String], seed: Int) -> String {
        guard !pool.isEmpty else { return "" }
        return pool[abs(seed) % pool.count]
    }

    /// Every message of the Normal and Strict tones, for checking length and placeholders.
    static var gentleAndStrict: [String] {
        let tones: [NotificationTone] = [.normal, .strict]
        let shared = prep + start + direct + strict + whyStrict + sundayOpening
            + morningGood + morningAverage + morningBad + morningNeutral
        let dictionaries = [sundayLater, dayNudge, realityCheck, streakAtRisk, streakLost, streakFollowUp]
        return shared + dictionaries.flatMap { dictionary in tones.flatMap { dictionary[$0] ?? [] } }
            + tones.compactMap { streakFinal[$0] } + [streakRepairHint, streakRepairLastDay]
    }

    static var totalCount: Int {
        [prep, start, direct, strict, savage, punchlines, whyStrict, whySavage, sundayOpening,
         morningGood, morningAverage, morningBad, morningNeutral].reduce(0) { $0 + $1.count }
            + [sundayLater, dayNudge, realityCheck, streakAtRisk, streakLost, streakFollowUp]
                .reduce(0) { $0 + $1.values.reduce(0) { $0 + $1.count } }
            + streakFinal.count + 2
    }
}
