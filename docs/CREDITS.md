# Zdroje třetích stran

## Fotky cviků

Fotky cviků v knihovně (`Kept/Resources/ExercisePhotos`, 2 fotky na cvik: začátek a konec pohybu) pocházejí
z projektu **free-exercise-db** (https://github.com/yuhonas/free-exercise-db), který je uvolněný jako volné dílo
pod licencí The Unlicense. Použití i v placené aplikaci je povolené bez dalších podmínek.

- Staženo 10. 11. 2026, zmenšeno na 520 px (JPEG kvalita 55).
- Název souboru `ex-<id>-<0|1>.jpg`, kde `<id>` je identifikátor cviku v databázi (pole `photo` v `ExerciseCatalog`).
- České názvy, svaly, tipy a technika (`ExerciseTechnique*.swift`) jsou napsané pro Kept, z databáze se nepřebírají.
- V detailu cviku je uvedeno „Fotky: free-exercise-db, volné dílo.“ Licence to nevyžaduje, ale je to slušnost.
- Anglické názvy cviků pro hledání (`ExerciseCatalog+English.swift`) pocházejí ze stejné databáze.
- Licence ověřena 11. 11. 2026: repozitář uvádí The Unlicense (volné dílo). Původ jednotlivých fotek se opírá o prohlášení zdroje.

## Ikona a logo

Ikona aplikace a logo (`Assets.xcassets`) navrhl Claude (AI od Anthropicu) na Philipův pokyn: bílá fajfka nad zelenou linkou, stejný tvar kreslí kód úvodní animace. Žádná převzatá grafika, výstupy patří Philipovi (potvrzeno 11. 11. 2026, viz `docs/LEGAL.md`).

## Písma, symboly a zvuky

- Písmo je systémové (San Francisco), žádné vlastní písmo v aplikaci není.
- Ikony jsou SF Symbols od Applu; smějí se používat v aplikacích pro zařízení Apple, ne v logu ani v ikoně aplikace.
- Aplikace neobsahuje žádné vlastní zvuky ani hudbu.

## Kód třetích stran

Aplikace neobsahuje žádnou cizí knihovnu. Návrhy v `docs/design/*.html` načítají ikony Tabler (licence MIT) z internetu; do aplikace se nedostanou.
