-- Kept social layer, phase 1: friends, blocking, reporting, rate limits.
-- Everything is written through functions that check the rules; the tables have no write policies.

-- A person can be suspended from the dashboard (moderation); a suspended account cannot use any function below.
alter table public.profiles add column suspended_at timestamptz;
-- Short secret that goes into the personal QR code and link. It can be replaced at any time.
alter table public.profiles add column invite_code text not null default encode(extensions.gen_random_bytes(6), 'hex');
create unique index profiles_invite_code_key on public.profiles (invite_code);

-- ---------------------------------------------------------------------------------------------
-- Rate limits: how many times a kind of action may happen in a window. Used by every social function.

create table public.rate_events (
    user_id uuid not null references auth.users (id) on delete cascade,
    kind text not null,
    at timestamptz not null default now()
);
create index rate_events_lookup on public.rate_events (user_id, kind, at desc);
alter table public.rate_events enable row level security;

create function public.check_rate(p_user uuid, p_kind text, p_max int, p_window interval)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    delete from public.rate_events where user_id = p_user and at < now() - interval '2 days';
    if (select count(*) from public.rate_events where user_id = p_user and kind = p_kind and at > now() - p_window) >= p_max then
        raise exception 'rate_limited' using errcode = '54000';
    end if;
    insert into public.rate_events (user_id, kind) values (p_user, p_kind);
end;
$$;
revoke all on function public.check_rate(uuid, text, int, interval) from public, anon, authenticated;

-- The caller's id, and a check that the account exists and is not suspended.
create function public.active_user()
returns uuid
language plpgsql
security definer
set search_path = ''
stable
as $$
declare
    v_uid uuid := (select auth.uid());
    v_suspended timestamptz;
begin
    if v_uid is null then
        raise exception 'not_signed_in' using errcode = '28000';
    end if;
    select suspended_at into v_suspended from public.profiles where id = v_uid;
    if not found then
        raise exception 'no_profile' using errcode = 'P0002';
    end if;
    if v_suspended is not null then
        raise exception 'suspended' using errcode = '42501';
    end if;
    return v_uid;
end;
$$;
revoke all on function public.active_user() from public, anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- Tables

create table public.friendships (
    user_a uuid not null references auth.users (id) on delete cascade,
    user_b uuid not null references auth.users (id) on delete cascade,
    requested_by uuid not null references auth.users (id) on delete cascade,
    status text not null check (status in ('pending', 'accepted')),
    created_at timestamptz not null default now(),
    accepted_at timestamptz,
    -- One row per pair, with the smaller id first.
    primary key (user_a, user_b),
    check (user_a < user_b),
    check (requested_by = user_a or requested_by = user_b)
);
create index friendships_b on public.friendships (user_b);
alter table public.friendships enable row level security;
create policy friendships_select_own on public.friendships
    for select to authenticated
    using ((select auth.uid()) in (user_a, user_b));

