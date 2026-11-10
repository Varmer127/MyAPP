# Jak píšeme upozornění

Všechny texty jsou v `Kept/Services/NotificationTemplates.swift`, nadpisy v `NotificationManager.swift`
a sociální upozornění v `Services/Account/Notifications.swift`.

## Pravidla

1. **Nadpis nese zprávu.** U připomínek úkolu je nadpisem název úkolu. Nikdy „KEPT“ (název appky iOS ukazuje sám)
   ani obecné „RANNÍ PŘEHLED“. Normální velikost písmen, žádné VELKÉ PÍSMO, to na zamykací obrazovce působí jako křik.
2. **Název úkolu nikdy neohýbáme.** Česky „u Posilovny“ / „na Angličtinu“ z libovolného názvu správně neuděláme,
   stejně jako shodu „Posilovna pořád není hotový“. Proto je název v nadpisu a text pod ním se bez něj obejde.
3. **Jeden konkrétní další krok.** „Začni aspoň na pět minut“, „Vyber jeden a pusť se do něj“. Ne jen stav („Otevřeno: 3“).
4. **Krátce.** Do 80 znaků: banner nahoře na displeji ukáže jen dva řádky (zamykací obrazovka kolem čtyř),
   nadpis kolem 30–40 znaků. Nejdůležitější informace jde dopředu. Hlídá to test `NotificationCopyTests`;
   ranní přehled dává včerejší procento do nadpisu a povzbuzení přidá, jen když se vejde.
5. **Bez rodu.** Žádné „začal“, „slíbil“, „připravený“, „přijal(a)“. Přítomný čas, rozkaz, neutrální vazby
   („Irena a ty jste teď přátelé“, „Irena ti posílá šťouchnutí“).
6. **Normální a Přísný tón míří na chování, ne na člověka.** Po výpadku nabízíme nový start, ne výčitku.
7. **Připomínky úkolu nepředpokládají, jestli je termín za námi.** Stejná úroveň může přijít před i po termínu
   (normální tón ji po termínu opakuje), takže žádné „deadline se blíží“ ani „deadline minul“.
8. **Méně je víc.** Každá zpráva musí mít důvod; když zní urgentně všechno, nevěří se ničemu.

## Z čeho to vychází

- **Sebekritika vs. laskavost k sobě:** Ve studiích o plnění cílů sebekritika brzdila pokrok zhruba dvakrát víc,
  než mu pomáhaly vysoké nároky. Laskavost k sobě po selhání souvisí s tím, že se člověk k cíli vrátí (Sirois;
  Powers a kol.; Miyagawa a kol.). Proto normální a přísný tón nezahanbují a ranní zpráva po špatném dni zní
  „Nový den, čistý start“.
- **Duolingo:** posílá upozornění řízené algoritmem (bandit) s penalizací za opakování stejné zprávy. Vlastní
  testy textů ukazují malé, ale reálné rozdíly. Jejich „pasivně agresivní“ styl má i silnou kritiku, a právě to je
  pro nás drsný tón (zatím odložený, viz rozhodnutí z auditu 10/2026).
- **Personalizace a relevance:** zprávy s konkrétním obsahem (název úkolu, čas, počet) fungují lépe než obecné.
  Proto ranní přehled vypisuje názvy úkolů, ne „Kritické: 0. S deadlinem: 0.“
- **Délka:** nadpis ~30–40 znaků, text do ~110–180 znaků podle zařízení. Bereme spodní hranici.

Zdroje: OneSignal a Appbot (best practices 2026), Duolingo blog (copy testing), V. Boykis „Duo, the Push, and the
Bandits“, Batch a Braze (délky textu), Greater Good Berkeley (laskavost k sobě a prokrastinace).

## Odloženo

- **Drsný tón** (`savage`, `punchlines`, `whySavage`, `.savage` v slovnících): vulgarismy a urážky, navíc s rodem
  („Říkal jsi“). Necháno beze změny podle rozhodnutí z auditu, projít před TestFlightem / App Store (věkové hodnocení).
- **Lokalizace:** šablony jsou zatím obyčejné řetězce v polích; při převodu do angličtiny je přesuneme do katalogu.
