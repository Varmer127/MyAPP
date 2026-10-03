# Kept — technický a produktový blueprint

Pracovní název aplikace je **Kept** (podle PROMISES KEPT). Dá se kdykoli změnit v nastavení targetu.

Filozofie: aplikace porovnává **co jsem řekl, že udělám** s tím, **co jsem skutečně udělal**. Skóre se nikdy neukládají, vždy se počítají z historie tasků, takže je nejde „upravit“ jinak než reálnou prací.

## 1. Deployment target

- iOS 18.0, jen iPhone, jen na výšku, vynucený dark mode.
- Swift 5 language mode, SwiftUI + SwiftData + Charts + UserNotifications + PhotosUI. Žádné externí závislosti.
- Bundle ID `cz.philipstryka.kept`, automatické podepisování.

## 2. Struktura Xcode projektu

```
Kept.xcodeproj
Kept/
  KeptApp.swift
  Models/        SwiftData entity + enumy
  Services/      ScoreEngine, PlanService (+ NotificationManager, PatternDetection, FocusTimer v dalších fázích)
  Utilities/     DateHelpers
  Design/        Theme
  Components/    TaskCard, MetricTile, PerformanceBar, Badge, button styles
  Views/         Today, Week, Tasks, NoExcuses, Stats, Settings
  Assets.xcassets
```

Projekt používá synchronizované složky: každý soubor přidaný do `Kept/` je automaticky součástí targetu.

Složku `ViewModels` vynechávám. Obrazovky čtou data přes `@Query` a logika je ve službách; view modely by byly jen mezivrstva bez přínosu.

## 3. SwiftData entity

**TaskItem** (název `Task` koliduje se Swift concurrency)

| Property | Typ | Význam |
|---|---|---|
| uid | UUID | stabilní identita (snapshot, log změn) |
| title, notes, why | String | `why` = „Why does this matter?“ |
| categoryRaw, priorityRaw | String | enumy uložené jako raw value |
| weight | Int 1–5 | body tasku |
| plannedMinutes | Int | plánovaná délka |
| scheduledDate | Date | aktuální den (začátek dne) |
| deadline | Date? | nil = do konce dne |
| requiresProof, usesFocus | Bool | Phase 4 |
| statusRaw | String | pending / completed / completedLate / skipped / failed |
| completedAt, createdAt | Date | |
| isCommitted | Bool | byl součástí původního commitmentu |
| originalDate, originalWeight, originalPriorityRaw | | zmrazeno při I COMMIT |
| editedAfterCommitment, moveCount | | stopa změn |
| isRemoved, removedAt | | soft delete, committed task nikdy nezmizí |
| isRecovery | Bool | recovery task (Phase 4) |

**WeeklyPlan**: `weekStart` (pondělí 00:00), `committedAt`, `snapshotData` (JSON `[TaskSnapshot]`, kompletní originální plán).

**CommitmentEdit**: `date`, `kind` (removed, moved, priorityLowered/Raised, deadlineChanged, weightLowered/Raised, addedLater), `taskUID`, `taskTitle`, `detail` („Wed 7 → Fri 9“).

**FailureRecord**: `date`, `kind` (skipped / missed), `reason`, `critique`, `prevention` + kopie `taskTitle`, `category`, `priority`, `taskDate` pro analytiku.

**UserSettings** (jeden řádek): váhy kategorií; ve Phase 2 přibude tón, časy Morning Brief / Reality Check, frekvence reminderů.

Další fáze přidají: **FocusSession**, **ProofRecord**, **NotificationLog**, **WeeklyReview** (uložený výsledek a texty review). SwiftData zvládne přidání entit a properties s výchozí hodnotou lehkou migrací bez ztráty dat.

Oproti zadání vynechávám `DailyProductivity`, `TaskCompletion` a `RecoveryTask` jako samostatné entity: denní skóre se počítá z tasků, dokončení je stav tasku a recovery task je task s příznakem. Méně míst, kde se data můžou rozejít.

## 4. Vztahy

- WeeklyPlan 1—N TaskItem (cascade)
- WeeklyPlan 1—N CommitmentEdit (cascade)
- TaskItem 1—N FailureRecord (cascade)
- později TaskItem 1—N FocusSession, TaskItem 1—1 ProofRecord

## 5. Obrazovky

- **Today**: hero Accountability, Promises Kept / Productivity / Day streak, sekce Unresolved, Critical, Tasks, Closed. Později Morning Brief, Comeback Day, Reality Check.
- **Task editor** (sheet)
- **No Excuses** (full screen, 3 kroky)
- **Week**: tento / příští týden, dny, stav commitmentu, original vs current plan, log změn
- **Commit summary** (sheet s I COMMIT)
- **Stats**: Today / Week / Month, později grafy, patterns, rekordy, historie review
- **Settings**
- později **Focus timer**, **Proof**, **Weekly Review**, **Reality Check**

