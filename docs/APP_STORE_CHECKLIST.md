# Kept → App Store: co se musí změnit

Založeno 10. 10. 2026. Aplikace se zatím dolaďuje pro osobní použití; tenhle seznam říká, co je potřeba udělat, až přijde čas na veřejné vydání. Nic z toho zatím není hotové.

## Rozhodnuto (11. 10. 2026)

- **Pořadí:** nejdřív doladit aplikaci pro osobní použití, převod pro App Store až potom.
- **Model:** zdarma + předplatné. Ceny zatím neurčeny.
- **Trh:** Česko a Slovensko + zbytek světa.
- **Jazyky v první verzi:** čeština a angličtina; uživatel si jazyk zvolí při prvním spuštění.
- **Věk:** cílová skupina 13+ (drsný tón obsahuje vulgarismy; souhlas uživatele hodnocení nesnižuje).
- **Synchronizace přes iCloud:** ano, ale až v rámci příprav na App Store (vyžaduje placený účet).
- **Rozsah první verze:** základ zdarma (vždy záložky Dnes, Týden, Nastavení), zbytek jako moduly a v předplatném. Přesné rozdělení zatím neurčeno.
- **Kontrola důkazu fotkou pomocí AI:** ano, ale až později (potřebuje server, souhlas uživatele a rozšířené zásady soukromí).
- **Název:** nerozhodnuto. „Kept“ i „Vowed“ jsou v App Storu obsazené.

## 1. Musí být, jinak to neprojde nebo nedává smysl

- [ ] **Developer tlačítka „Zrušit všechny plány do budoucna“ a „Smazat všechna data a začít znovu“** (Nastavení → Vývojář, přidáno 14. a 16. 10. 2026). Odstranit ještě před ostrým testováním: smazat `Kept/Views/Settings/DeveloperSection.swift` a jeho použití v `SettingsView.swift`. V Release buildu se nezkompiluje, i tak pryč.
- [ ] **Úvodní video.** `Kept/Intro.mp4` je klip Davida Gogginse (cizí autorské dílo, mimo git). Odstranit, nebo nahradit vlastním. Kód přehrávání (`IntroView`) může zůstat.
- [ ] **Jazyky.** Všechny texty jsou česky napevno v kódu (odhadem 600–800 řetězců, ~45 souborů).
  - [ ] přesunout texty do String Catalogu
  - [ ] angličtina (a další jazyky)
  - Rozsah zjištěný 16. 10. 2026: ~260 textů přímo v `Text("…")` (Xcode je vytáhne do String Catalogu sám), ~80 textů předávaných přes proměnné (kategorie, důvody selhání, otázky deníku) k ručnímu převodu, ruční české tvary (`String.days`), napevno nastavená čeština v `Locale.app`, ~190 notifikací ve třech tónech (drsný tón v angličtině spíš napsat znovu), věty skládané z kousků přepsat na celé věty.
  - Od 16. 10. 2026 se nový kód píše tak, aby šel přeložit bez přepisování.
  - [ ] notifikace (`NotificationTemplates`, 143 šablon) napsat pro každý jazyk znovu, ne překládat doslova; drsný tón nechat zkontrolovat rodilým mluvčím
  - [ ] skloňování počtů („1 den / 2 dny / 5 dní“) přes pluralizaci systému místo `String.days`
  - [ ] `Locale.app` a `Calendar.app` jsou vynucené na češtinu a pondělí; přepnout na nastavení zařízení
  - [ ] výchozí názvy kategorií, partií a cviků překládat, vlastní názvy uživatele nechat být
