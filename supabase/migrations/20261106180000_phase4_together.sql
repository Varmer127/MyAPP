-- Kept social layer, phase 4 (second part): a witness for a task, a pair buddy, shared challenges,
-- groups (family, team) and shared activities in the calendar. Everything happens only between friends.

-- ---------------------------------------------------------------------------------------------
-- Witness: a friend confirms that a finished task really happened.

create table public.witness_requests (
    id uuid primary key default gen_random_uuid(),
    owner uuid not null references auth.users (id) on delete cascade,
    witness uuid not null references auth.users (id) on delete cascade,
    -- The task's id in the owner's app; the server knows only its title and day.
    task_ref uuid not null,
    title text not null check (char_length(title) between 1 and 80),
    day date not null,
    status text not null default 'pending' check (status in ('pending', 'confirmed', 'rejected')),
    created_at timestamptz not null default now(),
    answered_at timestamptz,
    unique (owner, task_ref),
    check (owner <> witness)
);
create index witness_requests_witness on public.witness_requests (witness, status);

-- ---------------------------------------------------------------------------------------------
-- Pair buddy: one friend who keeps an eye on the other's day. One buddy per person.

create table public.buddies (
    user_a uuid not null references auth.users (id) on delete cascade,
    user_b uuid not null references auth.users (id) on delete cascade,
    requested_by uuid not null references auth.users (id) on delete cascade,
    status text not null check (status in ('pending', 'accepted')),
    created_at timestamptz not null default now(),
    primary key (user_a, user_b),
    check (user_a < user_b)
);