create table public.blocks (
    blocker uuid not null references auth.users (id) on delete cascade,
    blocked uuid not null references auth.users (id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (blocker, blocked),
    check (blocker <> blocked)
);
create index blocks_blocked on public.blocks (blocked);
alter table public.blocks enable row level security;
create policy blocks_select_own on public.blocks
    for select to authenticated
    using (blocker = (select auth.uid()));

create table public.reports (
    id uuid primary key default gen_random_uuid(),
    reporter uuid references auth.users (id) on delete set null,
    reported uuid references auth.users (id) on delete set null,
    reason text not null check (reason in ('abuse', 'threat', 'sexual', 'spam', 'impersonation', 'other')),
    note text check (char_length(note) <= 500),
    status text not null default 'open' check (status in ('open', 'done')),
    created_at timestamptz not null default now()
);
create index reports_open on public.reports (status, created_at);
-- Reports are read in the dashboard only; people never read them back.
alter table public.reports enable row level security;

-- ---------------------------------------------------------------------------------------------
-- Helpers

create function public.is_blocked_between(p_a uuid, p_b uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
    select exists (select 1 from public.blocks where (blocker = p_a and blocked = p_b) or (blocker = p_b and blocked = p_a));
$$;
revoke all on function public.is_blocked_between(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- Finding someone: only by the whole identifier ("Jana#4827") or the code from a QR code or link.
-- Returns the name and the initial, nothing else (no age, no gender, no other data).

create function public.find_profile(p_query text)
returns table (id uuid, display_name text, initial text)
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.active_user();
    v_query text := btrim(p_query);
    v_name text;
    v_number int;
    v_row public.profiles;
begin
    perform public.check_rate(v_uid, 'find', 30, interval '10 minutes');
    if v_query is null or char_length(v_query) < 3 or char_length(v_query) > 60 then
        return;
    end if;

    if v_query ~ '^[0-9a-f]{12}$' then
        select * into v_row from public.profiles p where p.invite_code = v_query and p.suspended_at is null;
    elsif v_query ~ '#[0-9]{4}$' then
        v_name := btrim(substring(v_query from '^(.*)#[0-9]{4}$'));
        v_number := substring(v_query from '#([0-9]{4})$')::int;
        select * into v_row from public.profiles p
         where lower(p.display_name) = lower(v_name) and p.handle_number = v_number and p.suspended_at is null;
    end if;

    if v_row.id is null or v_row.id = v_uid or public.is_blocked_between(v_uid, v_row.id) then
        return;
    end if;
    return query select v_row.id, v_row.display_name, upper(left(v_row.display_name, 1));
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Requests and friendships

create function public.send_friend_request(p_target uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.active_user();
    v_a uuid := least(v_uid, p_target);
    v_b uuid := greatest(v_uid, p_target);
    v_row public.friendships;
begin
    if p_target is null or p_target = v_uid then
        raise exception 'invalid_target' using errcode = '22023';
    end if;
    if not exists (select 1 from public.profiles where id = p_target and suspended_at is null)
       or public.is_blocked_between(v_uid, p_target) then
        -- The same answer for "does not exist" and "blocked", so a block cannot be discovered.
        raise exception 'not_found' using errcode = 'P0002';
    end if;
    perform public.check_rate(v_uid, 'friend_request', 30, interval '1 hour');

    select * into v_row from public.friendships where user_a = v_a and user_b = v_b;
    if found then
        if v_row.status = 'accepted' then
            raise exception 'already_friends' using errcode = '23505';
        elsif v_row.requested_by = v_uid then
            raise exception 'already_requested' using errcode = '23505';
        else
            -- The other person asked first: asking back is the same as accepting.
            update public.friendships set status = 'accepted', accepted_at = now() where user_a = v_a and user_b = v_b;
            return 'accepted';
        end if;
    end if;

    if (select count(*) from public.friendships where requested_by = v_uid and status = 'pending') >= 20 then
        raise exception 'too_many_requests' using errcode = '54000';
    end if;
    if (select count(*) from public.friendships where status = 'accepted' and v_uid in (user_a, user_b)) >= 200 then
        raise exception 'too_many_friends' using errcode = '54000';
    end if;

    insert into public.friendships (user_a, user_b, requested_by, status) values (v_a, v_b, v_uid, 'pending');
    return 'requested';
end;
$$;

create function public.respond_friend_request(p_from uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.active_user();
    v_a uuid := least(v_uid, p_from);
    v_b uuid := greatest(v_uid, p_from);
begin
    if p_accept then
        if (select count(*) from public.friendships where status = 'accepted' and v_uid in (user_a, user_b)) >= 200 then
            raise exception 'too_many_friends' using errcode = '54000';
        end if;
        update public.friendships set status = 'accepted', accepted_at = now()
         where user_a = v_a and user_b = v_b and status = 'pending' and requested_by = p_from;
    else
        delete from public.friendships
         where user_a = v_a and user_b = v_b and status = 'pending' and requested_by = p_from;
    end if;
    if not found then
        raise exception 'not_found' using errcode = 'P0002';
    end if;
end;
$$;

-- Takes back a request the caller sent, or ends a friendship. Whatever hangs off the friendship
-- (shared plans, bets, pokes) is removed by the rows that reference it in later phases.
create function public.remove_friend(p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.active_user();
begin
    delete from public.friendships where user_a = least(v_uid, p_user) and user_b = greatest(v_uid, p_user);
end;
$$;

create function public.block_user(p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.active_user();
begin
    if p_user is null or p_user = v_uid then
        raise exception 'invalid_target' using errcode = '22023';
    end if;
    insert into public.blocks (blocker, blocked) values (v_uid, p_user) on conflict do nothing;
    delete from public.friendships where user_a = least(v_uid, p_user) and user_b = greatest(v_uid, p_user);
end;
$$;

create function public.unblock_user(p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.active_user();
begin
    delete from public.blocks where blocker = v_uid and blocked = p_user;
end;
$$;

create function public.report_user(p_user uuid, p_reason text, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.active_user();
begin
    if p_user is null or p_user = v_uid then
        raise exception 'invalid_target' using errcode = '22023';
    end if;
    perform public.check_rate(v_uid, 'report', 10, interval '1 day');
    insert into public.reports (reporter, reported, reason, note)
    values (v_uid, p_user, p_reason, left(btrim(p_note), 500));
end;
$$;

-- A new code for the QR code and link; the old one stops working.
create function public.rotate_invite_code()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.active_user();
    v_code text;
begin
    update public.profiles set invite_code = encode(extensions.gen_random_bytes(6), 'hex')
     where id = v_uid returning invite_code into v_code;
    return v_code;
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Lists for the screen

create function public.my_friends()
returns table (id uuid, display_name text, handle text, since timestamptz)
language sql
security definer
set search_path = ''
stable
as $$
    select p.id, p.display_name, p.display_name || '#' || p.handle_number, f.accepted_at
      from public.friendships f
      join public.profiles p on p.id = case when f.user_a = (select auth.uid()) then f.user_b else f.user_a end
     where f.status = 'accepted' and (select auth.uid()) in (f.user_a, f.user_b)
     order by lower(p.display_name);
$$;

-- Open requests. Before accepting, only the name and the initial are shown, never the number.
create function public.my_requests()
returns table (id uuid, display_name text, initial text, direction text, created_at timestamptz)
language sql
security definer
set search_path = ''
stable
as $$
    select p.id, p.display_name, upper(left(p.display_name, 1)),
           case when f.requested_by = (select auth.uid()) then 'outgoing' else 'incoming' end, f.created_at
      from public.friendships f
      join public.profiles p on p.id = case when f.user_a = (select auth.uid()) then f.user_b else f.user_a end
     where f.status = 'pending' and (select auth.uid()) in (f.user_a, f.user_b)
     order by f.created_at desc;
$$;

create function public.my_blocks()
returns table (id uuid, display_name text)
language sql
security definer
set search_path = ''
stable
as $$
    select p.id, p.display_name
      from public.blocks b join public.profiles p on p.id = b.blocked
     where b.blocker = (select auth.uid())
     order by lower(p.display_name);
$$;

-- The tables are only changed through the functions above, never directly.
revoke insert, update, delete, truncate on public.profiles, public.friendships, public.blocks from anon, authenticated;
revoke all on public.rate_events, public.reports from anon, authenticated;
revoke all on public.profiles, public.friendships, public.blocks from anon;

-- Only signed-in people may call the functions meant for the app.
do $$
declare
    f text;
begin
    foreach f in array array[
        'find_profile(text)', 'send_friend_request(uuid)', 'respond_friend_request(uuid, boolean)',
        'remove_friend(uuid)', 'block_user(uuid)', 'unblock_user(uuid)', 'report_user(uuid, text, text)',
        'rotate_invite_code()', 'my_friends()', 'my_requests()', 'my_blocks()'
    ] loop
        execute format('revoke all on function public.%s from public, anon', f);
        execute format('grant execute on function public.%s to authenticated', f);
    end loop;
end $$;
