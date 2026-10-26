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

## Přátelé a sociální část (plán v dokumentu „Kept: přátelé a sociální část, plán“)
- Fáze 0–7 podle plánu: základ (Supabase dev + prod, RLS, serverový čas, Discord, stav účtu), přátelé a bezpečnost (nahlášení, blokování, smazání účtu, věková brána), pošťouchnutí a Nerušit, sdílení a žebříčky, sázky a společné věci, aplikace připravená pro App Store, účty a závěr (Apple Developer, doména, Apple přihlášení, push, App Attest, právní věci), iPad po dokončení celé aplikace.
- Účet je **volitelný**. V onboardingu jedna krátká obrazovka (VYTVOŘIT ÚČET / PŘESKOČIT); zamčené části s nabídkou odemknutí; karta po prvním zapečetěném týdnu.
- Apple Developer účet a doména: až v závěrečné fázi, nejdřív je aplikace hotová pro App Store. Druhý iPhone k dispozici kdykoli. Pozvánky zatím QR a ručně zadaný kód, odkazy s doménou.
- **Přihlášení přes Facebook:** zatím ne (nákladnější: schvalování u Mety, ověření firmy, horší údaje o soukromí). Vrátit se k tomu později, pokud bude potřeba. Apple a Discord ano.
- **Věk 16+** s věkovou bránou při založení účtu; ověřit možnost Declared Age Range (iOS 26).
- **Serverový čas** je součástí základu sociální části.
- Citlivé údaje (váha, deník, zdraví, fotky, poznámky) nikdy na server; na server jen povolená pole.
- **Pošťouchnutí:** jen vlastní text do 100 znaků, žádné hotové věty a žádné „přísnější“ věty se souhlasem (zrušeno 26. 10.). Bez denního limitu, jednomu člověku nejvýše jednou za 3 hodiny. **Žádný filtr vulgarit**; ochrana je Nahlásit, zablokovat, odebrat. Riziko: pravidla Applu 1.2 chtějí filtrování nevhodného obsahu; případně volitelný filtr na straně příjemce, ve výchozím stavu vypnutý. Odkazy v textu zakázané (potvrdit).
- **Nerušit:** jeden režim, důvod ze seznamu (Práce, Škola, Trénink, Cesta, Dovolená, Spánek, Nemoc, Klid, Rodina, Soustředění) nebo vlastní do 6 slov; přátelé ve výchozím stavu důvod nevidí.
- **Žebříčky:** zatím dva, Spolehlivost a Odznaky; zapnuté ve výchozím stavu, vypnutí v samostatné záložce. Další si Philip doplní sám později (neevidovat v TODO).
- **Sázky:** body v úschově, žádné reálné peníze ani darování bodů. Nejnižší sázka 200 bodů (krátké i dlouhodobé), jinak bez limitu na výši, denní součet i počet, v jedné sázce nejvýše 10 lidí; strop je jen vlastní zůstatek. Dlouhodobé sázky s více účastníky (tvůrce zve, další lze přidat později, nejvýše rok); vedlejší podmínky volným textem mimo aplikaci.
- **Přidání přátel:** QR, odkaz nebo celý identifikátor `Jméno#čtyřčíslí`; jméno povinné už v onboardingu; hledání jen podle jména bez čísel ne; před přijetím žádosti jen jméno a iniciála. Jméno jde změnit nejvýše jednou za 7 dní (vazby jedou přes účet).
- Odebrání přítele se musí propsat všude (sdílení, sázky s vrácením bodů, pošťouchnutí, mezipaměť, blokovaný nemůže poslat novou žádost).
- Moderace od první fáze (nahlášení, blokování, filtr, kontakt na podporu, reakce do 24 h, smazání účtu v aplikaci); právní texty a GDPR v závěrečné fázi.
- **Registrace nabízena na čtyřech místech:** onboarding, zamčená záložka Přátelé, karta po prvním zapečetěném týdnu, tlačítko Registrovat se / Odhlásit se v Nastavení. Odznaky získané jen v telefonu jsou pro všechny; zamčené jsou jen ty, co vyžadují přátele. Do žebříčku Odznaky se počítají jen odznaky uživatelů s účtem, ověřené serverem.
- **Nový telefon:** účet obnoví vše na serveru (profil, přátelé, body, sázky, ověřené odznaky); osobní data (úkoly, grafy, statistiky, deník, váha, zdraví, fotky) přes iCloud synchronizaci (viz Dodělat), ne přes náš server.

