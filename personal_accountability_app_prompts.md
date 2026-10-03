# Personal Accountability iOS App — Master Prompt + Design Prompt

## 1. Master Prompt

Chci, abys fungoval zároveň jako senior iOS developer, product designer, UX designer a software architect.

Tvým úkolem je vytvořit pro mě kompletní nativní iOS aplikaci určenou výhradně pro moje osobní použití.

Aplikace nebude publikována v App Storu, nebude mít více uživatelů a nepotřebuje login ani backend.

Chci skutečně funkční aplikaci, kterou budu moct otevřít v Xcode, buildnout a nainstalovat na svůj vlastní iPhone.

Použij:

- Swift
- SwiftUI
- SwiftData
- UserNotifications
- Charts framework
- PhotosPicker tam, kde je potřeba
- minimum externích dependencies

Všechna data chci ukládat lokálně do zařízení.

Nechci cloud, login, externí analytics ani backend v první verzi.

==================================================
HLAVNÍ IDEA APLIKACE
==================================================

Nechci obyčejný todo list.

Nechci klasický habit tracker.

Chci osobní accountability systém, který mě bude nutit dodržovat závazky, které jsem si sám nastavil.

Hlavní myšlenka celé aplikace je:

"Dal jsi sám sobě slovo. Dodržel jsi ho?"

Aplikace má být přísná.

Nemá se mě snažit za každou cenu chválit.

Pokud se flákám, odkládám důležité věci, dávám si výmluvy nebo si uměle snižuji cíle, chci, aby mě s tím aplikace přímo konfrontovala.

Hlavní dlouhodobé metriky budou:

1. PROMISES KEPT
2. PRODUCTIVITY SCORE
3. ACCOUNTABILITY SCORE
4. COMMITMENT INTEGRITY

Nejdůležitější metrikou bude PROMISES KEPT.

Například:

84%
PROMISES KEPT

To znamená:

"84 % závazků, které sis sám naplánoval, jsi skutečně dodržel."

==================================================
WEEKLY COMMITMENT
==================================================

Každou neděli musím povinně vytvořit plán následujícího týdne.

Weekly Commitment je jeden z hlavních pilířů aplikace.

Během neděle mě aplikace musí opakovaně upozorňovat, dokud Weekly Commitment nevytvořím.

Chci intenzivní reminder systém.

Například každou hodinu během rozumné části dne.

Například:

10:00
"Je neděle. Naplánuj si týden."

11:00
"Pořád nemáš naplánovaný týden."

12:00
"Chceš být produktivní, ale ještě jsi ani nerozhodl, co tento týden uděláš."

13:00
"Tři hodiny připomínek a pořád nic. Naplánuj si týden."

Pokud používám Strict nebo Savage tone, upozornění se mohou postupně zostřovat.

Jakmile Weekly Commitment potvrdím, všechny další reminders na plánování týdne musí být zrušeny.

Před potvrzením zobraz souhrn například:

THIS WEEK I COMMIT TO:

5x Self Development
4x Work
3x School
2x Reading
3x Sport

17 TOTAL COMMITMENTS

A výrazné tlačítko:

I COMMIT

Po stisknutí:

- ulož timestamp
- ulož kompletní originální podobu plánu
- od této chvíle je možné sledovat případné změny

Pokud Weekly Commitment během týdne upravím:

- zachovej originální verzi
- zachovej current version
- eviduj odstraněné tasky
- eviduj přesunuté tasky
- eviduj změněné priority
- eviduj změněné deadliny

Nikdy nesmí jít jednoduše odstranit nepříjemný task a tím si zvýšit skóre.

==================================================
TASK MODEL
==================================================

Každý task musí podporovat:

- title
- category
- date
- optional deadline
- planned duration
- priority
- points / weight
- notes
- Why does this matter?
- optional proof requirement
- optional focus timer
- original commitment status
- edited after commitment
- completed
- completed late
- skipped
- failed
- recovery task
- completion timestamp
- original scheduled date
- current scheduled date

==================================================
DEADLINE
==================================================

Deadline nebude povinný.

Při vytváření tasku:

[ ] Use deadline

Pokud vypnuto:
task musí být splněn pouze do konce dne.

Pokud zapnuto:
nastavím konkrétní čas.

Například:

Study for Exam
Wednesday
Deadline: 18:00

vs.

Gym
Wednesday
No specific deadline

==================================================
KATEGORIE A PRIORITY
==================================================

Aplikace musí ve výchozím nastavení preferovat oblasti, které mě dlouhodobě rozvíjejí.

