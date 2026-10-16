import Foundation

enum DiaryService {
    static let pointsPerEntry = 50
    static let letterDelayDays = 30

    /// One question a day, picked by the date so it stays the same all day long.
    static let questions = [
        "Co ti dnes nejvíc pomohlo?",
        "Kde ses dnes vyhnul práci?",
        "Na co jsi dnes hrdý?",
        "Co bys dnes udělal jinak, kdybys mohl začít znovu?",
        "Co tě dnes nejvíc rozptylovalo?",
        "Kdy ses dnes cítil nejvíc v plném nasazení?",
        "Co jsi dnes odkládal a proč?",
        "Jaké rozhodnutí z dneška tě posunulo?",
        "Co tě dnes vyčerpalo víc, než by mělo?",
        "Co ses dnes naučil?",
        "Komu bys dnes chtěl poděkovat?",
        "Co by si o tvém dni řeklo tvoje budoucí já?",
        "Jaký malý krok tě dnes přiblížil k cíli?",
        "Čeho ses dnes bál a udělal jsi to stejně?",
        "Co dnes stálo za to?",
        "Kde sis dnes lhal?",
        "Co by ti zítra ráno ulehčilo start?",
        "Jak ses dnes choval k sobě?",
        "Co ti dnes dodalo energii?",
        "Na co nechceš zapomenout z dnešního dne?",
        "Jaký zvyk ti dnes pomohl, a jaký uškodil?",
        "Co bylo dnes těžší, než jsi čekal?",
        "Kde jsi dnes dodržel slovo, i když se ti nechtělo?",
        "Co bys poradil kamarádovi, který by měl tvůj dnešní den?",
        "Co dnes zůstalo nedořešené?",
        "Za co ses dnes pochválil?",
        "Co tě dnes překvapilo?",
        "Co ti dnes vzalo nejvíc času zbytečně?",
    ]

    static func question(for day: Date) -> String {
        questions[abs(day.daySeed) % questions.count]
    }

    static func entry(on day: Date, in entries: [DiaryEntry]) -> DiaryEntry? {
        entries.first { $0.day.isSameDay(as: day) }
    }

    /// Days in a row with something written. Today counts once written; until then the streak runs to yesterday.
    static func streak(_ entries: [DiaryEntry], now: Date = .now) -> Int {
        let written = Set(entries.filter(\.hasWriting).map { $0.day.startOfDay })
        var day = written.contains(now.startOfDay) ? now.startOfDay : now.startOfDay.addingDays(-1)
        var count = 0
        while written.contains(day) {
            count += 1
            day = day.addingDays(-1)
        }
        return count
    }

    /// Point events for the balance: one per day with something written.
    static func pointEvents(_ entries: [DiaryEntry]) -> [(date: Date, change: Int)] {
        entries.filter(\.hasWriting).map { ($0.createdAt, pointsPerEntry) }
    }

    /// An older entry worth looking back at: a week ago, a month ago or a year ago.
    static func lookBack(_ entries: [DiaryEntry], now: Date = .now) -> (label: String, entry: DiaryEntry)? {
        for (days, label) in [(7, "PŘED TÝDNEM JSI NAPSAL"), (30, "PŘED MĚSÍCEM JSI NAPSAL"), (365, "PŘED ROKEM JSI NAPSAL")] {
            if let entry = entry(on: now.startOfDay.addingDays(-days), in: entries), entry.hasWriting {
                return (label, entry)
            }
        }
        return nil
    }
}
