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

## Dodělat (domluveno 22. 10. 2026)
- **Svědek zprávou bez serveru** (systémové sdílení hotové zprávy po zapečetění a uzavření dne) – zatím nedělat, zapsáno.
- **Serverový čas** – poslední fáze před App Storem (`supabase-myapp`).
- **Synchronizace přes iCloud (CloudKit)** místo exportu souboru: ověřit, že modely splňují pravidla CloudKitu, zapnout iCloud schopnost, testovat na dvou zařízeních. Export JSON zůstává jako malá záložní volba.
- **Propojení uživatelů** (pošťouchnutí, sdílení plánů): sociální vrstva se serverem, účty, pravidla přístupu (RLS), GDPR; zvážit po vydání nebo dřív, podle tempa.

## CI / CD
- **CI** hotové (`.github/workflows/ci.yml`, `scripts/ci-checks.sh`): při pushi na `main` a u pull requestů rychlé kontroly, testy v Debug a sestavení Release.
- **CD (budoucí):** nahrání do TestFlightu a App Storu. Potřebuje placený účet vývojáře, podpisové certifikáty, aplikaci v App Store Connect a klíč API v tajných proměnných GitHubu. Nejméně práce je Xcode Cloud (podepisuje sám), jinak `fastlane` + GitHub Actions. Dělat až těsně před TestFlightem.
- Před TestFlightem přepnout v `ci-checks.sh` upozornění na vývojářské klíče (`devShow*`, `devHealthDemo`) na chybu.
