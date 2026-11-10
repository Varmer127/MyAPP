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
    /// The photo set in the bundle (free-exercise-db, public domain): "ex-<photo>-0.jpg" starts the movement, "-1" ends it.
    let photo: String

    var id: String { name }
    var muscles: [Muscle] { primary + secondary }
}

enum ExerciseCatalog {
    private static func e(_ name: String, _ primary: [Muscle], _ secondary: [Muscle] = [], _ equipment: Equipment, _ tip: String,
                          _ photo: String) -> CatalogExercise {
        CatalogExercise(name: name, primary: primary, secondary: secondary, equipment: equipment, tip: tip, photo: photo)
    }

    static let all: [CatalogExercise] = [
        // Chest
        e("Bench press", [.chest], [.triceps, .shoulders], .barbell, "Lopatky stažené, chodidla pevně v zemi, osu spouštěj na spodek prsou.", "Barbell_Bench_Press_-_Medium_Grip"),
        e("Bench press na šikmé lavici", [.chest], [.shoulders, .triceps], .barbell, "Lavice 30–45°, osa jde na horní část prsou.", "Barbell_Incline_Bench_Press_-_Medium_Grip"),
        e("Bench press na negativní lavici", [.chest], [.triceps], .barbell, "Krátký rozsah, kontrolovaně dolů.", "Decline_Barbell_Bench_Press"),
        e("Tlaky s jednoručkami", [.chest], [.triceps, .shoulders], .dumbbell, "Jednoručky dole k bokům hrudníku, nahoře je nesrážej.", "Dumbbell_Bench_Press"),
        e("Tlaky s jednoručkami na šikmé lavici", [.chest], [.shoulders, .triceps], .dumbbell, "Lokty asi 45° od těla.", "Incline_Dumbbell_Press"),
        e("Rozpažování s jednoručkami", [.chest], [.shoulders], .dumbbell, "Lehce pokrčené lokty, protáhni prsa, nespouštěj moc hluboko.", "Dumbbell_Flyes"),
        e("Rozpažování na kladce", [.chest], [], .cable, "Ruce se potkají před tělem, chvíli podrž stah.", "Cable_Crossover"),
        e("Peck deck", [.chest], [], .machine, "Zápěstí v rovině s lokty, pomalý návrat.", "Butterfly"),
        e("Tlaky na stroji na prsa", [.chest], [.triceps], .machine, "Sedačku nastav tak, aby rukojeti byly ve výšce prsou.", "Machine_Bench_Press"),
        e("Kliky", [.chest], [.triceps, .shoulders, .abs], .bodyweight, "Tělo v jedné linii, hrudník téměř k zemi.", "Pushups"),
        e("Kliky na bradlech", [.chest, .triceps], [.shoulders], .bodyweight, "Předklon zatíží prsa, vzpřímeně spíš triceps.", "Dips_-_Chest_Version"),
        e("Pullover s jednoručkou", [.chest, .lats], [], .dumbbell, "Lokty lehce pokrčené, jednoručka za hlavu jen do protažení.", "Straight-Arm_Dumbbell_Pullover"),

        // Back
        e("Mrtvý tah", [.lowerBack, .glutes, .hamstrings], [.traps, .forearms, .quads], .barbell, "Osa u holení, rovná záda, tlač podlahu nohama.", "Barbell_Deadlift"),
        e("Rumunský mrtvý tah", [.hamstrings, .glutes], [.lowerBack], .barbell, "Boky dozadu, kolena mírně pokrčená, osa klouže po stehnech.", "Romanian_Deadlift"),
        e("Mrtvý tah s jednoručkami", [.hamstrings, .glutes], [.lowerBack], .dumbbell, "Jako rumunský, jednoručky blízko nohou.", "Stiff-Legged_Dumbbell_Deadlift"),
        e("Shyby", [.lats], [.biceps, .upperBack], .bodyweight, "Začni z plného visu, bradu nad osu, bez houpání.", "Pullups"),
        e("Shyby podhmatem", [.lats, .biceps], [.upperBack], .bodyweight, "Úzký podhmat víc zapojí biceps.", "Chin-Up"),
        e("Přítahy v předklonu", [.upperBack, .lats], [.biceps, .lowerBack], .barbell, "Trup asi 45°, osu přitahuj k pupku.", "Bent_Over_Barbell_Row"),
        e("Přítahy jednoruč", [.lats, .upperBack], [.biceps], .dumbbell, "Jednoručka k boku, loket podél těla.", "One-Arm_Dumbbell_Row"),
        e("Přítahy T-osy", [.upperBack, .lats], [.biceps], .barbell, "Hrudník nahoru, lopatky k sobě.", "T-Bar_Row_with_Handle"),
        e("Stahování kladky", [.lats], [.biceps], .cable, "K horní části prsou, lehce zakloň trup.", "Wide-Grip_Lat_Pulldown"),
        e("Stahování kladky úzkým úchopem", [.lats], [.biceps], .cable, "Lokty vedeš dolů k bokům.", "V-Bar_Pulldown"),
        e("Přítahy kladky vsedě", [.upperBack, .lats], [.biceps], .cable, "Rovná záda, na konci stáhni lopatky.", "Seated_Cable_Rows"),
        e("Přítahy na stroji", [.upperBack, .lats], [.biceps], .machine, "Hrudník na opěrce, tah lokty.", "Leverage_Iso_Row"),
        e("Face pull", [.shoulders, .upperBack], [.traps], .cable, "Lano k obličeji, lokty vysoko, ruce od sebe.", "Face_Pull"),
        e("Krčení ramen", [.traps], [.forearms], .dumbbell, "Ramena rovně nahoru, nekruž.", "Dumbbell_Shrug"),
        e("Krčení ramen s osou", [.traps], [.forearms], .barbell, "Krátký pohyb, nahoře podrž.", "Barbell_Shrug"),
        e("Hyperextenze", [.lowerBack], [.glutes, .hamstrings], .bodyweight, "Nahoru jen do roviny s nohama, bez prohnutí.", "Hyperextensions_Back_Extensions"),
        e("Good morning", [.hamstrings, .lowerBack], [.glutes], .barbell, "Osa na zádech, boky dozadu, lehká váha.", "Good_Morning"),

        // Shoulders
        e("Tlaky nad hlavu", [.shoulders], [.triceps, .upperBack], .barbell, "Stažené hýždě a břicho, osa těsně kolem obličeje.", "Standing_Military_Press"),
        e("Tlaky s jednoručkami vsedě", [.shoulders], [.triceps], .dumbbell, "Jednoručky dole na úroveň uší.", "Seated_Dumbbell_Press"),
        e("Arnoldovy tlaky", [.shoulders], [.triceps], .dumbbell, "Při tlaku otáčej dlaně ven.", "Arnold_Dumbbell_Press"),
        e("Upažování", [.shoulders], [], .dumbbell, "Lehká váha, lokty mírně pokrčené, nahoru jen do výšky ramen.", "Side_Lateral_Raise"),
        e("Upažování na kladce", [.shoulders], [], .cable, "Kladka za tělem, plynulý tah.", "Standing_Low-Pulley_Deltoid_Raise"),
        e("Předpažování", [.shoulders], [], .dumbbell, "Do výšky očí, bez švihu.", "Front_Dumbbell_Raise"),
        e("Upažování v předklonu", [.shoulders, .upperBack], [], .dumbbell, "Zadní ramena, malé lokty, lehká váha.", "Seated_Bent-Over_Rear_Delt_Raise"),
        e("Reverse peck deck", [.shoulders, .upperBack], [], .machine, "Zadní delty, ruce do stran.", "Reverse_Machine_Flyes"),
        e("Tlaky na stroji na ramena", [.shoulders], [.triceps], .machine, "Zády opřený, plný rozsah.", "Machine_Shoulder_Military_Press"),
        e("Přítahy k bradě", [.shoulders, .traps], [], .barbell, "Široký úchop, lokty nad zápěstí.", "Upright_Barbell_Row"),

        // Arms
        e("Bicepsový zdvih s osou", [.biceps], [.forearms], .barbell, "Lokty u těla, nehoupej trupem.", "Barbell_Curl"),
        e("Bicepsový zdvih s jednoručkami", [.biceps], [.forearms], .dumbbell, "Nahoře otoč malíček ven.", "Dumbbell_Bicep_Curl"),
        e("Kladivové zdvihy", [.biceps, .forearms], [], .dumbbell, "Palce nahoru po celou dobu.", "Hammer_Curls"),
        e("Zdvihy na Scottově lavici", [.biceps], [], .barbell, "Dole nepropínej úplně, kontrolovaně.", "Preacher_Curl"),
        e("Bicepsový zdvih na kladce", [.biceps], [], .cable, "Konstantní napětí, lokty se nehýbou.", "Standing_Biceps_Cable_Curl"),
        e("Koncentrovaný zdvih", [.biceps], [], .dumbbell, "Loket opřený o stehno.", "Concentration_Curls"),
        e("Francouzský tlak", [.triceps], [], .barbell, "Lokty míří ke stropu, osa ke spánkům.", "EZ-Bar_Skullcrusher"),
        e("Tricepsové stahování na kladce", [.triceps], [], .cable, "Lokty u těla, dole propni.", "Triceps_Pushdown"),
        e("Tricepsové stahování lanem", [.triceps], [], .cable, "Dole roztáhni lano od sebe.", "Triceps_Pushdown_-_Rope_Attachment"),
        e("Tricepsový tlak nad hlavou", [.triceps], [], .dumbbell, "Lokty u hlavy, protáhni dlouhou hlavu tricepsu.", "Standing_Dumbbell_Triceps_Extension"),
        e("Bench press úzkým úchopem", [.triceps, .chest], [.shoulders], .barbell, "Úchop na šířku ramen, lokty u těla.", "Close-Grip_Barbell_Bench_Press"),
        e("Kliky na lavici", [.triceps], [.chest], .bodyweight, "Ruce za sebou na lavici, lokty dozadu.", "Bench_Dips"),
        e("Zápěstní zdvihy", [.forearms], [], .barbell, "Předloktí na stehnech, pohyb jen v zápěstí.", "Palms-Up_Barbell_Wrist_Curl_Over_A_Bench"),
        e("Farmářská chůze", [.forearms, .traps], [.abs], .dumbbell, "Těžké jednoručky, vzpřímeně, krátké kroky.", "Farmers_Walk"),

        // Legs
        e("Dřep", [.quads, .glutes], [.adductors, .lowerBack], .barbell, "Kolena ve směru špiček, záda rovně, aspoň do paralely.", "Barbell_Squat"),
        e("Čelní dřep", [.quads], [.glutes, .abs], .barbell, "Lokty vysoko, vzpřímený trup.", "Front_Barbell_Squat"),
        e("Goblet dřep", [.quads, .glutes], [.adductors], .dumbbell, "Jednoručka u hrudníku, lokty mezi koleny.", "Goblet_Squat"),
        e("Bulharský dřep", [.quads, .glutes], [.adductors], .dumbbell, "Zadní noha na lavici, váha na přední patě.", "Split_Squat_with_Dumbbells"),
        e("Výpady", [.quads, .glutes], [.hamstrings], .dumbbell, "Dlouhý krok, zadní koleno těsně nad zem.", "Dumbbell_Lunges"),
        e("Chůze ve výpadech", [.quads, .glutes], [.hamstrings], .dumbbell, "Plynulé kroky vpřed, trup vzpřímeně.", "Bodyweight_Walking_Lunge"),
        e("Leg press", [.quads, .glutes], [.adductors], .machine, "Spodní záda přitlačená, kolena nepropínej.", "Leg_Press"),
        e("Hack dřep", [.quads], [.glutes], .machine, "Hluboko, kolena nad špičkami.", "Hack_Squat"),
        e("Předkopávání", [.quads], [], .machine, "Nahoře podrž, pomalý návrat.", "Leg_Extensions"),
        e("Zakopávání vleže", [.hamstrings], [.calves], .machine, "Boky na lavici, plný rozsah.", "Lying_Leg_Curls"),
        e("Zakopávání vsedě", [.hamstrings], [], .machine, "Stehna pevně pod polstrem.", "Seated_Leg_Curl"),
        e("Hip thrust", [.glutes], [.hamstrings], .barbell, "Lopatky na lavici, nahoře stáhni hýždě, brada dolů.", "Barbell_Hip_Thrust"),
        e("Glute bridge", [.glutes], [.hamstrings], .bodyweight, "Paty blízko hýždí, tlač pánev nahoru.", "Butt_Lift_Bridge"),
        e("Přitahování nohou na stroji", [.adductors], [], .machine, "Kontrolovaně, bez švihu.", "Thigh_Adductor"),
        e("Odtahování nohou na stroji", [.glutes], [], .machine, "Mírný předklon víc zapojí hýždě.", "Thigh_Abductor"),
        e("Výpony ve stoje", [.calves], [], .machine, "Dole protáhni, nahoře podrž.", "Standing_Calf_Raises"),
        e("Výpony vsedě", [.calves], [], .machine, "Pomalu, plný rozsah.", "Seated_Calf_Raise"),
        e("Výstupy na bednu", [.quads, .glutes], [.hamstrings], .dumbbell, "Tlač přes patu přední nohy.", "Dumbbell_Step_Ups"),
        e("Kettlebell swing", [.glutes, .hamstrings], [.lowerBack, .shoulders], .kettlebell, "Pohyb z boků, ne z rukou.", "One-Arm_Kettlebell_Swings"),

        // Core
        e("Plank", [.abs], [.obliques, .shoulders], .bodyweight, "Tělo rovně, hýždě stažené, dýchej.", "Plank"),
        e("Boční plank", [.obliques], [.abs], .bodyweight, "Boky nahoře, tělo v jedné linii.", "Side_Bridge"),
        e("Sedy-lehy", [.abs], [], .bodyweight, "Pomalu dolů, netahej za hlavu.", "Sit-Up"),
        e("Zkracovačky", [.abs], [], .bodyweight, "Krátký pohyb, bederní část na zemi.", "Crunches"),
        e("Zvedání nohou ve visu", [.abs], [.obliques, .forearms], .bodyweight, "Bez houpání, pánev podsadit.", "Hanging_Leg_Raise"),
        e("Zvedání nohou vleže", [.abs], [], .bodyweight, "Bedra přitisknutá k zemi.", "Flat_Bench_Lying_Leg_Raise"),
        e("Kladkové zkracovačky", [.abs], [], .cable, "Vsedě na kolenou, zakulat trup.", "Cable_Crunch"),
        e("Ruské twisty", [.obliques], [.abs], .bodyweight, "Otáčej trupem, ne jen rukama.", "Russian_Twist"),
        e("Ab wheel", [.abs], [.shoulders, .lats], .other, "Jen tak daleko, dokud nepropadáš v bedrech.", "Ab_Roller"),
        e("Dead bug", [.abs], [], .bodyweight, "Bedra u země, protilehlá ruka a noha.", "Dead_Bug"),
        e("Pallof press", [.obliques, .abs], [], .cable, "Odolej rotaci, ruce rovně před sebe.", "Pallof_Press"),
        e("Mountain climbers", [.abs], [.shoulders, .quads], .bodyweight, "Rychlé střídání, boky nízko.", "Mountain_Climbers"),

        // Full body / conditioning
        e("Přemístění", [.quads, .glutes, .traps], [.shoulders, .hamstrings], .barbell, "Výbušně z nohou, osa blízko těla.", "Power_Clean"),
        e("Thruster", [.quads, .shoulders], [.glutes, .triceps], .kettlebell, "Dřep a rovnou tlak nad hlavu.", "Kettlebell_Thruster"),
        e("Veslování na trenažéru", [.upperBack, .quads], [.lats, .biceps], .machine, "Nohy, trup, ruce, zpátky obráceně.", "Rowing_Stationary"),
        e("Švihadlo", [.calves], [.shoulders], .other, "Skákej z špiček, lokty u těla.", "Rope_Jumping"),

        // More exercises, each with its photos
        e("Tlaky na šikmé lavici na stroji", [.chest], [.shoulders, .triceps], .machine, "Rukojeti ve výšce horní části prsou, lopatky na opěrce.", "Leverage_Incline_Chest_Press"),
        e("Rozpažování na kladce zespodu", [.chest], [.shoulders], .cable, "Ruce vedeš zespodu nahoru před obličej, cílí na horní prsa.", "Low_Cable_Crossover"),
        e("Rozpažování na šikmé lavici", [.chest], [.shoulders], .dumbbell, "Lavice 30°, lokty lehce pokrčené po celou dobu.", "Incline_Dumbbell_Flyes"),
        e("Bench press v Smithově stroji", [.chest], [.triceps, .shoulders], .machine, "Lavici postav tak, aby osa dopadala na spodek prsou.", "Smith_Machine_Bench_Press"),
        e("Kliky s nohama na vyvýšení", [.chest], [.shoulders, .triceps], .bodyweight, "Čím výš nohy, tím víc pracují horní prsa a ramena.", "Push-Ups_With_Feet_Elevated"),
        e("Tlaky s jednoručkami neutrálním úchopem", [.chest, .triceps], [.shoulders], .dumbbell, "Dlaně k sobě šetří ramena a víc zapojí triceps.", "Dumbbell_Bench_Press_with_Neutral_Grip"),
        e("Svend press", [.chest], [.shoulders], .other, "Kotouče drž stlačené mezi dlaněmi celou dobu.", "Svend_Press"),
        e("Tlaky na kladce vestoje", [.chest], [.shoulders, .triceps], .cable, "Krok vpřed a zpevněný trup, kladky ve výšce prsou.", "Standing_Cable_Chest_Press"),
        e("Floor press", [.chest, .triceps], [.shoulders], .barbell, "Lokty se dotknou země, pak výbušně nahoru.", "Floor_Press"),
        e("Mrtvý tah s trap bar", [.quads, .glutes], [.hamstrings, .lowerBack, .traps], .barbell, "Stojíš uvnitř osy, záda zůstávají vzpřímenější.", "Trap_Bar_Deadlift"),
        e("Sumo mrtvý tah", [.glutes, .adductors, .quads], [.hamstrings, .lowerBack], .barbell, "Široký postoj, ruce uvnitř kolen, kolena tlač ven.", "Sumo_Deadlift"),
        e("Rack pull", [.lowerBack, .traps, .glutes], [.hamstrings, .forearms], .barbell, "Mrtvý tah od kolen, posiluje horní část tahu.", "Rack_Pulls"),
        e("Přítahy jednoručkami v předklonu", [.upperBack, .lats], [.biceps, .lowerBack], .dumbbell, "Trup skoro vodorovně, jednoručky k bokům.", "Bent_Over_Two-Dumbbell_Row"),
        e("Přítahy v předklonu podhmatem", [.lats, .upperBack], [.biceps], .barbell, "Podhmat víc zapojí spodní část zad a biceps.", "Reverse_Grip_Bent-Over_Rows"),
        e("Australské shyby", [.upperBack, .lats], [.biceps], .bodyweight, "Tělo rovné jako prkno, hrudník k ose.", "Inverted_Row"),
        e("Stahování kladky propnutýma rukama", [.lats], [.triceps], .cable, "Ruce skoro rovné, pohyb jen v ramenou.", "Straight-Arm_Pulldown"),
        e("Stahování kladky jednoruč", [.lats], [.biceps], .cable, "Loket táhni dolů k boku, trup se netočí.", "One_Arm_Lat_Pulldown"),
        e("Přítahy kladky jednoruč vsedě", [.lats, .upperBack], [.biceps], .cable, "Ruka jde k boku, na konci lehce otoč trup.", "Seated_One-arm_Cable_Pulley_Rows"),
        e("Přítahy na šikmé lavici", [.upperBack, .lats], [.biceps, .shoulders], .dumbbell, "Hrudník na lavici, záda nemusí nic držet.", "Dumbbell_Incline_Row"),
        e("Shyby se zátěží", [.lats], [.biceps, .upperBack], .bodyweight, "Zátěž na opasku, technika stejná jako u shybů.", "Weighted_Pull_Ups"),
        e("Přítahy na stroji shora", [.lats, .upperBack], [.biceps], .machine, "Táhneš šikmo shora dolů, hrudník na opěrce.", "Leverage_High_Row"),
        e("Krčení ramen na kladce", [.traps], [.forearms], .cable, "Kladka drží napětí i dole.", "Cable_Shrugs"),
        e("Přítahy landmine jednoruč", [.lats, .upperBack], [.biceps, .forearms], .barbell, "Konec osy přitahuj k boku, druhou rukou se opři.", "One-Arm_Long_Bar_Row"),
        e("Tlaky s jednoručkami vestoje", [.shoulders], [.triceps, .abs], .dumbbell, "Stažené hýždě a břicho, nezaklánět se.", "Standing_Dumbbell_Press"),
        e("Push press", [.shoulders], [.triceps, .quads], .barbell, "Krátký podřep a výbušný tlak, nohy pomůžou.", "Push_Press"),
        e("Tlaky v Smithově stroji", [.shoulders], [.triceps], .machine, "Lavici postav tak, aby osa šla těsně před obličejem.", "Smith_Machine_Overhead_Shoulder_Press"),
        e("Tlaky na kladce vsedě", [.shoulders], [.triceps], .cable, "Konstantní napětí po celou dobu.", "Seated_Cable_Shoulder_Press"),
        e("Zadní ramena na kladce", [.shoulders, .upperBack], [], .cable, "Ruce do stran a dozadu, lehká váha.", "Cable_Rear_Delt_Fly"),
        e("Roztahování gumy", [.upperBack, .shoulders], [], .band, "Skvělé jako rozcvička ramen.", "Band_Pull_Apart"),
        e("Upažování vsedě", [.shoulders], [], .dumbbell, "Vsedě nejde švihat, čistá práce ramen.", "Seated_Side_Lateral_Raise"),
        e("Předpažování s kotoučem", [.shoulders], [], .other, "Kotouč drž oběma rukama, zvedej do výšky očí.", "Front_Plate_Raise"),
        e("Přítahy k bradě s jednoručkami", [.shoulders, .traps], [], .dumbbell, "Lokty vedou pohyb, jen do výšky ramen.", "Standing_Dumbbell_Upright_Row"),
        e("Vnější rotace na kladce", [.shoulders], [.upperBack], .cable, "Loket u těla, otáčíš jen předloktím ven.", "External_Rotation_with_Cable"),
        e("Bicepsový zdvih s EZ osou", [.biceps], [.forearms], .barbell, "Zalomená osa šetří zápěstí.", "EZ-Bar_Curl"),
        e("Zdvihy na šikmé lavici", [.biceps], [], .dumbbell, "Paže za tělem protáhnou dlouhou hlavu bicepsu.", "Incline_Dumbbell_Curl"),
        e("Spider curl", [.biceps], [], .dumbbell, "Hrudníkem na šikmé lavici, paže visí kolmo.", "Spider_Curl"),
        e("Kladivové zdvihy na kladce", [.biceps, .forearms], [], .cable, "Lano, palce nahoru, konstantní napětí.", "Cable_Hammer_Curls_-_Rope_Attachment"),
        e("Zdvihy nadhmatem", [.forearms, .biceps], [], .barbell, "Nadhmat posiluje předloktí.", "Reverse_Barbell_Curl"),
        e("Zottmanovy zdvihy", [.biceps, .forearms], [], .dumbbell, "Nahoru podhmatem, dolů nadhmatem.", "Zottman_Curl"),
        e("Bicepsový zdvih na stroji", [.biceps], [], .machine, "Lokty v ose stroje, plný rozsah.", "Machine_Bicep_Curl"),
        e("Tricepsové stahování V-osou", [.triceps], [], .cable, "Lokty u těla, dole úplně propni.", "Triceps_Pushdown_-_V-Bar_Attachment"),
        e("Tricepsový tlak nad hlavou lanem", [.triceps], [], .cable, "Zády ke kladce, lano za hlavou.", "Triceps_Overhead_Extension_with_Rope"),
        e("Zapažování s jednoručkou", [.triceps], [], .dumbbell, "Paže u těla, pohybuje se jen předloktí.", "Tricep_Dumbbell_Kickback"),
        e("Kliky na bradlech na triceps", [.triceps], [.chest, .shoulders], .bodyweight, "Trup vzpřímeně, lokty dozadu.", "Dips_-_Triceps_Version"),
        e("Tricepsový stroj", [.triceps], [], .machine, "Lokty v ose stroje.", "Machine_Triceps_Extension"),
        e("Úzké kliky", [.triceps], [.chest], .bodyweight, "Ruce pod rameny, lokty podél těla.", "Push-Ups_-_Close_Triceps_Position"),
        e("JM press", [.triceps], [.chest], .barbell, "Kříženec bench pressu a francouzského tlaku.", "JM_Press"),
        e("Navíjení závaží", [.forearms], [], .other, "Navíjej i odvíjej pomalu.", "Wrist_Roller"),
        e("Dřep v Smithově stroji", [.quads, .glutes], [.hamstrings], .machine, "Chodidla mírně před osou.", "Smith_Machine_Squat"),
        e("Box dřep", [.quads, .glutes], [.hamstrings, .lowerBack], .barbell, "Krátce si sedni na bednu, pak výbušně nahoru.", "Box_Squat"),
        e("Sumo dřep s jednoručkou", [.quads, .adductors, .glutes], [], .dumbbell, "Široký postoj, jednoručka visí mezi nohama.", "Plie_Dumbbell_Squat"),
        e("Zercher dřep", [.quads, .glutes], [.abs, .upperBack], .barbell, "Osa v loktech, trup vzpřímený.", "Zercher_Squats"),
        e("Dřep s vlastní vahou", [.quads, .glutes], [], .bodyweight, "Základ všech dřepů.", "Bodyweight_Squat"),
        e("Pistol dřep", [.quads, .glutes], [.abs], .kettlebell, "Dřep na jedné noze, kettlebell jako protiváha.", "Kettlebell_Pistol_Squat"),
        e("Zpětné výpady", [.quads, .glutes], [.hamstrings], .dumbbell, "Krok dozadu šetří kolena.", "Dumbbell_Rear_Lunge"),
        e("Výpady s osou", [.quads, .glutes], [.hamstrings], .barbell, "Osa na zádech, trup vzpřímený.", "Barbell_Lunge"),
        e("Sissy dřep", [.quads], [], .bodyweight, "Kolena dopředu, trup a stehna v jedné linii.", "Weighted_Sissy_Squat"),
        e("Mrtvý tah na propnutých nohou", [.hamstrings], [.lowerBack, .glutes], .barbell, "Nohy skoro rovné, boky dozadu.", "Stiff-Legged_Barbell_Deadlift"),
        e("Mrtvý tah na jedné noze", [.hamstrings, .glutes], [.lowerBack], .kettlebell, "Pánev rovně, zadní noha jde nahoru.", "Kettlebell_One-Legged_Deadlift"),
        e("Glute ham raise", [.hamstrings, .glutes], [.calves], .machine, "Zadní stehna táhnou tělo nahoru.", "Glute_Ham_Raise"),
        e("Severské zakopávání", [.hamstrings], [.glutes], .bodyweight, "Pomalu dolů, ruce chytí pád.", "Natural_Glute_Ham_Raise"),
        e("Zakopávání vestoje", [.hamstrings], [], .machine, "Jedna noha, pomalý návrat.", "Standing_Leg_Curl"),
        e("Pull through na kladce", [.glutes, .hamstrings], [.lowerBack], .cable, "Pohyb z boků jako u swingu.", "Pull_Through"),
        e("Zanožování na kladce", [.glutes], [.hamstrings], .cable, "Manžeta na kotníku, noha jde dozadu.", "One-Legged_Cable_Kickback"),
        e("Zanožování v kleku", [.glutes], [.hamstrings], .bodyweight, "Na čtyřech, pata ke stropu.", "Glute_Kickback"),
        e("Glute bridge s osou", [.glutes], [.hamstrings], .barbell, "Vleže na zemi, osa přes boky.", "Barbell_Glute_Bridge"),
        e("Most na jedné noze", [.glutes], [.hamstrings], .bodyweight, "Pánev zůstává rovně.", "Single_Leg_Glute_Bridge"),
        e("Výpony na leg pressu", [.calves], [], .machine, "Jen špičky na plošině.", "Calf_Press_On_The_Leg_Press_Machine"),
        e("Výpony s jednoručkou", [.calves], [], .dumbbell, "Na schodu pro plný rozsah.", "Standing_Dumbbell_Calf_Raise"),
        e("Výskoky na bednu", [.quads, .glutes], [.calves], .other, "Doskoč měkce a sestup krokem.", "Front_Box_Jump"),
        e("Výskoky z dřepu", [.quads, .glutes], [.calves], .bodyweight, "Výbušnost, měkké dopady.", "Freehand_Jump_Squat"),
        e("Monster walk s gumou", [.glutes], [.adductors], .band, "Guma kolem kotníků, krátké kroky.", "Monster_Walk"),
        e("Zkracovačky na stroji", [.abs], [], .machine, "Zakulať trup, netahej rukama.", "Ab_Crunch_Machine"),
        e("Obrácené zkracovačky", [.abs], [], .bodyweight, "Pánev se odlepí od země.", "Reverse_Crunch"),
        e("Zkracovačky lanem vestoje", [.abs], [], .cable, "Zády ke kladce, zakulať trup.", "Standing_Rope_Crunch"),
        e("Dřevorubec na kladce", [.obliques], [.abs, .shoulders], .cable, "Rotace z trupu, ruce rovně.", "Standing_Cable_Wood_Chop"),
        e("Nůžky", [.abs], [], .bodyweight, "Bedra přitisknutá k zemi.", "Flutter_Kicks"),
        e("Šikmé zkracovačky", [.obliques], [.abs], .bodyweight, "Loket k protilehlému kolenu.", "Oblique_Crunches_-_On_The_Floor"),
        e("Úklony s jednoručkou", [.obliques], [], .dumbbell, "Jen do strany, ne dopředu.", "Dumbbell_Side_Bend"),
        e("Kolena k hrudníku na bradlech", [.abs], [.obliques], .bodyweight, "Opři se o předloktí v opěrce, bez houpání.", "Knee_Hip_Raise_On_Parallel_Bars"),
        e("Jackknife", [.abs], [], .bodyweight, "Ruce a nohy se potkají nahoře.", "Jackknife_Sit-Up"),
        e("Přetahy loket–koleno", [.abs, .obliques], [], .bodyweight, "Pomalá rotace, ne švih.", "Cross-Body_Crunch"),
        e("Turecký vztyk", [.shoulders, .abs], [.glutes, .obliques], .kettlebell, "Oči celou dobu na kettlebellu.", "Kettlebell_Turkish_Get-Up_Squat_style"),
        e("Kettlebell windmill", [.obliques], [.shoulders, .hamstrings], .kettlebell, "Ruka nahoře, oči na kettlebellu.", "Kettlebell_Windmill"),
        e("Battle ropes", [.shoulders], [.abs, .forearms], .other, "Vlny z ramen, trup zpevněný.", "Battling_Ropes"),
        e("Tlačení saní", [.quads, .glutes], [.calves, .shoulders], .other, "Nízko, krátké a rychlé kroky.", "Sled_Push"),
        e("Hody medicinbalem o zem", [.abs, .shoulders], [.lats], .other, "Celým tělem, ne jen rukama.", "Overhead_Slam"),
        e("Rotoped", [.quads], [.calves, .hamstrings], .machine, "Sedlo ve výšce kyčle.", "Bicycling_Stationary"),
        e("Air bike", [.quads], [.shoulders], .machine, "Čím víc tlačíš, tím větší odpor.", "Air_Bike"),
        e("Eliptical", [.quads], [.glutes, .calves], .machine, "Šetrné ke kloubům.", "Elliptical_Trainer"),
        e("Stepper", [.quads, .glutes], [.calves], .machine, "Nestahuj se rukama.", "Stairmaster"),
        e("Běh na páse", [.quads], [.hamstrings, .calves], .machine, "Krátký krok, dopad pod těžiště.", "Running_Treadmill"),
        e("Kettlebell přemístění", [.glutes, .hamstrings], [.shoulders, .forearms], .kettlebell, "Kettlebell se obtočí kolem ruky, nebouchá do předloktí.", "One-Arm_Kettlebell_Clean"),
        e("Kettlebell trh", [.glutes, .shoulders], [.hamstrings], .kettlebell, "Jedním pohybem až nad hlavu.", "One-Arm_Kettlebell_Snatch"),
        e("Trh", [.quads, .glutes, .shoulders], [.hamstrings, .traps], .barbell, "Technický cvik, začni s prázdnou osou.", "Power_Snatch"),
        e("Nadhoz", [.quads, .glutes, .shoulders], [.triceps, .traps], .barbell, "Přemístění na ramena, pak výraz nad hlavu.", "Clean_and_Jerk"),
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