## 6. Navigace

Tab bar TODAY / WEEK / STATS / SETTINGS. Vše ostatní jsou sheety nebo full-screen covery nad tabem, žádné hluboké stacky. Notifikace později otevírají konkrétní flow (plánování týdne, Reality Check, task).

## 7. Productivity Score

```
váha tasku   = zaokrouhlit(body priority × násobič kategorie), omezeno na 1–5
body         = Low 1, Medium 2, High 4, Critical 5
násobiče     = Self Dev 1.0, Work 1.0, School 0.9, Reading 0.75, Admin 0.5, Sport 0.5, Other 0.4

faktor       = včas 1.0 | pozdě do 1 h 0.9 | pozdě do 24 h 0.8 | později 0.7 | skip / fail / removed 0

základ       = Σ(váha × faktor) + 0.5 × Σ(váha splněných recovery tasků)
               ----------------------------------------------------------   (max 100 %)
                              Σ(váha všech ne-recovery tasků)

Productivity = základ × (1 − 0.10 × ztracené Critical / všechny Critical)
```

Příklad ze zadání: Gym, Walk, Shopping, Cleaning splněno (váhy 2+1+1+1), Claude a Study (Critical, 5+5) ne → 5/15 = 33 % × 0.9 = **30 %**, přestože completion je 67 %.

U committed tasku se počítá `max(aktuální váha, původní váha)`, snížením váhy si selhání nezlevníš.

## 8. Promises Kept

```
Promises Kept = splněné committed tasky (včas i pozdě) / všechny committed tasky s uzavřeným výsledkem
```

- Odstraněný task zůstává ve jmenovateli jako nesplněný.
- Přesunutý task je pořád původní závazek.
- Task přidaný po commitmentu není slib: počítá se do Productivity, ne sem.
- „Uzavřený“ = splněný, skipnutý, failnutý, odstraněný, nebo jeho den skončil.

## 9. Accountability Score (0–100, klouzavých 30 dní)

```
základ = 45 % Promises Kept + 25 % Productivity + 15 % Commitment Integrity + 15 % On-time rate
         (chybějící složka se vynechá a zbytek se přeškáluje)

srážky = nevysvětlená selhání  1 b / ks, max 10
       + ztracené Critical     2 b / ks, max 10
       + opakované selhání     2 b za každý task se 3+ selháními, max 6

bonus  = splněné recovery tasky 1 b / ks, max 5
       + day streak             0.5 b / den, max 5

Accountability = omezit(základ − srážky + bonus, 0, 100)
```

Stropy srážek zajišťují, že jeden task nezničí měsíc. Podtitulek pod skóre se generuje z toho, co ho nejvíc táhne dolů.

## 10. Commitment Integrity

```
penalizace tasku = min(1, součet za druhy změn)
   removed 1.0 | moved 0.5 | priority lowered 0.5 | deadline changed 0.25 | weight lowered 0.25
   zvýšení priority / váhy a přidání tasku = 0

Integrity = 1 − Σ penalizací / počet původních commitmentů
```

Příklad ze zadání: 24 původních, 4 odstraněné, 3 přesunuté → 1 − 5.5/24 = **77 %**.

## 11. Architektura notifikací (Phase 2)

Jeden `NotificationManager`. Protože iOS nenechá aplikaci běžet na pozadí, nic se nerozhoduje „živě“: při každé změně dat (uložení tasku, DONE, commit, otevření aplikace) se **všechny naplánované notifikace přepočítají a naplánují znovu**. Identifikátory mají tvar `typ.uidTasku.level`, takže jdou cíleně rušit.

Typy: příprava (30 min předem), start, deadline, overdue eskalace, Morning Brief, Reality Check, nedělní plánování.

## 12. Nedělní plánování

Každou neděli 10:00–21:00 po hodině, 12 notifikací s postupně ostřejším textem podle tónu. Plánují se dopředu vždy na nejbližší neděli. Po stisku I COMMIT pro příští týden se všechny zbývající zruší.

## 13. Eskalace

Pro každý otevřený task se předem naplánuje řada: Level 0 (−30 min), 1 (start), 2 (+15 min), 3 (+45 min), 4 (+90 min a dál). Skutečný level textu = základní level posunutý podle:

- tónu (Normal max 2, Strict max 3, Savage max 4)
- priority (Critical +1)
- počtu nedávných selhání stejného tasku (3+ → +1)
- aktuálních skóre (Promises Kept pod 60 % → +1)

