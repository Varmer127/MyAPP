-- Kept social layer, phase 3: sharing the week, friends' leaderboards and reactions.
-- What is shared is chosen by the person: nothing (default), a summary of the week, or the whole plan.
-- Notes, reasons, stakes, the diary, weight and health never leave the phone.

alter table public.profiles
    add column share_level text not null default 'none' check (share_level in ('none', 'summary', 'plan')),
    -- Leaderboards are on by default and can be turned off at any time.
    add column leaderboards_enabled boolean not null default true;

-- One row per person and week, sent by the app. The numbers come from the phone (honest limit: they rely on trust).
create table public.week_snapshots (
    user_id uuid not null references auth.users (id) on delete cascade,
    week_start date not null,
    reliability smallint check (reliability between 0 and 100),
    done smallint not null check (done between 0 and 500),
    total smallint not null check (total between 0 and 500),
    streak smallint not null default 0 check (streak between 0 and 3650),
    badges smallint not null default 0 check (badges between 0 and 500),
    sealed boolean not null default false,
    updated_at timestamptz not null default now(),
    primary key (user_id, week_start)
);
alter table public.week_snapshots enable row level security;

-- The plan of the week, only for people who share the whole plan: title, category, day and state.
create table public.shared_tasks (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade,
    week_start date not null,
    day date not null,
    title text not null check (char_length(title) between 1 and 80),
    category text not null check (char_length(category) between 1 and 30),
    status text not null check (status in ('open', 'done', 'missed')),
    position smallint not null default 0
);
create index shared_tasks_week on public.shared_tasks (user_id, week_start);
alter table public.shared_tasks enable row level security;

create table public.reactions (
    sender uuid not null references auth.users (id) on delete cascade,
    recipient uuid not null references auth.users (id) on delete cascade,
    week_start date not null,
    kind text not null check (kind in ('fire', 'clap', 'strong', 'heart')),
    created_at timestamptz not null default now(),
    seen_at timestamptz,
    primary key (sender, recipient, week_start, kind),
    check (sender <> recipient)
);
create index reactions_recipient on public.reactions (recipient, created_at desc);
alter table public.reactions enable row level security;

revoke all on public.week_snapshots, public.shared_tasks, public.reactions from anon, authenticated;

-- Ending a friendship also removes the reactions between the two people.
create function public.remove_reactions_between()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    delete from public.reactions
     where (sender = old.user_a and recipient = old.user_b) or (sender = old.user_b and recipient = old.user_a);
    return old;
end;
$$;
revoke all on function public.remove_reactions_between() from public, anon, authenticated;
create trigger friendships_remove_reactions after delete on public.friendships
    for each row execute function public.remove_reactions_between();