## Přihlášení e-mailem (25. 10. 2026)
- V aplikaci je přihlášení **e-mailem s šestimístným kódem, bez hesla** (vedle Discordu). Heslo se zatím nedělá; kdyby bylo potřeba, vyžaduje obnovu hesla a vlastní odesílač e-mailů.
- Výchozí e-maily Supabase mají malý limit (asi 2 za hodinu) a posílají se z cizí adresy. Před vydáním: vlastní SMTP z naší domény (fáze 6) a ochrana proti hromadné registraci (CAPTCHA, např. Cloudflare Turnstile).
- Šablony e-mailů „Confirm signup“ i „Magic Link“ musí obsahovat `{{ .Token }}` (kód), jinak přijde jen odkaz. **Supabase šablony nejde upravit, dokud není nastavený vlastní SMTP** (Authentication → Emails → SMTP Settings). Do té doby je v aplikaci přihlášení e-mailem vypnuté (`ServerConfig.emailLoginEnabled = false`); po nastavení SMTP a úpravě šablon přepnout na `true`.

## Přihlášení: poznámky (25. 10. 2026)
- **Okno iOS s adresou projektu** („Kept chce použít k přihlášení fsaefkdsjcecebhoqagq.supabase.co“) vyskakuje systém před otevřením přihlášení; text nejde upravit. Zmizí jen s vlastní doménou přihlášení (Supabase custom domain, placený doplněk, např. auth.kept…); vrátit se k tomu v závěrečné fázi s doménou.
- **Přihlášení přes Apple** jde až s placeným Apple Developer účtem (Services ID, klíč, schopnost Sign in with Apple v aplikaci); do té doby je jen Discord. Kód připravit v závěrečné fázi, Apple pravidla 4.8 ho u přihlášení přes třetí stranu vyžadují.
- Přihlášení Discord v aplikaci ještě není ověřené na skutečném účtu.

## Nedořešené a neodsouhlasené (rekapitulace 26. 10. 2026)

### Čeká na tvoje rozhodnutí
- **Ranní přehled se nezobrazuje:** myslí se notifikace v 7:30 (chodí jen ve dny s otevřeným úkolem), nebo úvodní obrazovka po ránu (3:00 až 10:30, po 4 h nečinnosti, 1× denně, ne v den průvodce)? Chceš notifikaci i pro prázdné dny?
- **Filtr vulgarit:** odstraněn. Riziko u Applu (pravidlo 1.2). Návrh: volitelný filtr na straně příjemce, vypnutý. Odkazy v pošťouchnutí zatím zakázané, potvrdit.
- **Hledání přátel:** teď jen celé označení `Jméno#1234`, QR a kód. Chceš i hledání jen podle jména? (nedoporučuji, je to věkově citlivá aplikace)
- **Věková brána:** udělal jsem rok + měsíc narození a blokaci telefonu na 30 dní po zamítnutí. Nebylo výslovně odsouhlaseno. Ověřit ještě Apple Declared Age Range.
- Jméno pro přátele a oslovení z onboardingu (5. pád) zůstávají dvě oddělené věci (potvrzeno 26. 10.).
- **Přátelé jako záložka:** teď jsou v Nastavení pod účtem. Chceš volitelnou záložku (limit 2 navíc)?
- **Nové okno Přidat úkol:** je varianta A, další možnosti rozbalené. Výchozí stav (rozbalené/sbalené) a vzhled ve světlém režimu k potvrzení.
- **Úvodní video:** přepínač je pryč, ale kód a soubor Intro.mp4 zůstaly. Smazat úplně?
- **Přihlášení e-mailem s heslem** (místo kódu): až s doménou, rozhodnout později.

### Čeká na tvoji akci
- Spustit migraci fáze 1 v Supabase SQL Editoru (`supabase/migrations/20261025120000_phase1_friends.sql`), pak napsat „hotovo“.
- Vyzkoušet přihlášení přes Discord v aplikaci a napsat, jak to dopadlo.
- Commit a push (od fáze 0 je necommitnuté skoro vše).

### Moje nedodělané
- SQL testy v CI (`supabase test db`) jsem nespustil; první běh v CI je ověří.
- Fáze 1 v aplikaci (přátelé, QR, blokování, nahlášení) není vyzkoušená na dvou účtech.
- Vizuálně neověřeno: Statistiky, graf trendu, Nastavení a Záložky ve světlém režimu, pull-to-refresh, export dat, úprava existujícího úkolu v novém okně.
- Aktualizovat plán v dokumentu (sekce Moderace a další ještě zmiňují filtr a starší stav) a `docs/APP_STORE_CHECKLIST.md`.
- **Soukromí:** `PrivacyInfo.xcprivacy` a údaje o sběru dat v App Store Connect je nutné doplnit (e-mail, jméno, identifikátor, kód přítele, síťová komunikace).
- Serverový čas se v aplikaci měří, ale nic ho zatím nepoužívá.