Texty: 100+ šablon rozdělených podle tónu a levelu, s proměnnými `{task}`, `{čas}`, `{why}`, `{počet selhání}`. Savage míří jen na chování, ne na vzhled, zdraví nebo sebepoškozování. DONE / SKIP zruší zbytek řady.

## 14. Failure Memory

Zdroj pravdy jsou `FailureRecord` + stavy tasků + `CommitmentEdit`. Tasky se párují podle normalizovaného názvu (malá písmena, bez mezer na krajích), takže „Claude Work“ v úterý a ve čtvrtek je tentýž opakovaný závazek. No Excuses už teď při dalším selhání ukáže tvou minulou výmluvu a slib.

## 15. Pattern Detection (Phase 3)

`PatternDetectionService` počítá nad historií:

- selhání podle tasku („4 z posledních 6“), kategorie, dne v týdnu, hodiny, priority
- nejčastější důvody a jejich koncentrace v high-value kategoriích
- počet přesunů, snížení commitmentu, pozdních dokončení
- kontrast sport vs. profesní rozvoj, busy vs. productive

Vzorec se zobrazí, jen když má dost dat (min. 3 výskyty) a překročí práh, aby aplikace netvrdila věci z jednoho případu.

## 16. Weekly Review (Phase 3)

Hlavička (Week N, Promises Kept, vs last week) → karty (total, completed, missed, on time, late) → graf po dnech (Charts) → best / worst day a kategorie → most failed task → Your Excuses → Patterns Detected → Self-critique review (tvoje vlastní texty) → **THE TRUTH** s verdiktem v zelené / oranžové / červené.

## 17. MVP scope (Phase 1)

Xcode projekt, SwiftData, Weekly Commitment se snapshotem a logem změn, tvorba a editace tasků, Today, DONE / SKIP, No Excuses flow, nevyřešené minulé tasky, všechny čtyři metriky, základní Stats, váhy kategorií v Settings.

## 18. Fáze

1. základ (viz bod 17)
2. notifikace, tóny, Savage, eskalace, Morning Brief, Reality Check
3. Weekly Review, Charts, Failure Memory, Pattern Detection, Excuse Counter, streaky, plné Stats
4. Focus timer, Proof mode, Recovery tasky a Comeback Day, Planned vs Actual, Personal Records
5. pokročilé insighty, Weekly Planning Assistant, Savage vizuální stav, animace, ikona, polish

## 19. Limity iOS

- **Max 64 čekajících lokálních notifikací** na aplikaci. Eskalace se proto plánují jen pro nejbližší tasky (dnešek a zítřek) a doplňují se při každém otevření.
- **Aplikace na pozadí neběží.** Nejde „zjistit, že je task pořád nehotový, a poslat ostřejší zprávu“. Řešení: eskalační řada je naplánovaná předem a DONE ji zruší. Když aplikaci neotevřeš, notifikace přijdou podle posledního známého stavu.
- **Nejde spolehlivě poznat ignorovanou notifikaci.** Odhad: notifikace byla doručena a task zůstal otevřený.
- **Focus / Nerušit notifikace ztlumí.** Time Sensitive úroveň je prorazí, ale vyžaduje capability v projektu; Critical Alerts vyžadují schválení Applem a nejsou dostupné.
- **Podpis zdarma (osobní Apple ID) platí 7 dní.** Potom se aplikace nespustí, dokud ji z Xcode nenainstaluješ znovu; data zůstanou. S placeným Apple Developer účtem (99 USD / rok) je to 1 rok.
- **Focus timer na pozadí neodpočítává kódem**, čas se dopočítá z uložených časových razítek a konec ohlásí naplánovaná notifikace.
- Časová pásma: den tasku je uložený jako půlnoc v pásmu zařízení. Při cestování přes pásma se může task posunout o den.

## 20. Soubory

Phase 1 (existují):

```
KeptApp.swift
Models/      Enums, TaskItem, WeeklyPlan (+ TaskSnapshot, CommitmentEdit), FailureRecord, UserSettings
Services/    ScoreEngine, PlanService
Utilities/   DateHelpers
Design/      Theme
Components/  Components, TaskCard
Views/       RootView, Today/TodayView, Tasks/TaskEditorView, NoExcuses/NoExcusesView,
             Week/WeekView, Week/CommitSummaryView, Stats/StatsView, Settings/SettingsView
```

Další fáze: `NotificationManager`, `NotificationTemplates`, `MorningBriefView`, `RealityCheckView`, `PatternDetectionService`, `StatisticsService`, `WeeklyReviewView`, `FocusTimerService`, `FocusView`, `ProofView`, `FocusSession`, `ProofRecord`, `NotificationLog`, `WeeklyReview`.

PHASE 1 READY
