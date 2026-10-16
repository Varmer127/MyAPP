import Foundation

/// Muscle groups, used for the exercise library, the muscle map and the weekly volume.
enum Muscle: String, CaseIterable, Identifiable, Codable {
    case chest, shoulders, biceps, triceps, forearms, abs, obliques, traps, lats, upperBack, lowerBack
    case glutes, quads, hamstrings, adductors, calves

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chest: "Prsa"
        case .shoulders: "Ramena"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .forearms: "Předloktí"
        case .abs: "Břicho"
        case .obliques: "Šikmé břicho"
        case .traps: "Trapézy"
        case .lats: "Široký sval zádový"
        case .upperBack: "Horní záda"
        case .lowerBack: "Spodní záda"
        case .glutes: "Hýždě"
        case .quads: "Přední stehna"
        case .hamstrings: "Zadní stehna"
        case .adductors: "Vnitřní stehna"
        case .calves: "Lýtka"
        }
    }
}

enum Equipment: String, CaseIterable, Identifiable, Codable {
    case barbell, dumbbell, machine, cable, bodyweight, kettlebell, band, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .barbell: "Velká činka"
        case .dumbbell: "Jednoručky"
        case .machine: "Stroj"
        case .cable: "Kladka"
        case .bodyweight: "Vlastní váha"
        case .kettlebell: "Kettlebell"
        case .band: "Guma"
        case .other: "Jiné"
        }
    }
}

/// One exercise of the built-in library. Written for Kept, no third-party data.
struct CatalogExercise: Identifiable, Hashable {
    let name: String
    let primary: [Muscle]
    let secondary: [Muscle]
    let equipment: Equipment
    /// One short line on how to do it well.
    let tip: String

    var id: String { name }
    var muscles: [Muscle] { primary + secondary }
}

enum ExerciseCatalog {
    private static func e(_ name: String, _ primary: [Muscle], _ secondary: [Muscle] = [], _ equipment: Equipment, _ tip: String) -> CatalogExercise {
        CatalogExercise(name: name, primary: primary, secondary: secondary, equipment: equipment, tip: tip)
    }

