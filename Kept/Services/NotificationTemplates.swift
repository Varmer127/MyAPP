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

/// All notification copy. Placeholders: {task}, {time}, {why}, {n}.
/// Savage copy attacks laziness, procrastination and broken promises — never appearance, health or self-worth.
enum NotificationTemplates {
    // MARK: Task escalation, by level

    /// Level 0 — preparation, 30 minutes before the task should start.
    static let prep = [
        "Za 30 minut: {task}.",
        "{task} začíná za půl hodiny. Připrav se.",
        "Za 30 minut máš {task}. Dokonči, co děláš.",
        "Blíží se {task}. Start za 30 minut.",
        "Půl hodiny do {task}. Ukliď si stůl a zavři ostatní věci.",
        "Za 30 minut: {task}. Tohle sis naplánoval sám.",
        "{task} za 30 minut. Žádné překvapení, žádná výmluva.",
        "Za půl hodiny {task}. Buď připravený začít včas.",
    ]

    /// Level 1 — the task should be starting now.
    static let start = [
        "{task} měl právě začít.",
        "Je čas: {task}.",
        "Teď: {task}. Začni.",
        "{task} — start. Otevři to a pusť se do toho.",
        "Je {time}. {task} začíná teď.",
        "Naplánoval sis {task} na teď. Tak začni.",
        "{task}. Čas běží od této chvíle.",
        "Teď je ta chvíle, kterou sis na {task} vyhradil.",
        "Start: {task}. Prvních pět minut je nejtěžších.",
        "{task} je na řadě. Nic dalšího teď není důležitější.",
    ]

    /// Level 2 — direct.
    static let direct = [
        "Je {time} a {task} pořád není hotový.",
        "{task} stále čeká. Je {time}.",
        "Je {time}. {task} jsi ještě nezačal.",
        "{task} není splněný. Deadline se blíží.",
        "Pořád nic u {task}. Je {time}.",
        "{task}: stav nesplněno. Čas {time}.",
        "Je {time}. Na {task} zbývá čím dál méně času.",
        "{task} je pořád otevřený. Začni teď.",
        "Tento závazek zůstává nesplněný: {task}.",
        "Je {time}. {task} se sám neudělá.",
        "{task} čeká už příliš dlouho. Otevři ho.",
        "Dal sis slovo na {task}. Je {time} a hotovo není.",
    ]

    /// Level 3 — strict.
    static let strict = [
        "Zase to odkládáš. {task}. Začni.",
        "{task} odkládáš už příliš dlouho. Přestaň hledat důvody.",
        "Je {time}. Slíbil sis {task}. Kde je?",
        "Tohle je přesně ten moment, kdy se rozhoduje. {task}. Teď.",
        "Odkládání není plán. {task} čeká.",
        "Dal jsi sám sobě slovo. {task} pořád není hotový.",
        "Každá minuta odkladu je rozhodnutí. {task}.",
        "Nečekej na náladu. {task} se dělá i bez ní.",
        "{task}: deadline minul. Dokonči to aspoň pozdě.",
        "Výmluvu si můžeš napsat později. Teď udělej {task}.",
        "Je {time} a ty děláš něco jiného než {task}. Proč?",
        "Tohle sis naplánoval ty, ne nikdo jiný. {task}.",
        "{task} už měl být hotový. Každá další hodina to zhoršuje.",
        "Přestaň vyjednávat sám se sebou. {task}.",
        "Tvoje skóre padá kvůli {task}. Zastav to.",
        "{task} jsi nesplnil už {n}×. Dnes to může být jinak.",
        "Disciplína znamená udělat to, i když se ti nechce. {task}.",
        "Za hodinu budeš litovat, že jsi nezačal teď. {task}.",
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
    ]

