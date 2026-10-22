# Kept — otevřené věci (osobní verze)

Věci, ke kterým se musíme vrátit. Převod do App Storu je zvlášť v `APP_STORE_CHECKLIST.md`.

## Světlý režim — zkontrolovat na vlastní oči
Kód používá jen barvy z tématu, ale tyto obrazovky jsme ve světlém režimu zatím neviděli:
- Nastavení gymu (řádky s plusem, přetahování pauz, štítek „Výchozí“)
- Karta plánovače s odpočtem a přehledem týdne (Týden)
- Obchod (cenová tlačítka, milníky)
- Sloučená karta „Série skončila“ s comebackem (Dnes)
- Animace bodů (+100 bodů)
- Deník (celá sekce, dopis budoucímu já, zámek)
- Rychlé plánování („už máš“, potvrzení zdvojení)

## Vyzkoušet na telefonu
- Tlačítko Hotovo ve widgetu
- Kalendář iPhonu (povolení, události u dnů, upozornění na kolizi)
- Sdílení zapečetěného týdne
- Živý banner plánovače na zamčené obrazovce
- Zatřesení ceny v obchodě
- Deník: hlasový zápis (mikrofon + rozpoznávání češtiny), zámek Face ID, body za zápis
- Klepnutí na upozornění (oprava pádu z 15. 10.)
- Gym: přepnutí jednoduchý / pokročilý v Nastavení gymu, jednoduchý trénink (velké tlačítko pauzy), nová mapa svalů ve světlém i tmavém režimu
- Widgety na ploše: Kept – další úkol, týden, série, spolehlivost, gym (stopky s tlačítkem pauzy) ve světlém i tmavém vzhledu
- Stopky gymu na zamčené obrazovce a v Dynamic Islandu (tlačítka PAUZA / DALŠÍ SÉRIE, upozornění na konec pauzy)
- Ikony aktivit: změna v Nastavení → Moje aktivity a v onboardingu, zobrazení v úkolech a plánování

## Odloženo po auditu (22. 10. 2026)
- **Tón Drsný:** texty obsahují vulgarismy a urážky; podívat se na to znovu před TestFlightem (věkové hodnocení, soucitný reset po porušení slibu).
- **Angličtina:** později, při převodu do App Storu (String Catalog, rod v textech).
- **Vývojářská tlačítka a klíče:** odstranit až na konci (`DeveloperSection`, `devShow*` a `devHealthDemo`, `HealthService.demoSummary`).
- **Widgety, Live Activity a upozornění na zamčené obrazovce:** soukromí neřešíme.
- **Svědek a serverový čas:** potřebují server (fáze App Storu).
- **Zdraví, načítání při návratu do popředí:** zatím beze změny; nejdřív vysvětlit, co to dělá.
- **Nezpracováno z auditu:** pět stupňů písma místo 29 velikostí, střídmější verzálky u popisků, jemné světlo na horní hraně karet v tmavém režimu, rozdělení velkých pohledů (`TodayView`, `WeekView`, `OnboardingView`).