    static let all: [CatalogExercise] = [
        // Chest
        e("Bench press", [.chest], [.triceps, .shoulders], .barbell, "Lopatky stažené, chodidla pevně v zemi, osu spouštěj na spodek prsou."),
        e("Bench press na šikmé lavici", [.chest], [.shoulders, .triceps], .barbell, "Lavice 30–45°, osa jde na horní část prsou."),
        e("Bench press na negativní lavici", [.chest], [.triceps], .barbell, "Krátký rozsah, kontrolovaně dolů."),
        e("Tlaky s jednoručkami", [.chest], [.triceps, .shoulders], .dumbbell, "Jednoručky dole k bokům hrudníku, nahoře je nesrážej."),
        e("Tlaky s jednoručkami na šikmé lavici", [.chest], [.shoulders, .triceps], .dumbbell, "Lokty asi 45° od těla."),
        e("Rozpažování s jednoručkami", [.chest], [.shoulders], .dumbbell, "Lehce pokrčené lokty, protáhni prsa, nespouštěj moc hluboko."),
        e("Rozpažování na kladce", [.chest], [], .cable, "Ruce se potkají před tělem, chvíli podrž stah."),
        e("Peck deck", [.chest], [], .machine, "Zápěstí v rovině s lokty, pomalý návrat."),
        e("Tlaky na stroji na prsa", [.chest], [.triceps], .machine, "Sedačku nastav tak, aby rukojeti byly ve výšce prsou."),
        e("Kliky", [.chest], [.triceps, .shoulders, .abs], .bodyweight, "Tělo v jedné linii, hrudník téměř k zemi."),
        e("Kliky na bradlech", [.chest, .triceps], [.shoulders], .bodyweight, "Předklon zatíží prsa, vzpřímeně spíš triceps."),
        e("Pullover s jednoručkou", [.chest, .lats], [], .dumbbell, "Lokty lehce pokrčené, jednoručka za hlavu jen do protažení."),

        // Back
        e("Mrtvý tah", [.lowerBack, .glutes, .hamstrings], [.traps, .forearms, .quads], .barbell, "Osa u holení, rovná záda, tlač podlahu nohama."),
        e("Rumunský mrtvý tah", [.hamstrings, .glutes], [.lowerBack], .barbell, "Boky dozadu, kolena mírně pokrčená, osa klouže po stehnech."),
        e("Mrtvý tah s jednoručkami", [.hamstrings, .glutes], [.lowerBack], .dumbbell, "Jako rumunský, jednoručky blízko nohou."),
        e("Shyby", [.lats], [.biceps, .upperBack], .bodyweight, "Začni z plného visu, bradu nad osu, bez houpání."),
        e("Shyby podhmatem", [.lats, .biceps], [.upperBack], .bodyweight, "Úzký podhmat víc zapojí biceps."),
        e("Přítahy v předklonu", [.upperBack, .lats], [.biceps, .lowerBack], .barbell, "Trup asi 45°, osu přitahuj k pupku."),
        e("Přítahy jednoruč", [.lats, .upperBack], [.biceps], .dumbbell, "Jednoručka k boku, loket podél těla."),
        e("Přítahy T-osy", [.upperBack, .lats], [.biceps], .barbell, "Hrudník nahoru, lopatky k sobě."),
        e("Stahování kladky", [.lats], [.biceps], .cable, "K horní části prsou, lehce zakloň trup."),
        e("Stahování kladky úzkým úchopem", [.lats], [.biceps], .cable, "Lokty vedeš dolů k bokům."),
        e("Přítahy kladky vsedě", [.upperBack, .lats], [.biceps], .cable, "Rovná záda, na konci stáhni lopatky."),
        e("Přítahy na stroji", [.upperBack, .lats], [.biceps], .machine, "Hrudník na opěrce, tah lokty."),
        e("Face pull", [.shoulders, .upperBack], [.traps], .cable, "Lano k obličeji, lokty vysoko, ruce od sebe."),
        e("Krčení ramen", [.traps], [.forearms], .dumbbell, "Ramena rovně nahoru, nekruž."),
        e("Krčení ramen s osou", [.traps], [.forearms], .barbell, "Krátký pohyb, nahoře podrž."),
        e("Hyperextenze", [.lowerBack], [.glutes, .hamstrings], .bodyweight, "Nahoru jen do roviny s nohama, bez prohnutí."),
        e("Good morning", [.hamstrings, .lowerBack], [.glutes], .barbell, "Osa na zádech, boky dozadu, lehká váha."),

        // Shoulders
        e("Tlaky nad hlavu", [.shoulders], [.triceps, .upperBack], .barbell, "Stažené hýždě a břicho, osa těsně kolem obličeje."),
        e("Tlaky s jednoručkami vsedě", [.shoulders], [.triceps], .dumbbell, "Jednoručky dole na úroveň uší."),
        e("Arnoldovy tlaky", [.shoulders], [.triceps], .dumbbell, "Při tlaku otáčej dlaně ven."),
        e("Upažování", [.shoulders], [], .dumbbell, "Lehká váha, lokty mírně pokrčené, nahoru jen do výšky ramen."),
        e("Upažování na kladce", [.shoulders], [], .cable, "Kladka za tělem, plynulý tah."),
        e("Předpažování", [.shoulders], [], .dumbbell, "Do výšky očí, bez švihu."),
        e("Upažování v předklonu", [.shoulders, .upperBack], [], .dumbbell, "Zadní ramena, malé lokty, lehká váha."),
        e("Reverse peck deck", [.shoulders, .upperBack], [], .machine, "Zadní delty, ruce do stran."),
        e("Tlaky na stroji na ramena", [.shoulders], [.triceps], .machine, "Zády opřený, plný rozsah."),
        e("Přítahy k bradě", [.shoulders, .traps], [], .barbell, "Široký úchop, lokty nad zápěstí."),

        // Arms
        e("Bicepsový zdvih s osou", [.biceps], [.forearms], .barbell, "Lokty u těla, nehoupej trupem."),
        e("Bicepsový zdvih s jednoručkami", [.biceps], [.forearms], .dumbbell, "Nahoře otoč malíček ven."),
        e("Kladivové zdvihy", [.biceps, .forearms], [], .dumbbell, "Palce nahoru po celou dobu."),
        e("Zdvihy na Scottově lavici", [.biceps], [], .barbell, "Dole nepropínej úplně, kontrolovaně."),
        e("Bicepsový zdvih na kladce", [.biceps], [], .cable, "Konstantní napětí, lokty se nehýbou."),
        e("Koncentrovaný zdvih", [.biceps], [], .dumbbell, "Loket opřený o stehno."),
        e("Francouzský tlak", [.triceps], [], .barbell, "Lokty míří ke stropu, osa ke spánkům."),
        e("Tricepsové stahování na kladce", [.triceps], [], .cable, "Lokty u těla, dole propni."),
        e("Tricepsové stahování lanem", [.triceps], [], .cable, "Dole roztáhni lano od sebe."),
        e("Tricepsový tlak nad hlavou", [.triceps], [], .dumbbell, "Lokty u hlavy, protáhni dlouhou hlavu tricepsu."),
        e("Bench press úzkým úchopem", [.triceps, .chest], [.shoulders], .barbell, "Úchop na šířku ramen, lokty u těla."),
        e("Kliky na lavici", [.triceps], [.chest], .bodyweight, "Ruce za sebou na lavici, lokty dozadu."),
        e("Zápěstní zdvihy", [.forearms], [], .barbell, "Předloktí na stehnech, pohyb jen v zápěstí."),
        e("Farmářská chůze", [.forearms, .traps], [.abs], .dumbbell, "Těžké jednoručky, vzpřímeně, krátké kroky."),

        // Legs
        e("Dřep", [.quads, .glutes], [.adductors, .lowerBack], .barbell, "Kolena ve směru špiček, záda rovně, aspoň do paralely."),
        e("Čelní dřep", [.quads], [.glutes, .abs], .barbell, "Lokty vysoko, vzpřímený trup."),
        e("Goblet dřep", [.quads, .glutes], [.adductors], .dumbbell, "Jednoručka u hrudníku, lokty mezi koleny."),
        e("Bulharský dřep", [.quads, .glutes], [.adductors], .dumbbell, "Zadní noha na lavici, váha na přední patě."),
        e("Výpady", [.quads, .glutes], [.hamstrings], .dumbbell, "Dlouhý krok, zadní koleno těsně nad zem."),
        e("Chůze ve výpadech", [.quads, .glutes], [.hamstrings], .dumbbell, "Plynulé kroky vpřed, trup vzpřímeně."),
        e("Leg press", [.quads, .glutes], [.adductors], .machine, "Spodní záda přitlačená, kolena nepropínej."),
        e("Hack dřep", [.quads], [.glutes], .machine, "Hluboko, kolena nad špičkami."),
        e("Předkopávání", [.quads], [], .machine, "Nahoře podrž, pomalý návrat."),
        e("Zakopávání vleže", [.hamstrings], [.calves], .machine, "Boky na lavici, plný rozsah."),
        e("Zakopávání vsedě", [.hamstrings], [], .machine, "Stehna pevně pod polstrem."),
        e("Hip thrust", [.glutes], [.hamstrings], .barbell, "Lopatky na lavici, nahoře stáhni hýždě, brada dolů."),
        e("Glute bridge", [.glutes], [.hamstrings], .bodyweight, "Paty blízko hýždí, tlač pánev nahoru."),
        e("Unožování na kladce", [.glutes], [], .cable, "Pomalý pohyb do strany, trup stabilní."),
        e("Přitahování nohou na stroji", [.adductors], [], .machine, "Kontrolovaně, bez švihu."),
        e("Odtahování nohou na stroji", [.glutes], [], .machine, "Mírný předklon víc zapojí hýždě."),
        e("Výpony ve stoje", [.calves], [], .machine, "Dole protáhni, nahoře podrž."),
        e("Výpony vsedě", [.calves], [], .machine, "Pomalu, plný rozsah."),
        e("Výstupy na bednu", [.quads, .glutes], [.hamstrings], .dumbbell, "Tlač přes patu přední nohy."),
        e("Kettlebell swing", [.glutes, .hamstrings], [.lowerBack, .shoulders], .kettlebell, "Pohyb z boků, ne z rukou."),

        // Core
        e("Plank", [.abs], [.obliques, .shoulders], .bodyweight, "Tělo rovně, hýždě stažené, dýchej."),
        e("Boční plank", [.obliques], [.abs], .bodyweight, "Boky nahoře, tělo v jedné linii."),
        e("Sedy-lehy", [.abs], [], .bodyweight, "Pomalu dolů, netahej za hlavu."),
        e("Zkracovačky", [.abs], [], .bodyweight, "Krátký pohyb, bederní část na zemi."),
        e("Zvedání nohou ve visu", [.abs], [.obliques, .forearms], .bodyweight, "Bez houpání, pánev podsadit."),
        e("Zvedání nohou vleže", [.abs], [], .bodyweight, "Bedra přitisknutá k zemi."),
        e("Kladkové zkracovačky", [.abs], [], .cable, "Vsedě na kolenou, zakulat trup."),
        e("Ruské twisty", [.obliques], [.abs], .bodyweight, "Otáčej trupem, ne jen rukama."),
        e("Ab wheel", [.abs], [.shoulders, .lats], .other, "Jen tak daleko, dokud nepropadáš v bedrech."),
        e("Dead bug", [.abs], [], .bodyweight, "Bedra u země, protilehlá ruka a noha."),
        e("Pallof press", [.obliques, .abs], [], .cable, "Odolej rotaci, ruce rovně před sebe."),
        e("Mountain climbers", [.abs], [.shoulders, .quads], .bodyweight, "Rychlé střídání, boky nízko."),

        // Full body / conditioning
        e("Přemístění", [.quads, .glutes, .traps], [.shoulders, .hamstrings], .barbell, "Výbušně z nohou, osa blízko těla."),
        e("Thruster", [.quads, .shoulders], [.glutes, .triceps], .barbell, "Dřep a rovnou tlak nad hlavu."),
        e("Burpees", [.quads, .chest], [.shoulders, .abs], .bodyweight, "Plynule: klik, výskok, tlesk."),
        e("Veslování na trenažéru", [.upperBack, .quads], [.lats, .biceps], .machine, "Nohy, trup, ruce, zpátky obráceně."),
        e("Švihadlo", [.calves], [.shoulders], .other, "Skákej z špiček, lokty u těla."),
    ]