- [ ] **Věci na míru jednomu člověku.**
  - [ ] kategorie jsou pevný `enum` (včetně „Claude a aplikace“); potřeba vlastní kategorie uživatele
  - [ ] výchozí týdenní cíle (Gym 4×, Nový skill 2×…) a minimum 7 aktivit nastavit v úvodním průvodci
  - [ ] výchozí partie v gymu a cviky jako nabídka, ne danost
  - [x] úvodní průvodce (onboarding): hotový 16. 10. 2026 (14 kroků, interaktivní průvodce, aktivity, gym, zámek, vzhled). Před vydáním doplnit volbu angličtiny.
    - [ ] **Sestavení vlastní sekce Gym** (přidáno 16. 10. 2026): uživatel si vybere, jaký split jede (např. push/pull/legs, horní/spodní, full body, vlastní), jaké partie a cviky chce nabízet, kolikrát týdně chodí a výchozí pauzy mezi sériemi. Z toho se předvyplní Nastavení gymu, týdenní cíl a návrhy „Na řadě: …“. Kdo gym nechce, sekci přeskočí a vůbec se mu nezobrazí.
    - [ ] volba minima aktivit týdně (viz níž)
- [ ] **Platby.** Nákupy přes StoreKit 2, obrazovka s nabídkou, obnovení nákupů, rozdělení funkcí na zdarma / placené. Model zatím nerozhodnut.
- [ ] **Zásady ochrany soukromí.** Veřejná URL + vyplněný „App Privacy“ dotazník v App Store Connect. Kvůli HealthKitu povinné.
- [ ] **Web.** Stránka se zásadami soukromí a kontaktem na podporu (obojí povinné odkazy v App Storu).
- [ ] **Drsný tón.** Vulgární notifikace: nesmí být výchozí, jen jako vědomá volba; nastavit odpovídající věkové hodnocení. Titulky notifikací (`punchlines`) obsahují silné vulgarismy v angličtině („FUCK“) – v dotazníku věkového hodnocení uvést častý hrubý jazyk; zvážit variantu bez nich.
- [ ] **Název.** „Kept“ je v App Storu obsazený několika aplikacemi (viz níže). Vybrat rozlišující název a ověřit ochranné známky.

- **Odpočty a tlak na uživatele.** Odpočet u vykoupení série (48 h) je skutečná lhůta a platí se body získanými v aplikaci. Kdyby se body někdy daly koupit za peníze, je odpočet tlačící k nákupu rizikový (klamavé / agresivní obchodní praktiky, „dark patterns“) — před tím právně posoudit. Odpočet se nesmí nikdy sám obnovovat ani být smyšlený.

- **Kalendář iPhonu (přidáno 11. 10. 2026).** Aplikace žádá o úplný přístup ke kalendáři (jen čtení, nic neukládá). Uvést v zásadách ochrany soukromí a v App Store „App Privacy“; text žádosti o povolení přeložit do angličtiny.
- **Obchod za body (přidáno 11. 10. 2026).** Body se dají jen získat v aplikaci. Pokud by se někdy prodávaly za peníze, jde o nákupy v aplikaci se vším, co k tomu patří (viz odpočty výše).

- **Ikona aplikace.** Vlastní, nakreslená od nuly 5. 10. 2026 (černý čtverec, bílá fajfka, zelená čárka). Rozhodnuto 16. 10. 2026: zůstává, zatím nechránit. Před vydáním jen rychle zkontrolovat podobnost s konkurencí v App Storu.

## 2. Na straně vývojářského účtu

- [ ] Apple Developer Program (99 USD / rok)
- [ ] Smlouva o placených aplikacích: bankovní a daňové údaje v App Store Connect
- [ ] Přihlásit se do App Store Small Business Program (provize 15 % místo 30 %)
- [ ] Daně v ČR probrat s účetním
- [ ] Bundle ID `cz.philipstryka.kept` a App Group `group.cz.philipstryka.kept` zaregistrovat pod placeným účtem

## 3. Kvalita pro platící uživatele

