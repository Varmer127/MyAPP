# Právní rámec Kept

Stav k 11. 11. 2026. Texty pro uživatele jsou v `Kept/Resources/Legal/` (česky a anglicky, anglická verze má přednost),
v aplikaci v Nastavení → Dokumenty a u registrace. Právní kontrolu dělá Philip (právník).

## Ústava: co se musí vyřešit, než se něco spustí

Tyto věci se nás dnes netýkají. Jakmile ale na dané oblasti začneme pracovat, nesmí se vydat bez toho, co je u ní napsáno.

**Článek 1: Platby a předplatné (nákupy v aplikaci).**
Před vydáním: pravidla vrácení peněz, zrušení předplatného na pár klepnutí a odkaz na správu předplatného,
oznámení automatického obnovení (cena, období, datum další platby) před potvrzením nákupu, žádné skryté poplatky,
ceny včetně DPH, obnovení nákupů, poučení o odstoupení od smlouvy u digitálního obsahu. Doplnit Podmínky (část 3)
a Zásady (Apple jako příjemce). Týdenní program se slevou za splnění: nejdřív právní posouzení (hazard, spotřebitelské právo).

**Článek 2: Web.**
Zásady a Podmínky na veřejné adrese, kontaktní údaje provozovatele. Cookie lišta jen tehdy, když web použije jiné než
nezbytné cookies nebo měření; do souhlasu se nic nenačítá. Kontrast, popisky obrázků a ovládání klávesnicí i na webu.

**Článek 3: Marketingové e-maily a newsletter.**
Samostatný souhlas (nikdy spojený s podmínkami), záznam o souhlasu, odhlášení jedním klepnutím v každém e-mailu.

**Článek 4: Analytika, hlášení pádů a jakákoli cizí knihovna.**
Před přidáním: k čemu je, jaká data sbírá, zpracovatelská smlouva, zápis do Zásad, `PrivacyInfo.xcprivacy`
a App Privacy v App Store Connect. Sledování napříč aplikacemi jen se souhlasem (App Tracking Transparency).
Licence knihovny zapsat do `docs/CREDITS.md`.

**Článek 5: Umělá inteligence.**
Obsah vytvořený AI označit. Data uživatelů neposílat poskytovateli AI bez zápisu v Zásadách a bez smlouvy,
která zakazuje trénování na těchto datech.

**Článek 6: Nahrávání souborů na server.**
Limity velikosti a typu, lhůta uchování, moderace, postup pro oznámení porušení autorských práv
(v USA registrace zástupce podle DMCA, v EU oznamovací mechanismus podle nařízení o digitálních službách).

**Článek 7: Propagace (web, App Store, sítě).**
Žádné vymyšlené recenze, žádná loga zákazníků bez svolení, žádná nepodložená tvrzení (hlavně o zdraví a výsledcích),
žádná falešná naléhavost (odpočty, „poslední kusy“), žádná nepravdivá tvrzení o certifikacích (SOC 2 apod.),
o dostupnosti jen to, co umíme dodržet.

**Článek 8: Mladší uživatelé.**
Účet je od 15 let (v ČR hranice pro souhlas se zpracováním osobních údajů, § 7 zákona č. 110/2019 Sb.; Philip rozhodl 11. 11. 2026).
Snížení hranice znamená souhlas rodičů a kontrolu pravidel Applu pro děti. Před vydáním v jiné zemi EU ověřit tamní hranici
(např. Německo 16 let).

**Článek 9: Každý nový zpracovatel.**
Zpracovatelská smlouva dřív, než k němu poteče první údaj; doplnit seznam v Zásadách (část 7) a tady.

**Článek 10: Trh mimo EU.**
Před nabídnutím aplikace v USA nebo jinde projít tamní pravidla (děti, soukromí, spotřebitel).

**Článek 11: Změna Podmínek nebo Zásad.**
Nová verze a datum v dokumentu, řádek v tabulce verzí níže, oznámení v aplikaci aspoň 14 dní předem;
u podstatné změny Podmínek nový souhlas.

## Zpracovatelé a příjemci

**Dnes**

| Kdo | K čemu | Jaké údaje | Kde | Smlouva |
|---|---|---|---|---|
| Supabase, Inc. | databáze, přihlášení | vše z části 4 Zásad | AWS Londýn (eu-west-2), Spojené království | uzavřít (Philip) |
| Amazon Web Services, Cloudflare | dílčí zpracovatelé Supabase | totéž | podle Supabase | přes Supabase |
| Sendinblue SAS (Brevo) | e-mail s kódem | e-mailová adresa | Francie | uzavřít (Philip) |
| Discord Inc. | přihlášení přes Discord | samostatný správce | USA | není potřeba |
| Apple | iPhone, Zdraví, rozpoznávání řeči, zálohy | samostatný správce | — | není potřeba |

**Plánováno (fáze 6 a dál)**

- Apple Push Notification service (skutečná upozornění): identifikátor zařízení.
- Přihlášení přes Apple.
- Nákupy přes App Store (StoreKit): platbu zpracovává Apple.
- Synchronizace přes iCloud (CloudKit): data v účtu uživatele, bez našeho přístupu.
**Schváleno 11. 11. 2026 (Philip schválil doporučené volby)**