Výchozí hierarchie:

1. Self Development
2. Work / Business
3. Education / School
4. Professional Reading / Knowledge
5. Personal Administration
6. Sport / Fitness
7. Other

Self Development může obsahovat například:

- AI
- Claude
- coding
- business skills
- professional skills
- languages
- learning useful software
- learning new skills

Work / Business:

- project work
- business
- deep work
- client work
- important professional tasks

Education:

- university
- exams
- studying
- assignments

Reading:

- professional books
- educational books
- useful non-fiction

Sport je pozitivní, ale nechci, aby byl ve výchozím skóre důležitější než profesní nebo intelektuální rozvoj.

Task priority:

- Low
- Medium
- High
- Critical

Například možné váhy:

Critical Self Development: 5
Critical Work: 5
High Education: 4
Professional Reading: 3
Administration: 2
Gym: 2
Optional Sport: 1

Uživatel musí mít možnost váhu manuálně změnit.

==================================================
TODAY SCREEN
==================================================

Hlavní obrazovka musí být extrémně jednoduchá.

Chci, aby působila jako performance dashboard.

Například:

TODAY

ACCOUNTABILITY
81

PROMISES KEPT
86%

PRODUCTIVITY
74%

4 / 6
TASKS COMPLETED

Dále task cards.

Například:

CLAUDE WORK

High Priority
60 min
Deadline 18:00

[ START ]
[ DONE ]
[ SKIP ]

Pokud task používá Focus Mode:

[ START FOCUS ]

Pokud je deadline překročený:
card musí vizuálně ukázat overdue stav.

==================================================
NO EXCUSES MODE
==================================================

Pokud task nesplním nebo dám SKIP, nestačí pouze task přeskočit.

Musím projít accountability flow.

STEP 1:

WHY DID YOU FAIL?

Možnosti:

- I forgot
- I procrastinated
- I was lazy
- I didn't feel like it
- I planned badly
- I didn't have enough time
- Unexpected situation
- Health
- Other

STEP 2:

SELF-CRITIQUE

Povinné textové pole:

"Why did this actually happen?"

Nastav rozumné minimum délky, například 20 znaků.

STEP 3:

WHAT WILL YOU DO DIFFERENTLY?

Povinné nebo silně doporučené textové pole:

"What will prevent this from happening again?"

Vše ukládej do historie.

Aplikace má být schopna tyto odpovědi později použít.

Například:

"V úterý jsi napsal, že ses na Claude práci vykašlal kvůli procrastination. Dnes se stalo to samé."

==================================================
FAILURE MEMORY
==================================================

Aplikace musí mít dlouhodobou paměť mých selhání.

Sleduj:

- jaké tasky často nesplním
- jaké kategorie často nesplním
- které dny týdne jsou problematické
- v jakých časech často selžu
- které priority nejčastěji selhávají
- jaké důvody uvádím
- jaké výmluvy se opakují
- jaké self-critique texty se opakují
- kolikrát jsem task přesunul
- kolikrát jsem snížil Weekly Commitment
- jak často task dokončím pozdě
- kolikrát jsem ignoroval reminders

Například:

PATTERN DETECTED

Claude Work

4 failures in last 6 attempts

Most common reason:
Procrastination

A následně:

"Poslední 4 ze 6 Claude sessions jsi nesplnil. Dnes můžeš ten pattern přerušit."

==================================================
NOTIFICATION TONES
==================================================

Chci 3 režimy:

NORMAL
STRICT
SAVAGE

NORMAL:

věcný a neutrální.

STRICT:

přímý a konfrontační.

SAVAGE:

velmi tvrdý accountability režim.

Savage mode může používat tvrdší slovník včetně výrazů typu:

"Zase se chováš jako líný hovado. Otevři ten task a začni."

"Furt meleš o tom, čeho chceš dosáhnout. Tak kde je ta práce?"

"Zamysli se nad svým životem. Tohle je přesně to chování, které tě drží na místě."

"Dal sis závazek a zase před ním utíkáš."

"Chceš výsledky lidí, kteří makají, ale dnes se tak nechováš."

"Kolikrát ještě budeš říkat, že začneš později?"

"Další výmluva ti žádný výsledek nevytvoří."

"Nikdo tě nepřijde zachránit. Udělej tu práci."

"Včera sis slíbil, že se to nebude opakovat. A co děláš dnes?"

Savage mode nemá používat:

- výzvy k sebepoškozování
- výzvy k hladovění
- ponižování vzhledu
- nenávistné nadávky