- [ ] **Záloha a synchronizace.** Data jsou jen v zařízení; zvážit iCloud (CloudKit). Pozor: SwiftData + CloudKit má omezení (žádné unikátní atributy, všechny vztahy volitelné).
- [ ] **Verzování databáze.** Zavést `VersionedSchema` a migrační plán, aby aktualizace nikdy nerozbila data.
- [ ] **Automatické testy** výpočtu skóre (`ScoreEngine`), odkladů, částečného splnění a migrací. Projekt teď nemá žádný testovací target.
- [ ] **Zjednodušení první verze.** Rozhodnout, co bude v 1.0 a co až později.
- [ ] **Přístupnost.** Dynamická velikost písma (teď pevné velikosti), VoiceOver popisky, kontrast.
- [ ] **Různé velikosti displeje**, případně iPad (teď jen iPhone na výšku).
- [ ] **Time Sensitive notifikace**, aby připomínky prošly režimem Nerušit.
- [ ] **TestFlight** s několika lidmi před vydáním.
- [ ] Odstranit ladicí výpis naplánovaných notifikací (`NotificationManager`, `logger.info`).

## Už hotové základy, na které převod naváže

- Volitelné záložky (Statistiky, Gym, Zdraví) s přepínači v Nastavení; úvodní průvodce je jen nastaví.
- Body a propustky (`PointsService`): hodnoty jsou konstanty na jednom místě, připravené k ladění.

## Nápady na později (nerozhodnuto, nic z toho není naprogramované)

Všechny čtyři mění to, že aplikace dnes nic neposílá mimo telefon. Znamenají server, účty nebo sdílení dat se třetí stranou a rozšíření zásad soukromí.

- **AI kouč.** Buď cloudový model (potřebuje vlastní server jako prostředníka, platí se za každé použití, podle pravidla 5.1.2(i) je nutný výslovný souhlas před odesláním dat), nebo model v zařízení (zdarma a soukromý, ale jen na novějších iPhonech).
- **Ověření důkazu fotkou pomocí AI.** Jde ověřit, co na fotce je; nejde dokázat, že je dnešní a že úkol opravdu proběhl. Podmínkou je focení přímo v aplikaci, ne výběr z galerie.
- **Duely s přáteli.** Vyžadují účty, server a seznam přátel.
- **Přátelé a společná odpovědnost (vize odsouhlasena 16. 10. 2026, podrobnosti dořešíme později).** Uživatel si přidá přátele (pozvánka nebo QR kód). Přátelé navzájem vidí spolehlivost, sérii, zapečetěný týden a co z něj je splněné, a taky když někdo něco vynechal. Můžou poslat šťouchnutí („Zvedni se, máš dneska gym“) jako upozornění, nebo pochvalu. Proč: slib, o kterém ví i někdo jiný, se dodržuje líp; navazuje na sdílení zapečetěného týdne.
  - Uživatel řídí, komu co ukazuje: jen čísla, nebo i názvy úkolů. Deník, selhání („Nesplnil jsem“), míry a fotky se nesdílí nikdy.
  - Šťouchnutí jde vypnout nebo omezit (např. jedno denně od jednoho přítele), drsný tón jen od výslovně povolených.
  - Obnáší: přihlášení a server (zřejmě Supabase projektu MyAPP), změnu slibu „vše jen v telefonu“, zásad ochrany soukromí a údajů v App Storu; blokování a nahlašování (pravidla App Storu pro obsah mezi uživateli); ochranu před šikanou (limity, jen předem připravené zprávy bez volného textu); opatrnost kvůli věku od 13 let.
  - Varianta na začátek bez serveru: „svědek týdne“, zapečetěný týden poslaný kamarádovi přes tlačítko Sdílet.