    /// Strict copy that quotes the user's own "Why does this matter?".
    static let whyStrict = [
        "Říkal jsi: „{why}“ A {task} pořád není hotový.",
        "Tvoje vlastní slova: „{why}“ Tak proč {task} čeká?",
        "„{why}“ — tohle jsi napsal ty. {task} k tomu vede.",
        "Na tomhle ti záleželo: „{why}“ Dokaž to. {task}.",
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
    private static let sundayOpening = [
        "Je neděle. Naplánuj si týden.",
        "Pořád nemáš naplánovaný týden.",
        "Chceš být produktivní, ale ještě jsi ani nerozhodl, co tento týden uděláš.",
        "Tři hodiny připomínek a pořád nic. Naplánuj si týden.",
    ]

    private static let sundayLater: [NotificationTone: [String]] = [
        .normal: [
            "Závazek na příští týden stále chybí.",
            "Plán týdne není potvrzený. Zabere to deset minut.",
            "Připomínka: příští týden nemá žádný závazek.",
            "Naplánuj si týden, dokud je neděle.",
            "Týden bez plánu se nedá dodržet. Vytvoř ho.",
            "Stále čeká: závazek na příští týden.",
            "Neděle končí. Plán týdne pořád není.",
            "Poslední dnešní připomínka: naplánuj si týden.",
        ],
        .strict: [
            "Bez plánu nemáš co dodržet. Naplánuj si týden.",
            "Odkládáš i samotné plánování. Deset minut. Teď.",
            "Týden začíná zítra a ty nevíš, co v něm uděláš.",
            "Kdo neplánuje, ten se vymlouvá. Otevři Týden.",
            "Pět hodin ignorování. Naplánuj si týden.",
            "Zítra bude pozdě hledat, co je důležité. Plánuj teď.",
            "Neděle končí a ty nemáš jediný závazek na příští týden.",
            "Poslední výzva. Bez závazku jdeš do týdne naslepo.",
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
            "Otevřené závazky dnes: {n}.",
            "Stále otevřeno: {n}. Naplánuj si zbytek dne.",
            "Večer se blíží. Otevřené závazky: {n}.",
        ],
        .strict: [
            "Půlka dne je pryč. Otevřené závazky: {n}.",
            "Stále čeká: {n}. Co z toho uděláš teď?",
            "Den končí. Nesplněné sliby: {n}.",
        ],
        .savage: [
            "Poledne. Otevřené závazky: {n}. A ty ses ještě pořádně nerozjel.",
            "Slíbil sis to a pořád to leží. Otevřeno: {n}. Přestaň se flákat.",
            "Den je skoro pryč. Nesplněné sliby: {n}. Tohle chceš večer vidět?",
        ],
    ]

    static let morningGood = [
        "Včera {n} %. Dnes to zopakuj.",
        "Včera {n} %. Tak vypadá dodržené slovo. Znovu.",
        "Včera {n} %. Nenech to být výjimka.",
    ]

    static let morningAverage = [
        "Včera {n} %. Dnes přidej.",
        "Včera {n} %. Průměr tě nikam neposune.",
        "Včera {n} %. Chybělo málo. Dnes to dotáhni.",
    ]

    static let morningBad = [
        "Včera {n} %. Dnes nemáš co dohánět řečmi. Začni pracovat.",
        "Včera {n} %. Včerejšek nezměníš. Dnešek ano.",
        "Včera {n} %. Dnes to naprav.",
    ]

    static let morningNeutral = [
        "Nový den. Dodrž, co sis slíbil.",
        "Dnešní závazky sis vybral sám. Splň je.",
        "Začni tím nejdůležitějším.",
    ]

    static let realityCheck: [NotificationTone: [String]] = [
        .normal: [
            "Večerní bilance. Dnešní závazky: {n}. Podívej se, jak jsi dopadl.",
            "Je čas na večerní bilanci. Dnešní závazky: {n}.",
            "Večerní bilance: zkontroluj dnešek, dokud ho jde opravit.",
        ],
        .strict: [
            "Večerní bilance. Dnešní závazky: {n}. Kolik z toho je hotovo?",
            "Čas pravdy. Dnešní závazky: {n}. Otevři večerní bilanci.",
            "Den končí. Dodržel jsi slovo? Otevři večerní bilanci.",
        ],
        .savage: [
            "Večerní bilance. Dnešní sliby: {n}. Podívej se, kolik jsi jich zase nedodržel.",
            "Čas pravdy. Dnes ses flákal, nebo makal? Otevři to.",
            "Den je pryč. Čísla nelžou. Otevři večerní bilanci.",
        ],
    ]

    static func morningSentence(yesterday: Double?, seed: Int) -> String {
        guard let yesterday else { return pick(morningNeutral, seed: seed) }
        let percent = Int((yesterday * 100).rounded())
        let pool: [String]
        if yesterday >= 0.8 {
            pool = morningGood
        } else if yesterday >= 0.6 {
            pool = morningAverage
        } else {
            pool = morningBad
        }
        return pick(pool, seed: seed).replacingOccurrences(of: "{n}", with: "\(percent)")
    }

    // MARK: Assembly

    static func taskMessage(level: Int, title: String, time: String, why: String, failures: Int, seed: Int) -> String {
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
        return pick(pool, seed: seed)
            .replacingOccurrences(of: "{task}", with: title)
            .replacingOccurrences(of: "{time}", with: time)
            .replacingOccurrences(of: "{why}", with: why)
            .replacingOccurrences(of: "{n}", with: "\(failures)")
    }

    static func pick(_ pool: [String], seed: Int) -> String {
        guard !pool.isEmpty else { return "" }
        return pool[abs(seed) % pool.count]
    }

    static var totalCount: Int {
        [prep, start, direct, strict, savage, whyStrict, whySavage, sundayOpening,
         morningGood, morningAverage, morningBad, morningNeutral].reduce(0) { $0 + $1.count }
            + [sundayLater, dayNudge, realityCheck].reduce(0) { $0 + $1.values.reduce(0) { $0 + $1.count } }
    }
}