Tvrdý tón má být zaměřen na moje chování, lenost, prokrastinaci a nedodržené závazky.

Chci minimálně 100 různých notification templates.

==================================================
ESCALATING NOTIFICATIONS
==================================================

Notifikace mají eskalovat.

LEVEL 0 — PREPARATION

Například 30 minut před taskem:

"Za 30 minut: Claude Work."

LEVEL 1 — START

"Claude Work měl právě začít."

LEVEL 2 — DIRECT

"Je 19:15 a Claude Work pořád není hotový."

LEVEL 3 — STRICT

"Zase to odkládáš. Začni."

LEVEL 4 — SAVAGE

"Furt meleš o tom, čeho chceš dosáhnout. Tak kde je ta práce?"

Výběr intenzity musí zohlednit:

- Notification Tone
- task priority
- dobu po deadline
- počet ignorovaných reminders
- poslední failure history
- poslední task failures
- Promises Kept
- Productivity Score
- Accountability Score

Například:

Critical task
+
45 minutes overdue
+
3 recent failures
+
Savage mode

= maximum escalation

==================================================
PRODUCTIVITY SCORE
==================================================

Chci Weighted Productivity.

Nechci, aby například:

Gym ✅
Walk ✅
Shopping ✅
Cleaning ✅
Claude ❌
Study ❌

vedlo k:

"67 % — Good job."

To je špatně.

Pokud selžu na nejdůležitějších aktivitách, musí být skóre výrazně níže.

Například:

Task completion:
67%

Weighted Productivity:
31%

Critical commitments:
0 / 2

A hodnocení:

"Byl jsi aktivní. Nebyl jsi produktivní."

Výpočet může vycházet z:

earned weighted points / possible weighted points

Dále uprav podle:

- on-time completion
- late completion
- skipped
- missed
- Critical task failure
- repeated failure
- recovery task bonus

Například:

Completed on time:
100 % hodnoty

Completed late:
70–90 % podle zpoždění

Missed:
0 %

Skipped:
0 %

Critical missed:
může mít dodatečný negativní vliv na Accountability Score

==================================================
PROMISES KEPT
==================================================

Promises Kept má být jednoduchá a tvrdá metrika.

Například:

Original Weekly Commitment:
20 tasks

Actually completed:
17

PROMISES KEPT:
85%

Pokud task po potvrzení odstraním:
stále zůstává v denominatoru.

Pokud ho přesunu:
stále jde o původní commitment.

Pokud ho snížím nebo změním:
historie musí zachovat původní závazek.

==================================================
ACCOUNTABILITY SCORE
==================================================

Chci dlouhodobý Accountability Score od 0 do 100.

Může reflektovat:

- Promises Kept
- Productivity Score
- late tasks
- skipped tasks
- deleted commitments
- commitment edits
- repeated failures
- No Excuses completion
- recovery behaviour
- streaks
- consistency

Například:

ACCOUNTABILITY
81

Subtitle:

"You're generally reliable, but you repeatedly postpone high-priority work."

Chci transparentní algoritmus.

Nechci random číslo.

Navrhni konkrétní formula.

==================================================
COMMITMENT INTEGRITY
==================================================

Sleduj, jak moc měním svůj plán poté, co jsem se k němu zavázal.

Například:

ORIGINAL PLAN
24 commitments

CURRENT PLAN
20 commitments

REMOVED
4

MOVED
3

COMMITMENT INTEGRITY
78%

Výpočet navrhni rozumně.

==================================================
FOCUS MODE
==================================================

Task může mít:

START FOCUS

Po spuštění se zobrazí minimalistický timer.

Například:

59:32

CLAUDE WORK

[ PAUSE ]
[ FINISH ]

Pause musí fungovat.

Sleduj:

- planned time
- total elapsed time
- active focus time
- pause time
- number of pauses

Například:

Planned:
60 min

Focused:
48 min

Paused:
12 min

Task lze dokončit manuálně nebo po skončení timeru.

==================================================
PROOF MODE
==================================================

Task může mít:

[ ] Require proof

Pokud zapnuto, před označením DONE musím přidat:

PHOTO

nebo

SHORT COMPLETION NOTE

Například:

Gym:
photo

Reading:
"Pages 120–165"

Claude:
"Finished auth flow."

Proof data ukládej lokálně.

==================================================
PENALTY SYSTEM
==================================================

Chci penalty systém.

Například:

Late:
-10 až -30 % task value podle zpoždění

