-- Kept social layer, phase 2: pokes with a text of the sender's own, and the "do not disturb" mode.

alter table public.profiles
    -- Set from the dashboard when a sender abused pokes; such a person can no longer poke.
    add column poke_banned_at timestamptz,
    add column dnd_active boolean not null default false,
    add column dnd_reason_key text check (dnd_reason_key in
        ('work', 'school', 'training', 'trip', 'vacation', 'sleep', 'illness', 'calm', 'family', 'focus', 'custom')),
    add column dnd_reason_text text check (char_length(dnd_reason_text) <= 60),
    -- Friends see only "do not disturb"; the reason is shown to them only when the person chose to share it.
    add column dnd_reason_shared boolean not null default false,
    add column dnd_until timestamptz;

-- ---------------------------------------------------------------------------------------------
-- Pokes

create table public.pokes (
    id uuid primary key default gen_random_uuid(),
    sender uuid not null references auth.users (id) on delete cascade,
    recipient uuid not null references auth.users (id) on delete cascade,
    body text not null check (char_length(body) between 1 and 100),
    created_at timestamptz not null default now(),
    seen_at timestamptz,
    -- A reported poke disappears for the recipient at once.
    hidden_at timestamptz,
    check (sender <> recipient)
);
create index pokes_recipient on public.pokes (recipient, created_at desc);
create index pokes_pair on public.pokes (sender, recipient, created_at desc);
alter table public.pokes enable row level security;
create policy pokes_select_own on public.pokes
    for select to authenticated
    using ((recipient = (select auth.uid()) and hidden_at is null) or sender = (select auth.uid()));
revoke insert, update, delete, truncate on public.pokes from anon, authenticated;
revoke all on public.pokes from anon;

-- Ending a friendship (removal, blocking) also deletes the pokes between the two people.
create function public.remove_pokes_between()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    delete from public.pokes
     where (sender = old.user_a and recipient = old.user_b) or (sender = old.user_b and recipient = old.user_a);
    return old;
end;
$$;
revoke all on function public.remove_pokes_between() from public, anon, authenticated;
create trigger friendships_remove_pokes after delete on public.friendships
    for each row execute function public.remove_pokes_between();