| Potřeba | Vybráno | Proč | Kdy |
|---|---|---|---|
| Region produkční databáze | Frankfurt (eu-central-1), **odloženo, možná vůbec** | v EU, nejblíž Česku | jen nový projekt, region stávajícího změnit nejde; Philip 11. 11. 2026: později, možná zůstane Londýn (pro Spojené království platí rozhodnutí o odpovídající ochraně) |
| Ochrana registrace (CAPTCHA) | Cloudflare Turnstile | zdarma, bez sledování a hádanek s obrázky | před veřejným vydáním |
| E-maily z vlastní domény | Brevo (zůstává) | v EU, už ho používáme | po koupi domény |
| Hosting webu | Cloudflare Pages | zdarma, statický web bez měření nepotřebuje cookie lištu | fáze 6 |
| Schránka podpory | Seznam Email Profi | česká firma, adresa na vlastní doméně | po koupi domény |
| Hlášení pádů a měření | nic navíc | pády hlásí Apple (Xcode Organizer) se souhlasem uživatele v iOS | — |
| Ověření pravosti aplikace | Apple App Attest | bez dalšího zpracovatele | fáze 6 |

Než se kterákoli služba zapne: zpracovatelská smlouva a zápis do Zásad (část 7), viz článek 9.

## Nařízení o digitálních službách (DSA)

Posouzeno 11. 11. 2026. Kept ukládá texty, které uživatelé píšou (jména, šťouchnutí, názvy sázek, výzev, skupin a aktivit),
takže je **hostingová služba**. Online platformou spíš není, protože obsah nejde veřejnosti, jen přátelům a uzavřeným skupinám
(soukromá komunikace mezi omezeným počtem lidí, recitál 14). Provozovatel je **mikropodnik** (méně než 10 lidí a obrat
do 2 mil. EUR, doporučení 2003/361/ES). Dozor v ČR: Český telekomunikační úřad jako koordinátor digitálních služeb.

| Článek | Povinnost | Jak ji plníme |
|---|---|---|
| 11 | kontaktní místo pro úřady, jazyky | kontakt v Podmínkách, část 1 a 6; česky a anglicky (e-mail doplnit) |
| 12 | kontaktní místo pro uživatele, ne jen automat | totéž |
| 14 | v Podmínkách pravidla moderace včetně automatických nástrojů a vyřizování stížností | Podmínky, část 4 a 6 |
| 16 | oznámení nezákonného obsahu elektronicky, potvrzení přijetí, sdělení rozhodnutí oznamovateli | nahlášení v aplikaci; e-mail i bez účtu; potvrzení a výsledek slíbeny v části 6 |
| 17 | odůvodnění zásahu: o jaký obsah jde, podle čeho, zda rozhodl automat, jak se bránit | slíbeno v části 6; při prvním zásahu použít šablonu se všemi body |
| 18 | podezření na trestný čin ohrožující život nebo bezpečnost ohlásit policii | vnitřní postup provozovatele |
| 15 | výroční zpráva o moderaci | **neplatí**, mikropodnik (čl. 15 odst. 2) |
| 19–28 | další povinnosti online platforem | **neplatí**, i kdyby Kept platformou byl (čl. 19); jen na žádost úřadu sdělit počet uživatelů (čl. 24 odst. 3) |

Přehodnotit, když Kept přidá veřejný obsah (veřejné profily nebo žebříčky pro všechny), nebo když provozovatel přestane být
mikro- či malým podnikem (výjimka doběhne 12 měsíců poté).

## Otevřené body pro právní kontrolu

- Doplnit provozovatele, kontakt a datum účinnosti (v textech označeno `[DOPLNIT]`, anglicky `[TO BE COMPLETED]`).
- Uzavřít zpracovatelské smlouvy se Supabase a Brevem; ověřit mechanismus předání do USA a lhůty provozních záznamů a záloh (`[OVĚŘIT]`).
- Diktování deníku používá rozpoznávání řeči od Applu a zvuk může odejít na jeho servery. V Zásadách je to uvedeno; zvážit vynucení zpracování jen v zařízení, pokud ho čeština podporuje.
- Nový souhlas po podstatné změně Podmínek (článek 11): server zatím umí jen první souhlas při registraci; funkce pro opětovné přijetí nové verze přijde s první takovou změnou.
- Sázky o body: formulace v Podmínkách (část 7) a v popisu pro App Store.
- Ikona a logo navrhl Claude (AI od Anthropicu) na Philipův pokyn; podle podmínek Anthropicu patří výstupy uživateli. Dílo bez lidského autora nemusí být chráněné autorským právem, ochranu názvu a loga dá spíš ochranná známka (zvážit před vydáním).
- Fotky cviků: zdroj uvádí volné dílo (The Unlicense, ověřeno 11. 11. 2026); původ jednotlivých fotek se opírá o prohlášení zdroje.

## Verze dokumentů

| Verze | Datum | Co se změnilo |
|---|---|---|
| 0.1 (návrh) | 11. 11. 2026 | první znění Zásad ochrany soukromí a Podmínek používání, česky a anglicky |