Missed:
0 points

Removed after commitment:
0 points a commitment violation

Repeated failure:
negative Accountability impact

Critical missed:
větší Accountability penalty

Penalty systém ale nesmí být nastaven tak, že jeden task kompletně zničí měsíc.

==================================================
COMEBACK SYSTEM
==================================================

Chci silný comeback mechanic.

Pokud měl předchozí den například Productivity Score pod 60 %:

ráno zobraz:

YESTERDAY
43%

TODAY
COMEBACK DAY

Text:

"Včerejšek nezměníš. Dnešek ano."

Nabídni:

CREATE RECOVERY TASK

Recovery task je task navíc oproti původnímu plánu.

Například:

45 min Claude
30 min study
20 pages professional reading

Recovery task může přidat bonus k Productivity nebo Accountability Score.

Nesmí ale vymazat původní selhání.

Historie stále ukazuje missed task.

==================================================
REALITY CHECK
==================================================

Každý večer chci Reality Check.

Výchozí čas například 21:30, ale musí být nastavitelný.

Obrazovka:

REALITY CHECK

You promised:
6

Completed:
4

Promises Kept Today:
67%

Remaining:
2

Text může být například:

"Je 67 % výkon, který odpovídá tomu, kam se chceš dostat?"

Tlačítka:

FIX IT

END THE DAY

FIX IT:
ukáže tasky, které ještě lze dokončit.

END THE DAY:
všechny nesplněné tasky projdou No Excuses flow.

==================================================
MORNING BRIEF
==================================================

Každé ráno zobraz krátký briefing.

Například:

TODAY

5 commitments

3 high priority

2 deadlines

Critical focus:
Claude Work

Promises Kept this week:
88%

Current streak:
4 days

Podle historie zobraz krátkou větu.

Například:

"Včera 100 %. Dnes to zopakuj."

nebo:

"Včera 46 %. Dnes nemáš co dohánět řečmi. Začni pracovat."

==================================================
WEEKLY REVIEW
==================================================

Weekly Review musí být jedna z nejlepších částí aplikace.

Chci moderní, grafický, interaktivní review.

Použij cards, Charts framework a jemné animace.

Například:

WEEK 41

PROMISES KEPT
84%

PRODUCTIVITY
78%

ACCOUNTABILITY
81

VS LAST WEEK
+6%

Dále:

TOTAL COMMITMENTS
25

COMPLETED
21

MISSED
4

ON TIME
18

LATE
3

Dále graf podle dnů:

MON 91
TUE 84
WED 65
THU 90
FRI 72
SAT 100
SUN 88

Dále:

BEST CATEGORY

Self Development
92%

WORST CATEGORY

Work
61%

MOST FAILED TASK

Claude Work

3 failures

Dále:

YOUR EXCUSES

Procrastination: 4
No time: 2
Forgot: 1

Dále:

PATTERNS DETECTED

Například:

"You completed 100% of sport commitments but only 64% of professional-development commitments."

"You are significantly less productive after 19:00."

"Your most common failure reason was procrastination."

"You reduced your Weekly Commitment twice."

Dále:

SELF-CRITIQUE REVIEW

Zobraz části textů, které jsem během týdne sám napsal.

Například:

Tuesday:
"I wasted an hour scrolling instead of starting."

Friday:
"I postponed it because the task felt difficult."

A summary:

"You identified procrastination as the problem multiple times, but repeated the same behaviour."

==================================================
WEEKLY PLANNING ASSISTANT
==================================================

Při plánování nového týdne pracuj s minulými daty.

Například:

Last 4 weeks average:
17.5 completed commitments.

Pokud si naplánuji 35:

"Your plan is 100% larger than your recent completion average. Are you sure this is realistic?"

Nezakazuj mi plán potvrdit.

Pouze upozorni.

Další insight například:

"Your last three Tuesdays had below-average productivity. Consider scheduling critical tasks earlier."

==================================================
STREAKS
==================================================

Sleduj:

- Daily 80%+ streak
- Weekly 80%+ streak
- Perfect Day streak
- Perfect Week streak
- Self Development streak
- Work streak
- Promises Kept streak

Například:

5 WEEKS
80%+ PROMISES KEPT

==================================================
PERSONAL RECORDS
==================================================

Sleduj:

- Best Productivity Day
- Best Productivity Week
- Best Promises Kept Week
- Best Promises Kept Month
- Longest Daily Streak
- Longest Weekly Streak
- Most Focus Hours
- Most productive month
- Most tasks completed
- Longest Perfect Streak

