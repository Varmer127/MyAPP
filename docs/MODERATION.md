# Moderace: rychlá reakce na nahlášení

Cíl: na každé nahlášení reagovat do 24 hodin. Všechno se dělá v Supabase dashboardu (projekt Kept) → **SQL Editor**.

## 1. Co čeká
```sql
select * from public.moderation_queue();
```
Ukáže otevřená nahlášení: kdy, důvod, poznámku (u pošťouchnutí i jeho text), kdo nahlásil, koho, kolikrát už byl ten člověk nahlášen a jestli je pozastavený nebo má zákaz šťouchání.

## 2. Rozhodni
- **Neškodné / nedorozumění:** jen uzavři (krok 4).
- **Urážlivé pošťouchnutí:** zakaž šťouchání (krok 3a). Text je pro příjemce skrytý už od nahlášení.
- **Opakované nebo vážné (výhrůžky, sexuální obsah, vydávání se za jiného):** pozastav účet (krok 3b).
- **Něco nezákonného nebo ohrožení života:** pozastav účet a obrať se na Policii ČR (158). Nic nemaž, data jsou důkaz.

## 3. Zásah (místo `ID` vlož `reported_id` z fronty)
a) Zákaz šťouchání:
```sql
update public.profiles set poke_banned_at = now() where id = 'ID';
```
b) Pozastavení účtu (nic v sociální části pak nefunguje, data v telefonu zůstávají):
```sql
update public.profiles set suspended_at = now() where id = 'ID';
```
Zrušení zásahu: stejný příkaz s `null` místo `now()`.

## 4. Uzavři nahlášení (místo `REPORT` vlož `report_id`)
```sql
update public.reports set status = 'done' where id = 'REPORT';
```

## 5. Odpověz
Pokud nahlašující napsal na podporu, odpověz z adresy podpory: díky za nahlášení, situaci jsme vyřešili (bez podrobností o druhém člověku).

## Pravidla
- Nikdy neprozrazuj, kdo koho nahlásil.
- Uzavřená nahlášení se po roce smažou sama, otevřená ne.
- Smazaný účet zmizí i s nahlášeními na něj (`reported` se vynuluje).