- **Gym: jednoduchý a pokročilý režim jako základ pro free a placenou verzi (zapsáno 16. 10. 2026, zatím vše zdarma).** Režimy už v aplikaci jsou (volba v onboardingu a v Nastavení gymu, přepnutí bez ztráty dat). Pokročilý režim (cviky po sériích, knihovna, rekordy, mapa svalů, šablony) jde později snadno zamknout za předplatné; jednoduchý zůstane zdarma.
- **Úvodní průvodce s moduly.** Při prvním spuštění: jazyk, tón, které záložky chce mít v liště, propojení se Zdravím a zapnutí Gymu. U Zdraví i Gymu poznámka, že to jde udělat i později v Nastavení. U Gymu zmínit upozornění po tréninku zaznamenaném ve Zdraví (přichází po uložení tréninku, ne při jeho zahájení). Vše musí jít změnit v Nastavení.
- **Mince za splnění úkolů.** Virtuální měna jde udělat jen v zařízení. Skutečné peníze nebo sázky o peníze jsou právní otázka (hazard, pravidla Applu).
- **Minimum aktivit týdně volí uživatel v onboardingu** (dnes výchozí 7, měnit jde v Nastavení → Týdenní cíle). Rozhodnuto 11. 10. 2026, udělat spolu s onboardingem.
- **Anketa „Odkud ses o Kept dozvěděl?“ v onboardingu** (zapsáno 16. 10. 2026, zatím ne). Vyžaduje odesílání na server: Supabase projekt MyAPP, anonymní tabulka jen pro zápis, odeslání až s internetem, přeskočitelná; uvést v zásadách soukromí a App Privacy. Do té doby stačí zdroje a vlastní odkazy v App Store Connect.
- **Marketing kolem Nového roku (zapsáno 16. 10. 2026, všechny body níže odsouhlaseny; v listopadu předat marketingu, připomínka nastavena na 1. 11.).** Novoroční předsevzetí jsou přesně to, co Kept řeší: slib sám sobě a jeho dodržení. Leden je nejsilnější měsíc pro aplikace na návyky a produktivitu, lidé je v té době sami hledají. Nápady: vydat (nebo aspoň spustit předběžnou registraci) do prosince; kampaň typu „Předsevzetí, které tentokrát dodržíš“; „předsevzetí“ jako slib zapečetěný v plánovači; sdílitelná karta „Moje předsevzetí na rok“ (navázat na sdílení zapečetěného týdne); novoroční sleva na předplatné; v App Store Connect připravit událost v aplikaci (In-App Event) a obrázky do App Storu s tímto motivem. Pozor: druhý lednový týden mnoho lidí předsevzetí vzdává, což je dobrý moment na připomínku a „comeback“ sdělení.
- **Obrázky cviků (prověřeno 16. 10. 2026, zatím ne).** Knihovna cviků a mapa svalů jsou vlastní (texty i kresba), bez licenčních omezení. Fotky/ilustrace cviků z cizích zdrojů: free-exercise-db (yuhonas) i exercises.json (wrkout) se hlásí k Unlicense, ale nepíšou, odkud jsou obrázky – původ nejasný, pro placenou aplikaci nepoužívat. wger: data pod Creative Commons „podle jednotlivých položek“ – každý obrázek zvlášť ověřit licenci a uvést autora (u CC BY-SA i stejná licence pro upravené obrázky). Bezpečné cesty: vlastní ilustrace (nakreslit/zadat ilustrátorovi) nebo jen texty a mapa svalů.

## 4. Co uvést v App Storu

- [ ] Popis, klíčová slova a snímky obrazovky v každém jazyce
- [ ] Účel čtení dat ze Zdraví a použití fotoaparátu (`NSHealthShareUsageDescription`, `NSCameraUsageDescription` jsou teď jen česky)
- [ ] Upozornění u pauz v gymu a u drsného tónu ponechat; aplikace není zdravotní ani psychologická rada

## Název „Kept“ – stav k 10. 10. 2026

V App Storu už existují (zjištěno vyhledáváním, ne úplný průzkum):

- „Kept“ – údržba domácnosti (Rueben McBurrows)
- „Kept: Home Inventory“ – inventář domácnosti
- „Kept – saving with your style“ – spoření (Bank of Ayudhya)
- „The Kept App with Chris Powell“ – wellness / fitness

Ochranné známky (USPTO, EUIPO) ověřeny nebyly.