==================================================
WHY DOES THIS MATTER
==================================================

Při vytváření důležitého tasku můžu vyplnit:

WHY DOES THIS MATTER?

Například:

"Chci se během 6 měsíců naučit stavět vlastní aplikace."

Pokud task později ignoruji, notifikace může použít moji vlastní motivaci.

Například:

"Říkal jsi, že se chceš naučit stavět aplikace. Dnes jsi zase neudělal ani hodinu práce."

Toto považuji za důležitou funkci.

==================================================
EXCUSE COUNTER
==================================================

Chci sledovat, jak často používám jednotlivé výmluvy.

Například:

"No time"
17x in last 90 days

"Procrastination"
22x

"Didn't feel like it"
9x

Aplikace může zobrazit:

"You selected 'No time' 17 times in the last 90 days."

A pokud se opakuje zejména u jedné kategorie:

"12 of these were Work or Self Development tasks."

==================================================
PLANNED VS ACTUAL EFFORT
==================================================

Sleduj:

Planned effort

vs.

Actual effort

Například:

PLANNED THIS WEEK
18 h 00 min

ACTUAL FOCUSED
11 h 42 min

Completion:
65%

Graficky zobraz trend.

==================================================
INTERPRETACE AKTIVITY VS PRODUKTIVITY
==================================================

Aplikace musí rozlišovat mezi:

BEING BUSY

a

BEING PRODUCTIVE.

Pokud splním mnoho low-value tasků, ale selžu na Critical tasks, aplikace to má poznat.

Například:

Task Completion:
75%

Productivity:
39%

Critical Tasks:
0 / 2

Text:

"You were busy. You weren't productive."

==================================================
DASHBOARD
==================================================

Stats screen musí zobrazit:

Today
Week
Month

Promises Kept
Productivity
Accountability
Commitment Integrity

Completed
Missed
Late
Skipped

Focus Hours

Planned vs Actual Time

Category performance

Failure reasons

Excuse counter

Streaks

Personal records

Trends over 7 / 30 / 90 days

==================================================
NAVIGATION
==================================================

Bottom tab bar:

TODAY
WEEK
STATS
SETTINGS

TODAY

- current tasks
- morning brief
- Reality Check
- current scores

WEEK

- Weekly Commitment
- weekly calendar
- committed tasks
- edits
- original vs current plan

STATS

- charts
- patterns
- scores
- records
- review history

SETTINGS

- Notification Tone
- Normal / Strict / Savage
- reminder settings
- Weekly Planning reminder
- Reality Check time
- Morning Brief
- notification frequency
- deadline defaults
- category weights
- proof settings

==================================================
DESIGN
==================================================

Chci minimalistický premium design.

Inspirace:

- Apple Fitness
- Apple Health
- WHOOP
- Things 3
- Linear
- moderní fintech apps

Vizuálně:

- dark mode jako hlavní vzhled
- velmi tmavé pozadí
- velká čísla
- čisté cards
- SF Symbols
- minimum vizuálního chaosu
- moderní typografie
- jednoduché animace
- jasná hierarchie
- ovládání jednou rukou

Nechci:

- infantilní habit tracker
- roztomilé maskoty
- childish gamification
- přehnané emoji
- přehnané confetti

Aplikace má působit:

serious
premium
disciplined
performance-oriented
minimal

==================================================
DATA MODEL
==================================================

Navrhni kompletní SwiftData model.

Minimálně budu pravděpodobně potřebovat entity podobné:

Task
WeeklyPlan
WeeklyCommitmentSnapshot
TaskCompletion
FailureRecord
FocusSession
DailyProductivity
WeeklyReview
ProofRecord
RecoveryTask
UserSettings
NotificationHistory

Pokud navrhneš lepší strukturu, použij ji.

Model musí podporovat dlouhodobou historii a analytiku.

==================================================
ARCHITEKTURA
==================================================

Použij jednoduchou a čistou SwiftUI architekturu.

Nechci overengineering.

Rozděl projekt například:

Models
Views
ViewModels
Services
Components
Utilities

Vytvoř služby například:

NotificationManager
ProductivityEngine
AccountabilityEngine
StatisticsService
PatternDetectionService
FocusTimerService

Pokud je nějaká služba zbytečná, zjednoduš to.

==================================================
NOTIFICATION TECHNICAL REQUIREMENTS
==================================================

Použij UserNotifications.

Musí fungovat lokální notifications.

Navrhni systém pro:

- Sunday planning reminders
- task reminders
- deadline reminders
- overdue reminders
- Reality Check
- Morning Brief
- escalating reminders

Respektuj reálná technická omezení iOS.

Pokud iOS nedovoluje určité chování přesně tak, jak je navrženo, vysvětli omezení a navrhni nejlepší reálně funkční variantu.

Nikdy nepředstírej, že iOS umí něco, co neumí.

==================================================
IMPLEMENTATION STRATEGY
==================================================

Nechci, abys okamžitě vypsal tisíce řádků kódu bez struktury.

Nejdříve udělej:

1. Architecture proposal
2. SwiftData schema
3. Screen map
4. Navigation structure
5. Productivity algorithm
6. Promises Kept algorithm
7. Accountability algorithm
8. Commitment Integrity algorithm
9. Notification architecture
10. Failure-memory architecture
11. MVP implementation plan

Potom implementuj aplikaci po jednotlivých funkčních fázích.

PHASE 1

- base Xcode project
- SwiftData
- Weekly Commitment
- task creation
- Today screen
- completion
- No Excuses flow
- Promises Kept
- basic Productivity Score

PHASE 2

- local notifications
- Sunday hourly planning reminders
- deadline notifications
- escalating notifications
- Notification Tone
- Savage mode
- Morning Brief
- Reality Check

PHASE 3

- Weekly Review
- Charts
- Failure Memory
- Pattern Detection
- Excuse Counter
- streaks
- Stats screen

PHASE 4

- Focus Timer
- Pause / Resume
- Proof Mode
- Recovery Tasks
- Planned vs Actual
- Commitment Integrity
- Personal Records

PHASE 5

- advanced insights
- personalization
- UI polish
- animations
- UX improvements
- bug fixing

Po každé fázi musí projekt:

- compile
- run
- retain data after app restart
- work on a physical iPhone
- not contain fake placeholder functionality

==================================================
JAK MI MÁŠ DÁVAT KÓD
==================================================

Po každém implementačním kroku mi napiš:

1. Jaké soubory vytvořit.
2. Do jaké složky je dát.
3. Kompletní obsah každého souboru.
4. Co přesně udělat v Xcode.
5. Jak aplikaci buildnout.
6. Jak danou funkci otestovat.
7. Jaký výsledek mám očekávat.
8. Jak řešit nejpravděpodobnější chyby.

Pokud nahrazuješ existující soubor, vždy mi napiš kompletní nový obsah souboru, ne jen diff.

Nechci části kódu typu:

"...existing code..."

Chci copy-paste ready soubory.

==================================================
CODE QUALITY
==================================================

Používej:

- moderní Swift
- SwiftUI best practices
- čisté názvy
- jednoduchý kód
- reusable components tam, kde dávají smysl
- dependency injection pouze tam, kde je přínosná
- bezpečné SwiftData operace
- správnou práci s dates/time zones
- správnou práci s notification permissions

Vyhni se:

- zbytečnému overengineeringu
- obrovským View souborům
- magic numbers
- duplicitní logice
- deprecated APIs
- komplikované abstrakci bez přínosu

==================================================
DŮLEŽITÉ PRODUKTOVÉ PRAVIDLO
==================================================

Pokud při návrhu zjistíš, že některou funkci lze udělat lépe, můžeš ji vylepšit.

Ale nesmíš změnit hlavní filozofii:

Aplikace má porovnávat:

CO JSEM ŘEKL, ŽE UDĚLÁM

vs.

CO JSEM SKUTEČNĚ UDĚLAL

A má mě tvrdě konfrontovat s rozdílem mezi těmito dvěma věcmi.

Neoptimalizuj aplikaci primárně na pocit odměny.

Optimalizuj ji na:

- accountability
- consistency
- discipline
- honest feedback
- long-term improvement
- high-value work

==================================================
PRVNÍ ODPOVĚĎ
==================================================

V první odpovědi mi ještě NEPIŠ celý kód aplikace.

Nejdříve vytvoř velmi konkrétní technický a produktový blueprint obsahující:

1. doporučený deployment target
2. strukturu Xcode projektu
3. kompletní seznam SwiftData entities a jejich properties
4. relationship mezi entities
5. všechny hlavní obrazovky
6. navigation flow
7. přesnou formula Productivity Score
8. přesnou formula Promises Kept
9. přesnou formula Accountability Score
10. přesnou formula Commitment Integrity
11. Notification architecture
12. Sunday planning reminder logic
13. Escalation logic
14. Failure Memory logic
15. Pattern Detection logic
16. Weekly Review structure
17. MVP scope
18. rozdělení implementace do fází
19. možné technické limity iOS
20. seznam konkrétních Swift souborů, které následně vytvoříme