-- Today's numbers, so a buddy can see how the day goes.
create table public.day_snapshots (
    user_id uuid primary key references auth.users (id) on delete cascade,
    day date not null,
    done smallint not null check (done between 0 and 200),
    total smallint not null check (total between 0 and 200),
    updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------------------------
-- Shared challenges: reach a number of finished tasks (of one kind, or any) before a date, together.

create table public.challenges (
    id uuid primary key default gen_random_uuid(),
    creator uuid not null references auth.users (id) on delete cascade,
    title text not null check (char_length(title) between 1 and 80),
    -- A task category, or null for any task.
    category text check (char_length(category) between 1 and 30),
    target int not null check (target between 1 and 500),
    starts_on date not null,
    ends_on date not null,
    created_at timestamptz not null default now(),
    check (ends_on >= starts_on)
);
create table public.challenge_members (
    challenge_id uuid not null references public.challenges (id) on delete cascade,
    user_id uuid not null references auth.users (id) on delete cascade,
    status text not null check (status in ('invited', 'accepted')),
    progress int not null default 0 check (progress between 0 and 10000),
    updated_at timestamptz not null default now(),
    primary key (challenge_id, user_id)
);
create index challenge_members_user on public.challenge_members (user_id);

-- ---------------------------------------------------------------------------------------------
-- Groups: a family or a team, with its own leaderboard.

create table public.groups (
    id uuid primary key default gen_random_uuid(),
    owner uuid not null references auth.users (id) on delete cascade,
    name text not null check (char_length(name) between 1 and 40),
    created_at timestamptz not null default now()
);
create table public.group_members (
    group_id uuid not null references public.groups (id) on delete cascade,
    user_id uuid not null references auth.users (id) on delete cascade,
    status text not null check (status in ('invited', 'accepted')),
    joined_at timestamptz,
    primary key (group_id, user_id)
);
create index group_members_user on public.group_members (user_id);

-- ---------------------------------------------------------------------------------------------
-- Shared activities: "a run on Saturday at 9" with friends; accepting puts it into one's own plan.

create table public.activities (
    id uuid primary key default gen_random_uuid(),
    creator uuid not null references auth.users (id) on delete cascade,
    title text not null check (char_length(title) between 1 and 80),
    category text not null check (char_length(category) between 1 and 30),
    starts_at timestamptz not null,
    minutes int not null check (minutes between 15 and 960),
    created_at timestamptz not null default now()
);
create table public.activity_members (
    activity_id uuid not null references public.activities (id) on delete cascade,
    user_id uuid not null references auth.users (id) on delete cascade,
    status text not null check (status in ('invited', 'accepted', 'declined')),
    primary key (activity_id, user_id)
);
create index activity_members_user on public.activity_members (user_id);

do $$
declare t text;
begin
    foreach t in array array['witness_requests', 'buddies', 'day_snapshots', 'challenges', 'challenge_members',
                             'groups', 'group_members', 'activities', 'activity_members'] loop
        execute format('alter table public.%I enable row level security', t);
        execute format('revoke all on public.%I from anon, authenticated', t);
    end loop;
end $$;

-- Ending a friendship removes the witness requests and the buddy pair between the two people.
create function public.remove_together_between()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    delete from public.witness_requests
     where (owner = old.user_a and witness = old.user_b) or (owner = old.user_b and witness = old.user_a);
    delete from public.buddies where user_a = old.user_a and user_b = old.user_b;
    return old;
end;
$$;
revoke all on function public.remove_together_between() from public, anon, authenticated;
create trigger friendships_remove_together after delete on public.friendships
    for each row execute function public.remove_together_between();

-- Every invitee must be a friend of the caller; between 1 and p_max people.
create function public.check_invitees(p_uid uuid, p_invitees uuid[], p_max int)
returns void
language plpgsql
security definer
set search_path = ''
stable
as $$
declare v_friend uuid;
begin
    if p_invitees is null or cardinality(p_invitees) not between 1 and p_max then
        raise exception 'invalid_invitees' using errcode = '22023';
    end if;
    foreach v_friend in array p_invitees loop
        if v_friend = p_uid or not public.are_friends(p_uid, v_friend) then
            raise exception 'not_found' using errcode = 'P0002';
        end if;
    end loop;
end;
$$;
revoke all on function public.check_invitees(uuid, uuid[], int) from public, anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- Witness

create function public.request_witness(p_witness uuid, p_task uuid, p_title text, p_day date)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    if p_witness = v_uid or not public.are_friends(v_uid, p_witness) then
        raise exception 'not_found' using errcode = 'P0002';
    end if;
    if btrim(coalesce(p_title, '')) = '' or p_day is null then
        raise exception 'invalid_task' using errcode = '22023';
    end if;
    perform public.check_rate(v_uid, 'witness', 60, interval '1 day');
    insert into public.witness_requests (owner, witness, task_ref, title, day)
    values (v_uid, p_witness, p_task, left(btrim(p_title), 80), p_day)
    on conflict (owner, task_ref) do update
        set witness = excluded.witness, title = excluded.title, day = excluded.day,
            status = 'pending', created_at = now(), answered_at = null;
end;
$$;

create function public.answer_witness(p_id uuid, p_confirm boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    update public.witness_requests
       set status = case when p_confirm then 'confirmed' else 'rejected' end, answered_at = now()
     where id = p_id and witness = v_uid and status = 'pending';
    if not found then
        raise exception 'not_found' using errcode = 'P0002';
    end if;
end;
$$;

-- Requests the caller should answer, and the answers to the caller's own requests.
create function public.my_witnessing()
returns jsonb
language sql
security definer
set search_path = ''
stable
as $$
    select jsonb_build_object(
        'to_answer', coalesce((select jsonb_agg(jsonb_build_object(
                'id', w.id, 'owner_name', p.display_name, 'title', w.title, 'day', w.day) order by w.created_at)
              from public.witness_requests w join public.profiles p on p.id = w.owner
             where w.witness = (select auth.uid()) and w.status = 'pending'), '[]'::jsonb),
        'mine', coalesce((select jsonb_agg(jsonb_build_object(
                'task_ref', w.task_ref, 'witness_name', p.display_name, 'status', w.status))
              from public.witness_requests w join public.profiles p on p.id = w.witness
             where w.owner = (select auth.uid()) and w.created_at > now() - interval '120 days'), '[]'::jsonb));
$$;

-- ---------------------------------------------------------------------------------------------
-- Buddy

create function public.has_buddy(p_user uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
    select exists (select 1 from public.buddies where status = 'accepted' and p_user in (user_a, user_b));
$$;
revoke all on function public.has_buddy(uuid) from public, anon, authenticated;

create function public.request_buddy(p_friend uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.active_user();
    v_row public.buddies;
begin
    if p_friend = v_uid or not public.are_friends(v_uid, p_friend) then
        raise exception 'not_found' using errcode = 'P0002';
    end if;
    if public.has_buddy(v_uid) or public.has_buddy(p_friend) then
        raise exception 'already_paired' using errcode = '23505';
    end if;
    select * into v_row from public.buddies where user_a = least(v_uid, p_friend) and user_b = greatest(v_uid, p_friend);
    if found then
        if v_row.requested_by <> v_uid then
            update public.buddies set status = 'accepted' where user_a = v_row.user_a and user_b = v_row.user_b;
            delete from public.buddies where status = 'pending' and (v_uid in (user_a, user_b) or p_friend in (user_a, user_b));
            return 'accepted';
        end if;
        return 'requested';
    end if;
    insert into public.buddies (user_a, user_b, requested_by, status)
    values (least(v_uid, p_friend), greatest(v_uid, p_friend), v_uid, 'pending');
    return 'requested';
end;
$$;

create function public.respond_buddy(p_from uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    if p_accept then
        if public.has_buddy(v_uid) or public.has_buddy(p_from) then
            raise exception 'already_paired' using errcode = '23505';
        end if;
        update public.buddies set status = 'accepted'
         where user_a = least(v_uid, p_from) and user_b = greatest(v_uid, p_from) and requested_by = p_from and status = 'pending';
        if not found then
            raise exception 'not_found' using errcode = 'P0002';
        end if;
        -- Other open requests of the two are void now.
        delete from public.buddies where status = 'pending' and (v_uid in (user_a, user_b) or p_from in (user_a, user_b));
    else
        delete from public.buddies
         where user_a = least(v_uid, p_from) and user_b = greatest(v_uid, p_from) and requested_by = p_from and status = 'pending';
    end if;
end;
$$;

create function public.end_buddy()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    delete from public.buddies where v_uid in (user_a, user_b);
end;
$$;

create function public.push_day(p_day date, p_done int, p_total int)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.active_user();
    v_today date := (now() at time zone 'Europe/Prague')::date;
begin
    if p_day is null or p_day not between v_today - 1 and v_today + 1 then
        raise exception 'invalid_day' using errcode = '22023';
    end if;
    insert into public.day_snapshots (user_id, day, done, total, updated_at)
    values (v_uid, p_day, p_done, p_total, now())
    on conflict (user_id) do update set day = excluded.day, done = excluded.done, total = excluded.total, updated_at = now();
end;
$$;

-- The buddy (or an open buddy request) and how the buddy's day goes.
create function public.my_buddy()
returns jsonb
language sql
security definer
set search_path = ''
stable
as $$
    select coalesce((
        select jsonb_agg(jsonb_build_object(
            'id', p.id, 'name', p.display_name,
            'state', case when b.status = 'accepted' then 'paired'
                          when b.requested_by = (select auth.uid()) then 'outgoing' else 'incoming' end,
            'day', case when b.status = 'accepted' then d.day end,
            'done', case when b.status = 'accepted' then d.done end,
            'total', case when b.status = 'accepted' then d.total end))
          from public.buddies b
          join public.profiles p on p.id = case when b.user_a = (select auth.uid()) then b.user_b else b.user_a end
          left join public.day_snapshots d on d.user_id = p.id
         where (select auth.uid()) in (b.user_a, b.user_b)), '[]'::jsonb);
$$;

-- ---------------------------------------------------------------------------------------------
-- Challenges

create function public.create_challenge(p_title text, p_category text, p_target int, p_days int, p_invitees uuid[])
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.active_user();
    v_id uuid;
    v_today date := (now() at time zone 'Europe/Prague')::date;
begin
    perform public.check_invitees(v_uid, p_invitees, 19);
    if btrim(coalesce(p_title, '')) = '' or p_target is null or p_target not between 1 and 500
       or p_days is null or p_days not between 7 and 365 then
        raise exception 'invalid_challenge' using errcode = '22023';
    end if;
    perform public.check_rate(v_uid, 'challenge', 20, interval '1 day');
    insert into public.challenges (creator, title, category, target, starts_on, ends_on)
    values (v_uid, left(btrim(p_title), 80), nullif(btrim(coalesce(p_category, '')), ''), p_target, v_today, v_today + p_days - 1)
    returning id into v_id;
    insert into public.challenge_members (challenge_id, user_id, status) values (v_id, v_uid, 'accepted');
    insert into public.challenge_members (challenge_id, user_id, status)
    select v_id, x, 'invited' from (select distinct unnest(p_invitees) as x) i;
    return v_id;
end;
$$;

create function public.respond_challenge(p_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    if p_accept then
        update public.challenge_members set status = 'accepted', updated_at = now()
         where challenge_id = p_id and user_id = v_uid and status = 'invited';
    else
        delete from public.challenge_members where challenge_id = p_id and user_id = v_uid and status = 'invited';
    end if;
    if not found then
        raise exception 'not_found' using errcode = 'P0002';
    end if;
end;
$$;

create function public.leave_challenge(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    delete from public.challenge_members where challenge_id = p_id and user_id = v_uid;
    -- A challenge nobody is in any more is gone.
    delete from public.challenges c where c.id = p_id and not exists (select 1 from public.challenge_members m where m.challenge_id = c.id);
end;
$$;

create function public.push_challenge_progress(p_id uuid, p_progress int)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    update public.challenge_members set progress = least(greatest(coalesce(p_progress, 0), 0), 10000), updated_at = now()
     where challenge_id = p_id and user_id = v_uid and status = 'accepted';
end;
$$;

create function public.my_challenges()
returns jsonb
language sql
security definer
set search_path = ''
stable
as $$
    select coalesce(jsonb_agg(jsonb_build_object(
        'id', c.id, 'title', c.title, 'category', c.category, 'target', c.target,
        'starts_on', c.starts_on, 'ends_on', c.ends_on, 'is_creator', c.creator = (select auth.uid()),
        'my_status', me.status,
        'members', (select jsonb_agg(jsonb_build_object('id', m.user_id, 'name', p.display_name, 'status', m.status,
                                                        'progress', m.progress, 'is_me', m.user_id = (select auth.uid()))
                                     order by m.progress desc)
                      from public.challenge_members m join public.profiles p on p.id = m.user_id
                     where m.challenge_id = c.id)
    ) order by c.ends_on), '[]'::jsonb)
      from public.challenges c
      join public.challenge_members me on me.challenge_id = c.id and me.user_id = (select auth.uid())
     where c.ends_on >= (now() at time zone 'Europe/Prague')::date - 30;
$$;

-- ---------------------------------------------------------------------------------------------
-- Groups

create function public.create_group(p_name text, p_invitees uuid[])
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.active_user();
    v_id uuid;
begin
    perform public.check_invitees(v_uid, p_invitees, 29);
    if btrim(coalesce(p_name, '')) = '' then
        raise exception 'invalid_name' using errcode = '22023';
    end if;
    perform public.check_rate(v_uid, 'group', 10, interval '1 day');
    insert into public.groups (owner, name) values (v_uid, left(btrim(p_name), 40)) returning id into v_id;
    insert into public.group_members (group_id, user_id, status, joined_at) values (v_id, v_uid, 'accepted', now());
    insert into public.group_members (group_id, user_id, status)
    select v_id, x, 'invited' from (select distinct unnest(p_invitees) as x) i;
    return v_id;
end;
$$;

create function public.invite_to_group(p_group uuid, p_invitees uuid[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    if not exists (select 1 from public.groups where id = p_group and owner = v_uid) then
        raise exception 'not_found' using errcode = 'P0002';
    end if;
    perform public.check_invitees(v_uid, p_invitees, 29);
    insert into public.group_members (group_id, user_id, status)
    select p_group, x, 'invited' from (select distinct unnest(p_invitees) as x) i
    on conflict do nothing;
    if (select count(*) from public.group_members where group_id = p_group) > 30 then
        raise exception 'too_many_people' using errcode = '54000';
    end if;
end;
$$;

create function public.respond_group(p_group uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    if p_accept then
        update public.group_members set status = 'accepted', joined_at = now()
         where group_id = p_group and user_id = v_uid and status = 'invited';
    else
        delete from public.group_members where group_id = p_group and user_id = v_uid and status = 'invited';
    end if;
    if not found then
        raise exception 'not_found' using errcode = 'P0002';
    end if;
end;
$$;

-- Leaving a group; when the owner leaves, the group ends for everybody.
create function public.leave_group(p_group uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    if exists (select 1 from public.groups where id = p_group and owner = v_uid) then
        delete from public.groups where id = p_group;
    else
        delete from public.group_members where group_id = p_group and user_id = v_uid;
    end if;
end;
$$;

-- The caller's groups with their members and, for members in leaderboards, this week's reliability.
create function public.my_groups()
returns jsonb
language sql
security definer
set search_path = ''
stable
as $$
    select coalesce(jsonb_agg(jsonb_build_object(
        'id', g.id, 'name', g.name, 'is_owner', g.owner = (select auth.uid()), 'my_status', me.status,
        'members', (select jsonb_agg(jsonb_build_object(
                        'id', m.user_id, 'name', p.display_name, 'status', m.status, 'is_me', m.user_id = (select auth.uid()),
                        'reliability', case when m.status = 'accepted' and p.leaderboards_enabled then s.reliability end)
                        order by s.reliability desc nulls last)
                      from public.group_members m
                      join public.profiles p on p.id = m.user_id
                      left join public.week_snapshots s
                             on s.user_id = m.user_id and s.week_start = date_trunc('week', now() at time zone 'Europe/Prague')::date
                     where m.group_id = g.id)
    ) order by g.name), '[]'::jsonb)
      from public.groups g
      join public.group_members me on me.group_id = g.id and me.user_id = (select auth.uid());
$$;

-- ---------------------------------------------------------------------------------------------
-- Shared activities

create function public.create_activity(p_title text, p_category text, p_starts_at timestamptz, p_minutes int, p_invitees uuid[])
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.active_user();
    v_id uuid;
begin
    perform public.check_invitees(v_uid, p_invitees, 19);
    if btrim(coalesce(p_title, '')) = '' or btrim(coalesce(p_category, '')) = ''
       or p_starts_at is null or p_starts_at < now() - interval '1 hour' or p_starts_at > now() + interval '1 year'
       or p_minutes is null or p_minutes not between 15 and 960 then
        raise exception 'invalid_activity' using errcode = '22023';
    end if;
    perform public.check_rate(v_uid, 'activity', 30, interval '1 day');
    insert into public.activities (creator, title, category, starts_at, minutes)
    values (v_uid, left(btrim(p_title), 80), left(btrim(p_category), 30), p_starts_at, p_minutes)
    returning id into v_id;
    insert into public.activity_members (activity_id, user_id, status) values (v_id, v_uid, 'accepted');
    insert into public.activity_members (activity_id, user_id, status)
    select v_id, x, 'invited' from (select distinct unnest(p_invitees) as x) i;
    return v_id;
end;
$$;

create function public.respond_activity(p_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    update public.activity_members set status = case when p_accept then 'accepted' else 'declined' end
     where activity_id = p_id and user_id = v_uid;
    if not found then
        raise exception 'not_found' using errcode = 'P0002';
    end if;
end;
$$;

create function public.my_activities()
returns jsonb
language sql
security definer
set search_path = ''
stable
as $$
    select coalesce(jsonb_agg(jsonb_build_object(
        'id', a.id, 'title', a.title, 'category', a.category, 'starts_at', a.starts_at, 'minutes', a.minutes,
        'is_creator', a.creator = (select auth.uid()), 'my_status', me.status,
        'members', (select jsonb_agg(jsonb_build_object('id', m.user_id, 'name', p.display_name, 'status', m.status,
                                                        'is_me', m.user_id = (select auth.uid())))
                      from public.activity_members m join public.profiles p on p.id = m.user_id
                     where m.activity_id = a.id)
    ) order by a.starts_at), '[]'::jsonb)
      from public.activities a
      join public.activity_members me on me.activity_id = a.id and me.user_id = (select auth.uid())
     where a.starts_at > now() - interval '2 days';
$$;

do $$
declare
    f text;
begin
    foreach f in array array[
        'request_witness(uuid, uuid, text, date)', 'answer_witness(uuid, boolean)', 'my_witnessing()',
        'request_buddy(uuid)', 'respond_buddy(uuid, boolean)', 'end_buddy()', 'push_day(date, int, int)', 'my_buddy()',
        'create_challenge(text, text, int, int, uuid[])', 'respond_challenge(uuid, boolean)', 'leave_challenge(uuid)',
        'push_challenge_progress(uuid, int)', 'my_challenges()',
        'create_group(text, uuid[])', 'invite_to_group(uuid, uuid[])', 'respond_group(uuid, boolean)', 'leave_group(uuid)', 'my_groups()',
        'create_activity(text, text, timestamptz, int, uuid[])', 'respond_activity(uuid, boolean)', 'my_activities()'
    ] loop
        execute format('revoke all on function public.%s from public, anon', f);
        execute format('grant execute on function public.%s to authenticated', f);
    end loop;
end $$;