create function public.are_friends(p_a uuid, p_b uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
    select exists (select 1 from public.friendships
                    where user_a = least(p_a, p_b) and user_b = greatest(p_a, p_b) and status = 'accepted');
$$;
revoke all on function public.are_friends(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------------------------

create function public.set_sharing(p_level text, p_leaderboards boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    if p_level not in ('none', 'summary', 'plan') then
        raise exception 'invalid_level' using errcode = '22023';
    end if;
    update public.profiles set share_level = p_level, leaderboards_enabled = coalesce(p_leaderboards, true) where id = v_uid;
    -- Sharing less removes what was shared before.
    if p_level <> 'plan' then
        delete from public.shared_tasks where user_id = v_uid;
    end if;
end;
$$;

-- The app sends its numbers for one week (this one or one of the last two), and the plan when it is shared.
create function public.push_week(p_week date, p_reliability int, p_done int, p_total int, p_streak int,
                                 p_badges int, p_sealed boolean, p_tasks jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.active_user();
    v_level text;
begin
    if p_week is null or extract(isodow from p_week) <> 1
       or p_week < (now() at time zone 'Europe/Prague')::date - 21 or p_week > (now() at time zone 'Europe/Prague')::date + 7 then
        raise exception 'invalid_week' using errcode = '22023';
    end if;
    perform public.check_rate(v_uid, 'push_week', 120, interval '1 hour');

    insert into public.week_snapshots as s (user_id, week_start, reliability, done, total, streak, badges, sealed, updated_at)
    values (v_uid, p_week, p_reliability, p_done, p_total, p_streak, p_badges, coalesce(p_sealed, false), now())
    on conflict (user_id, week_start) do update
        set reliability = excluded.reliability, done = excluded.done, total = excluded.total, streak = excluded.streak,
            badges = excluded.badges, sealed = excluded.sealed, updated_at = now();

    select share_level into v_level from public.profiles where id = v_uid;
    delete from public.shared_tasks where user_id = v_uid and week_start = p_week;
    if v_level = 'plan' and jsonb_typeof(p_tasks) = 'array' then
        insert into public.shared_tasks (user_id, week_start, day, title, category, status, position)
        select v_uid, p_week, (t ->> 'day')::date, left(btrim(t ->> 'title'), 80), left(t ->> 'category', 30), t ->> 'status', x.ord
          from jsonb_array_elements(p_tasks) with ordinality as x(t, ord)
         where (t ->> 'day')::date between p_week and p_week + 6
           and btrim(coalesce(t ->> 'title', '')) <> ''
           and coalesce(t ->> 'category', '') <> ''
           and t ->> 'status' in ('open', 'done', 'missed')
         order by x.ord
         limit 60;
    end if;
end;
$$;

-- A friend's week as far as they share it, with the reactions the caller already gave to it.
create function public.friend_week(p_friend uuid, p_week date)
returns jsonb
language plpgsql
security definer
set search_path = ''
stable
as $$
declare
    v_uid uuid := (select auth.uid());
    v_level text;
    v_snapshot public.week_snapshots;
    v_result jsonb;
begin
    if v_uid is null or not public.are_friends(v_uid, p_friend) then
        raise exception 'not_found' using errcode = 'P0002';
    end if;
    select share_level into v_level from public.profiles where id = p_friend;
    v_result := jsonb_build_object(
        'level', v_level,
        'my_reactions', coalesce((select jsonb_agg(kind) from public.reactions
                                   where sender = v_uid and recipient = p_friend and week_start = p_week), '[]'::jsonb));
    if v_level = 'none' then
        return v_result;
    end if;
    select * into v_snapshot from public.week_snapshots where user_id = p_friend and week_start = p_week;
    if found then
        v_result := v_result || jsonb_build_object(
            'reliability', v_snapshot.reliability, 'done', v_snapshot.done, 'total', v_snapshot.total,
            'streak', v_snapshot.streak, 'sealed', v_snapshot.sealed);
    end if;
    if v_level = 'plan' then
        v_result := v_result || jsonb_build_object('tasks', coalesce((
            select jsonb_agg(jsonb_build_object('day', day, 'title', title, 'category', category, 'status', status) order by day, position)
              from public.shared_tasks where user_id = p_friend and week_start = p_week), '[]'::jsonb));
    end if;
    return v_result;
end;
$$;

-- Friends and the caller, ranked for one week. Only people who take part in leaderboards appear.
create function public.leaderboard(p_week date)
returns table (id uuid, display_name text, is_me boolean, reliability int, badges int, streak int)
language sql
security definer
set search_path = ''
stable
as $$
    with people as (
        select (select auth.uid()) as uid
        union
        select case when f.user_a = (select auth.uid()) then f.user_b else f.user_a end
          from public.friendships f
         where f.status = 'accepted' and (select auth.uid()) in (f.user_a, f.user_b)
    )
    select p.id, p.display_name, p.id = (select auth.uid()), s.reliability::int, s.badges::int, s.streak::int
      from people x
      join public.profiles p on p.id = x.uid and p.leaderboards_enabled and p.suspended_at is null
      join public.week_snapshots s on s.user_id = p.id and s.week_start = p_week;
$$;

-- A reaction is a small cheer on a friend's week. Tapping it again takes it back. Returns whether it is on now.
create function public.toggle_reaction(p_to uuid, p_week date, p_kind text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    if not public.are_friends(v_uid, p_to) then
        raise exception 'not_found' using errcode = 'P0002';
    end if;
    if p_kind not in ('fire', 'clap', 'strong', 'heart') then
        raise exception 'invalid_kind' using errcode = '22023';
    end if;
    delete from public.reactions where sender = v_uid and recipient = p_to and week_start = p_week and kind = p_kind;
    if found then
        return false;
    end if;
    perform public.check_rate(v_uid, 'reaction', 120, interval '1 hour');
    insert into public.reactions (sender, recipient, week_start, kind) values (v_uid, p_to, p_week, p_kind);
    return true;
end;
$$;

create function public.my_reactions()
returns table (sender_id uuid, sender_name text, kind text, week_start date, created_at timestamptz, seen boolean)
language sql
security definer
set search_path = ''
stable
as $$
    select r.sender, p.display_name, r.kind, r.week_start, r.created_at, r.seen_at is not null
      from public.reactions r join public.profiles p on p.id = r.sender
     where r.recipient = (select auth.uid()) and r.created_at > now() - interval '14 days'
     order by r.created_at desc
     limit 50;
$$;

create function public.mark_reactions_seen()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    update public.reactions set seen_at = now() where recipient = v_uid and seen_at is null;
end;
$$;

do $$
declare
    f text;
begin
    foreach f in array array[
        'set_sharing(text, boolean)', 'push_week(date, int, int, int, int, int, boolean, jsonb)',
        'friend_week(uuid, date)', 'leaderboard(date)', 'toggle_reaction(uuid, date, text)',
        'my_reactions()', 'mark_reactions_seen()'
    ] loop
        execute format('revoke all on function public.%s from public, anon', f);
        execute format('grant execute on function public.%s to authenticated', f);
    end loop;
end $$;