Na úplném konci první odpovědi mi napiš:

"PHASE 1 READY"

a potom se mnou začni implementovat Phase 1 krok za krokem.

---

## 2. Design Prompt

DESIGN SYSTEM

Chci, aby aplikace měla velmi výrazný, minimalistický a prémiový dark-mode design.

Nemá působit jako klasický habit tracker, wellness aplikace nebo roztomilá gamifikovaná productivity app.

Má působit spíš jako:

- performance dashboard
- osobní accountability cockpit
- moderní fintech aplikace
- high-performance operating system

Inspirace:

- Apple Fitness
- Apple Health
- WHOOP
- Linear
- Things 3
- moderní trading / fintech dashboardy

==================================================
COLOR PALETTE
==================================================

Hlavní background:

- téměř černá
- například #0A0A0A nebo podobná velmi tmavá barva

Cards:

- lehce světlejší černá / tmavě šedá
- například #111111 až #181818

Primary text:

- čistá nebo téměř čistá bílá

Secondary text:

- neutrální šedá

Accent colors mají mít jasný význam a nemají se používat pouze dekorativně.

GREEN:
- completed task
- positive trend
- comeback success
- good streak
- improvement
- strong performance

ORANGE:
- warning
- approaching deadline
- active task
- task in progress
- medium risk
- attention required
- "ještě máš čas to napravit"

RED:
- missed task
- overdue task
- critical failure
- commitment violation
- major productivity problem
- repeated failure

Chci, aby hlavní kombinace byla:

BLACK
WHITE
GREEN
ORANGE
RED

Nepoužívej mnoho dalších barev.

==================================================
VISUAL PRINCIPLE
==================================================

Barvy mají signalizovat stav.

Nechci barevné UI jen proto, aby vypadalo zajímavě.

Stavy:

NEUTRAL
white / grey

ACTIVE
orange

COMPLETED
green

OVERDUE
red

FAILED
dark red / red

Pokud je task overdue, nebarvi automaticky celou card jasně červeně.

Preferuji prémiovější řešení například:

- red left border
- red deadline
- small OVERDUE badge
- subtle red glow
- dark red background tint

==================================================
HOME / TODAY SCREEN
==================================================

Today Screen má působit jako performance dashboard.

Nahoře:

TODAY
date

Pod tím dominantní hlavní score.

Například:

81
ACCOUNTABILITY

Číslo musí být velké a vizuálně dominantní.

Pod ním tři menší metrics:

86%
PROMISES KEPT

74%
PRODUCTIVITY

4
DAY STREAK

Poté seznam dnešních tasků.

Critical tasks zobraz samostatně a vizuálně výrazněji.

Například:

CRITICAL

CLAUDE WORK

Self Development
60 min
Deadline 18:00

[ START FOCUS ]

==================================================
TASK CARDS
==================================================

Task cards mají být jednoduché.

Každá card má zobrazovat pouze důležité informace:

- title
- category
- priority
- duration
- deadline pokud existuje
- current status

Používej malé badges například:

CRITICAL
HIGH
OVERDUE
FOCUS
PROOF REQUIRED

Task cards nemají být přeplácané.

Completed task:

- subtle green accent
- checkmark
- lehce utlumený text

Active task:

- orange accent

Overdue task:

- red accent
- OVERDUE + čas zpoždění

Například:

OVERDUE 42 MIN

==================================================
TYPOGRAPHY
==================================================

Používej primárně nativní Apple typography / SF Pro.

Design má stát na velké typografii a whitespace.

Velká hlavní čísla:

48–72 pt
Bold / Heavy

Section headings:

20–28 pt

Task titles:

17–19 pt
Semibold

Secondary metadata:

12–14 pt

Status labels mohou být uppercase:

CRITICAL
OVERDUE
FAILED
COMEBACK DAY

Nepoužívej uppercase úplně všude.

==================================================
PROGRESS VISUALIZATION
==================================================

Preferuji jednoduché horizontální nebo vertikální performance bars před generickými kruhovými progress indicators.

Například:

PROMISES KEPT
████████████████░░░ 84%

PRODUCTIVITY
██████████████░░░░░ 72%

COMMITMENT INTEGRITY
█████████████████░░ 89%

Bars mají být tenké, čisté a minimalistické.