    static func named(_ name: String) -> CatalogExercise? {
        all.first { $0.name.activityKey == name.activityKey }
    }

    /// Muscles an exercise works; unknown own exercises count for nothing on the map.
    static func muscles(of name: String) -> [Muscle] {
        named(name)?.muscles ?? []
    }

    /// A ready-made list of exercises for a workout's name, used when no own template exists yet.
    static func defaultTemplate(for workout: String) -> [String] {
        let key = workout.activityKey
        func has(_ words: String...) -> Bool { words.contains { key.contains($0.activityKey) } }
        if has("push", "tlak") { return ["Bench press", "Tlaky nad hlavu", "Tlaky s jednoručkami na šikmé lavici", "Upažování", "Tricepsové stahování lanem"] }
        if has("pull", "tah") { return ["Mrtvý tah", "Shyby", "Přítahy v předklonu", "Face pull", "Bicepsový zdvih s osou"] }
        if has("legs", "nohy", "spodn") { return ["Dřep", "Rumunský mrtvý tah", "Leg press", "Zakopávání vleže", "Výpony ve stoje"] }
        if has("horn", "upper") { return ["Bench press", "Přítahy v předklonu", "Tlaky nad hlavu", "Stahování kladky", "Bicepsový zdvih s jednoručkami", "Tricepsové stahování na kladce"] }
        if has("full") { return ["Dřep", "Bench press", "Přítahy v předklonu", "Tlaky nad hlavu", "Plank"] }
        if has("ruce", "ramena") { return ["Tlaky nad hlavu", "Upažování", "Bicepsový zdvih s osou", "Francouzský tlak", "Kladivové zdvihy"] }
        if has("zada", "prsa") { return ["Bench press", "Tlaky s jednoručkami na šikmé lavici", "Shyby", "Přítahy v předklonu", "Přítahy kladky vsedě"] }
        return []
    }
}