-- Whether the person's "do not disturb" is on right now (an end time that has passed counts as off).
create function public.is_dnd(p_user uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
    select coalesce((select dnd_active and (dnd_until is null or dnd_until > now()) from public.profiles where id = p_user), false);
$$;
revoke all on function public.is_dnd(uuid) from public, anon, authenticated;

-- A poke is a short text of the sender's own. One person can be poked at most once every 3 hours;
-- there is no limit on how many different people one sender pokes.
create function public.send_poke(p_to uuid, p_body text)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.active_user();
    v_body text := btrim(p_body);
    v_sent timestamptz;
begin
    if exists (select 1 from public.profiles where id = v_uid and poke_banned_at is not null) then
        raise exception 'poke_banned' using errcode = '42501';
    end if;
    if p_to is null or p_to = v_uid
       or not exists (select 1 from public.friendships
                       where user_a = least(v_uid, p_to) and user_b = greatest(v_uid, p_to) and status = 'accepted') then
        raise exception 'not_found' using errcode = 'P0002';
    end if;
    if v_body is null or char_length(v_body) not between 1 and 100 then
        raise exception 'invalid_text' using errcode = '22023';
    end if;
    if v_body ~* '(https?://|www\.|\m[a-z0-9-]+\.(com|cz|sk|net|org|io|me|ly|app|eu|gg)\M)' then
        raise exception 'links_not_allowed' using errcode = '22023';
    end if;
    if public.is_dnd(p_to) then
        raise exception 'do_not_disturb' using errcode = '55000';
    end if;
    if exists (select 1 from public.pokes where sender = v_uid and recipient = p_to and created_at > now() - interval '3 hours') then
        raise exception 'too_soon' using errcode = '55000';
    end if;
    perform public.check_rate(v_uid, 'poke', 120, interval '1 hour');

    insert into public.pokes (sender, recipient, body) values (v_uid, p_to, v_body) returning created_at into v_sent;
    return v_sent;
end;
$$;

-- When each person pokes by the caller can be poked again (only those still waiting).
create function public.poke_cooldowns()
returns table (recipient uuid, available_at timestamptz)
language sql
security definer
set search_path = ''
stable
as $$
    select p.recipient, max(p.created_at) + interval '3 hours'
      from public.pokes p
     where p.sender = (select auth.uid()) and p.created_at > now() - interval '3 hours'
     group by p.recipient;
$$;

create function public.pokes_inbox()
returns table (id uuid, sender_id uuid, sender_name text, body text, created_at timestamptz, seen boolean)
language sql
security definer
set search_path = ''
stable
as $$
    select p.id, p.sender, pr.display_name, p.body, p.created_at, p.seen_at is not null
      from public.pokes p
      join public.profiles pr on pr.id = p.sender
     where p.recipient = (select auth.uid()) and p.hidden_at is null and p.created_at > now() - interval '30 days'
     order by p.created_at desc
     limit 50;
$$;

create function public.mark_pokes_seen()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    update public.pokes set seen_at = now() where recipient = v_uid and seen_at is null;
end;
$$;

create function public.delete_poke(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    delete from public.pokes where id = p_id and recipient = v_uid;
end;
$$;

-- Reporting a poke hides it at once and sends the text to the moderator together with the report.
create function public.report_poke(p_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.active_user();
    v_poke public.pokes;
begin
    perform public.check_rate(v_uid, 'report', 10, interval '1 day');
    select * into v_poke from public.pokes where id = p_id and recipient = v_uid;
    if not found then
        raise exception 'not_found' using errcode = 'P0002';
    end if;
    insert into public.reports (reporter, reported, reason, note)
    values (v_uid, v_poke.sender, p_reason, left('poke: ' || v_poke.body, 500));
    update public.pokes set hidden_at = now() where id = p_id;
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Do not disturb

-- p_hours = 0 keeps it on until the person turns it off.
create function public.set_dnd(p_active boolean, p_reason_key text, p_reason_text text, p_share boolean, p_hours int)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.active_user();
    v_text text := nullif(btrim(p_reason_text), '');
begin
    if p_active then
        if p_reason_key = 'custom' then
            -- At most six words.
            if v_text is null or array_length(regexp_split_to_array(v_text, '\s+'), 1) > 6 or char_length(v_text) > 60 then
                raise exception 'invalid_reason' using errcode = '22023';
            end if;
        else
            v_text := null;
        end if;
        update public.profiles
           set dnd_active = true,
               dnd_reason_key = p_reason_key,
               dnd_reason_text = v_text,
               dnd_reason_shared = coalesce(p_share, false),
               dnd_until = case when coalesce(p_hours, 0) > 0 then now() + make_interval(hours => least(p_hours, 24 * 14)) end
         where id = v_uid;
    else
        update public.profiles
           set dnd_active = false, dnd_reason_key = null, dnd_reason_text = null, dnd_reason_shared = false, dnd_until = null
         where id = v_uid;
    end if;
end;
$$;

-- The friends list now also says who has "do not disturb" on, and why when they chose to say.
drop function public.my_friends();
create function public.my_friends()
returns table (id uuid, display_name text, handle text, since timestamptz,
               dnd boolean, dnd_reason_key text, dnd_reason_text text)
language sql
security definer
set search_path = ''
stable
as $$
    select p.id, p.display_name, p.display_name || '#' || p.handle_number, f.accepted_at,
           public.is_dnd(p.id),
           case when public.is_dnd(p.id) and p.dnd_reason_shared then p.dnd_reason_key end,
           case when public.is_dnd(p.id) and p.dnd_reason_shared then p.dnd_reason_text end
      from public.friendships f
      join public.profiles p on p.id = case when f.user_a = (select auth.uid()) then f.user_b else f.user_a end
     where f.status = 'accepted' and (select auth.uid()) in (f.user_a, f.user_b)
     order by lower(p.display_name);
$$;

do $$
declare
    f text;
begin
    foreach f in array array[
        'send_poke(uuid, text)', 'poke_cooldowns()', 'pokes_inbox()', 'mark_pokes_seen()', 'delete_poke(uuid)',
        'report_poke(uuid, text)', 'set_dnd(boolean, text, text, boolean, int)', 'my_friends()'
    ] loop
        execute format('revoke all on function public.%s from public, anon', f);
        execute format('grant execute on function public.%s to authenticated', f);
    end loop;
end $$;