==================================================
WEEKLY REVIEW DESIGN
==================================================

Weekly Review má být vizuálně velmi silná část aplikace.

Má působit jako osobní performance report.

Úvod:

WEEK 41

84%
PROMISES KEPT

+6%
VS LAST WEEK

Pod tím jednotlivé cards:

TOTAL COMMITMENTS
25

COMPLETED
21

MISSED
4

ON TIME
18

LATE
3

Dále graf produktivity po dnech.

Použij Apple Charts.

Pak například:

BEST DAY
Thursday
94%

WORST DAY
Tuesday
41%

MOST FAILED TASK
Claude Work
3× missed

TOP EXCUSE
Procrastination
4×

==================================================
THE TRUTH SECTION
==================================================

Weekly Review má obsahovat výraznou sekci:

THE TRUTH

Tato část má vizuálně oddělit nejdůležitější insight týdne.

Například:

"You completed 100% of your sport commitments."

"You completed only 58% of your high-value work."

Pod tím výrazný verdict:

"You were active. You weren't productive."

Tento verdict může být podle výsledku:

green
orange
red

Sekce má být jednoduchá, dramatická a velmi čitelná.

==================================================
SAVAGE MODE VISUAL FEEDBACK
==================================================

Savage mode nemá měnit pouze text notifikací.

Může ovlivnit i vizuální stav aplikace.

Pokud například:

Productivity < 50%

nebo

Critical tasks = 0 / 2

nebo

existuje více overdue Critical tasks

aplikace může přejít do výraznějšího failure state.

Například:

- subtle dark red gradient v horní části
- red score accents
- red status line
- stronger warning typography

Headline:

TODAY IS SLIPPING

nebo

CRITICAL TASKS
0 / 2

Nechci agresivní blikající UI.

Má to stále působit prémiově.

==================================================
COMEBACK DAY
==================================================

Comeback Day může používat oranžovou jako hlavní accent.

Například:

COMEBACK DAY

Yesterday
43%

Today
0%

Text:

"Yesterday is done. Today isn't."

CTA:

START COMEBACK

Pokud se comeback podaří, orange se může postupně změnit na green.

==================================================
ANIMATIONS
==================================================

Animace mají být jemné a funkční.

Completed task:

- checkmark animation
- subtle green pulse
- score update animation

Critical failure:

- subtle red border pulse
- Accountability score se animovaně sníží

Weekly Review:

- charts animate in
- statistics reveal gradually
- scores count up

Nepoužívej:

- confetti
- cartoon animations
- excessive bouncing
- childish celebration effects

==================================================
SPACING AND LAYOUT
==================================================

Používej hodně whitespace.

Cards:

- rounded corners, ale ne příliš výrazné
- subtle borders
- dark surfaces
- minimum shadows

Preferuji větší vertical spacing a jasnou hierarchii.

UI musí být pohodlně ovladatelné jednou rukou.

Důležité CTA buttons dávej do spodní části obrazovky, pokud to dává smysl.

==================================================
BUTTONS
==================================================

Primary action:

solid white nebo context-specific accent

Například:

START FOCUS
white button / black text

Danger / failure action:

red accent

Secondary action:

dark card with subtle border

Buttons mají působit robustně a jednoduše.

==================================================
NAVIGATION
==================================================

Bottom navigation:

TODAY
WEEK
STATS
SETTINGS

Používej SF Symbols.

Active tab:

white

Inactive tab:

grey

Nepoužívej barevné tab icons podle kategorií.

==================================================
ICONS
==================================================

Používej primárně SF Symbols.

Ikony pouze tam, kde zvyšují čitelnost.

Nechci ikonou označovat každý řádek.

Minimalismus je důležitější než dekorace.

==================================================
DESIGN PERSONALITY
==================================================

Aplikace má působit:

serious
premium
disciplined
dark
minimal
high-performance
direct
masculine
clean

Nemá působit:

cute
playful
childish
wellness-like
overly motivational

Cílem designu je vytvořit pocit:

"Tohle není seznam úkolů. Tohle je moje osobní performance dashboard."

==================================================
DŮLEŽITÉ UX PRAVIDLO
==================================================

Nechci, aby aplikace byla vizuálně negativní pořád.

Červená má mít sílu právě proto, že se používá pouze při problému.

Normální stav má být převážně:

black
white
grey

Green, orange a red se mají objevovat pouze tam, kde mají význam.

Tak bude failure state působit mnohem silněji.

Při návrhu všech obrazovek se drž tohoto design systému konzistentně.
