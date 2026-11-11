-- Kept: hardening after the security audit of 11 November 2026.
-- 1. New tables and sequences in "public" start closed for the app, so a forgotten "revoke" cannot open one.
-- 2. Rate limits hold when many requests arrive at the same moment.
-- 3. A name cannot carry a link or invisible characters (a stranger sees it in a friend request);
--    every other text people send each other loses invisible characters on the way in.

-- ---------------------------------------------------------------------------------------------
-- 1. Closed by default

alter default privileges for role postgres in schema public revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on sequences from anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- 2. Rate limits under parallel requests

create or replace function public.check_rate(p_user uuid, p_kind text, p_max int, p_window interval)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    -- One at a time per person and kind: requests sent together used to count the same rows and all pass.
    perform pg_advisory_xact_lock(hashtextextended(p_user::text || ':' || p_kind, 0));
    delete from public.rate_events where user_id = p_user and at < now() - interval '2 days';
    if (select count(*) from public.rate_events where user_id = p_user and kind = p_kind and at > now() - p_window) >= p_max then
        raise exception 'rate_limited' using errcode = '54000';
    end if;
    insert into public.rate_events (user_id, kind) values (p_user, p_kind);
end;
$$;

-- The same poke as before; the rate check now comes before the "once a minute" check, so two pokes
-- sent in the same instant wait for each other and the second one is refused.
create or replace function public.send_poke(p_to uuid, p_body text)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.active_user();
    v_body text := coalesce(btrim(p_body), '');
    v_sent timestamptz;
begin
    if exists (select 1 from public.profiles where id = v_uid and poke_banned_at is not null) then
        raise exception 'poke_banned' using errcode = '42501';
    end if;
    if p_to is null or p_to = v_uid or not public.are_friends(v_uid, p_to) then
        raise exception 'not_found' using errcode = 'P0002';
    end if;
    if char_length(v_body) > 100 then
        raise exception 'invalid_text' using errcode = '22023';
    end if;
    if public.has_link(v_body) then
        raise exception 'links_not_allowed' using errcode = '22023';
    end if;
    if public.is_dnd(p_to) then
        raise exception 'do_not_disturb' using errcode = '55000';
    end if;
    perform public.check_rate(v_uid, 'poke', 120, interval '1 hour');
    if exists (select 1 from public.pokes where sender = v_uid and recipient = p_to and created_at > now() - interval '1 minute') then
        raise exception 'too_soon' using errcode = '55000';
    end if;
    insert into public.pokes (sender, recipient, body) values (v_uid, p_to, v_body) returning created_at into v_sent;
    return v_sent;
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- 3. Texts

-- Characters nobody sees but that change what is shown: control characters (new lines included),
-- zero-width spaces and the marks that turn the direction of the text around. The joiner inside
-- emoji (family, flags) is left alone.
-- The pattern is put together from character numbers on purpose: the characters themselves are invisible,
-- and a copy of this file through a clipboard once turned them into something else.
create function public.hidden_characters_pattern()
returns text
language sql
immutable
set search_path = ''
as $$
    select '[' || chr(1) || '-' || chr(31) || chr(127) || '-' || chr(159) || chr(1564) || chr(8203) || chr(8204) || chr(8206) || chr(8207)
               || chr(8234) || '-' || chr(8238) || chr(8288) || chr(8294) || '-' || chr(8297) || chr(65279) || ']';
$$;

create function public.has_hidden_characters(p_text text)
returns boolean
language sql
immutable
set search_path = ''
as $$
    select coalesce(p_text ~ public.hidden_characters_pattern(), false);
$$;

create function public.has_link(p_text text)
returns boolean
language sql
immutable
set search_path = ''
as $$
    select coalesce(p_text ~* '(https?://|www\.|\m[a-z0-9-]+\.(com|cz|sk|net|org|io|me|ly|app|eu|gg)\M)', false);
$$;

create function public.plain_text(p_text text)
returns text
language sql
immutable
set search_path = ''
as $$
    select btrim(regexp_replace(p_text, public.hidden_characters_pattern(), '', 'g'));
$$;

-- A name is the one text a stranger sees (in a friend request), so it is refused, not quietly repaired.
create function public.guard_display_name()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if public.has_hidden_characters(new.display_name) or public.has_link(new.display_name) then
        raise exception 'invalid_name' using errcode = '22023';
    end if;
    return new;
end;
$$;
create trigger profiles_guard_name before insert or update of display_name on public.profiles
    for each row execute function public.guard_display_name();

-- Removes invisible characters from the text columns named in the trigger, whatever function writes the row.
create function public.strip_hidden_characters()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_column text;
    v_row jsonb := to_jsonb(new);
    v_clean jsonb := '{}'::jsonb;
begin
    foreach v_column in array tg_argv loop
        if public.has_hidden_characters(v_row ->> v_column) then
            v_clean := v_clean || jsonb_build_object(v_column, public.plain_text(v_row ->> v_column));
        end if;
    end loop;
    if v_clean <> '{}'::jsonb then
        new := jsonb_populate_record(new, v_clean);
    end if;
    return new;
end;
$$;

create trigger profiles_plain_text before insert or update of dnd_reason_text on public.profiles
    for each row execute function public.strip_hidden_characters('dnd_reason_text');
create trigger pokes_plain_text before insert or update of body on public.pokes
    for each row execute function public.strip_hidden_characters('body');
create trigger bets_plain_text before insert or update of title, terms on public.bets
    for each row execute function public.strip_hidden_characters('title', 'terms');
create trigger challenges_plain_text before insert or update of title, category on public.challenges
    for each row execute function public.strip_hidden_characters('title', 'category');
create trigger groups_plain_text before insert or update of name on public.groups
    for each row execute function public.strip_hidden_characters('name');
create trigger activities_plain_text before insert or update of title, category on public.activities
    for each row execute function public.strip_hidden_characters('title', 'category');
create trigger witness_requests_plain_text before insert or update of title on public.witness_requests
    for each row execute function public.strip_hidden_characters('title');
create trigger shared_tasks_plain_text before insert or update of title, category on public.shared_tasks
    for each row execute function public.strip_hidden_characters('title', 'category');
create trigger reports_plain_text before insert or update of note on public.reports
    for each row execute function public.strip_hidden_characters('note');

-- Helpers for the functions above only, never for the app.
do $$
declare f text;
begin
    foreach f in array array['hidden_characters_pattern()', 'has_hidden_characters(text)', 'has_link(text)', 'plain_text(text)',
                             'guard_display_name()', 'strip_hidden_characters()'] loop
        execute format('revoke all on function public.%s from public, anon, authenticated', f);
    end loop;
end $$;