### Plánované fáze, které ještě nezačaly
- Fáze 2: pošťouchnutí (100 znaků, 1× za 3 h na člověka) a Nerušit (důvody ze seznamu).
- Fáze 3: sdílení týdne, kopírování plánů, gratulace, žebříčky Spolehlivost a Odznaky, úrovně viditelnosti.
- Fáze 4: sázky (úschova bodů, min. 200, dlouhodobé s více lidmi), společné výzvy, svědek, párový parťák, skupiny, sdílené aktivity v kalendáři.
- Fáze 5: aplikace připravená pro App Store (uklidit vývojářská tlačítka, `ci-checks.sh` změnit z varování na chybu, bezpečnostní testy).
- Fáze 6: Apple Developer účet, doména, přihlášení přes Apple, SMTP a e-mailový kód, vlastní doména přihlášení, push, App Attest, produkční Supabase, právní texty a GDPR, TestFlight.
- Fáze 7: iPad.
- Mimo fáze: synchronizace přes iCloud (CloudKit) před vydáním, CD do TestFlight, angličtina, přezkoumání tónu Drsný, soukromí widgetů a zamykací obrazovky, svědek zprávou, vydání před Novým rokem (marketing v listopadu).

### Rozhodnuto 26. 10. 2026
- Hledání přátel jen podle celého označení (`Jméno#1234`) nebo QR kódu; ručně psaný kód zrušen.
- Věková brána: žádná blokace telefonu, po chybě se dá zadat datum znovu (účet se při zamítnutí nemaže).
- Přátelé nebudou záložka; vstup je v Nastavení, na Dnes, ve Statistikách a v Profilu (u odznaků).
- Úvodní video i `Intro.mp4` smazány.
- Přihlášení e-mailem (SMTP) a vlastní doména přihlášení: fáze 6.
- Ranní přehled: Philip ověří a ozve se.
- Chyba přihlášení Discordem (stav se nezměnil): příčinou byl dotaz na sloupec `invite_code`, který vznikne až migrací fáze 1. Opraveno i tím, že se chyba ukáže a nabídne „Zkusit znovu“.
- Věková brána podle vzoru Instagramu a Facebooku (26. 10.): jen zadání data narození, bez zaškrtávátka věku; souhlas s pravidly je jedna věta pod tlačítkem „Vytvořit účet“; hláška o 16 letech až po zamítnutí. Zbývá právní ověření (v ČR je věk souhlasu se zpracováním osobních údajů 15 let) a odkaz na pravidla, až budou na webu (fáze 6).

## Fáze 2: pošťouchnutí a Nerušit (26. 10. 2026, v práci)
- Hotovo v kódu: pošťouchnutí jen vlastním textem (1 až 100 znaků, bez odkazů, jednomu člověku 1× za 3 h, bez denního limitu, ochranný strop 120 za hodinu), příchozí pošťouchnutí v seznamu přátel, smazání a nahlášení (nahlášený text zmizí a jde s nahlášením moderátorovi), zrušením přátelství se pošťouchnutí mezi nimi smažou; režim Nerušit (důvod ze seznamu nebo vlastní do 6 slov, volitelně ukázat přátelům, volitelný automatický konec, dokud je zapnuté, nejde šťouchnout).
- Migrace `supabase/migrations/20261026120000_phase2_pokes_dnd.sql` čeká na spuštění v Supabase; testy `supabase/tests/database/pokes.test.sql` poběží v CI.
- Upozornění na pošťouchnutí jsou zatím jen uvnitř aplikace. Skutečný push přijde ve fázi 6 (potřebuje Apple Developer účet).
- Potvrzeno 26. 10.: komu je zapnuto Nerušit, toho nejde šťouchnout; zákaz šťouchání pro zneužití se nastavuje z dashboardu (`poke_banned_at`).
- Neověřeno vizuálně (simulátor není přihlášený); vyzkoušet na telefonu po spuštění migrace.
- Schránka Upozornění: zvonek vpravo v řádku s názvem každé záložky; na Dnes vedle plamínku, „PŘIDAT ÚKOL“ je pod tím přes celou šířku. Obsah: „Jak dopadl včerejšek“ (shrnutí včerejšího dne, odlišné od ranního přehledu, který mluví o dnešku), týdenní a měsíční příběh, žádosti o přátelství, nová pošťouchnutí.
