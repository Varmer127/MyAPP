-- Kept social layer: no wait after a declined request and no limit for new accounts (decided by Philip),
-- a poke once a minute per person, and muting pokes from one person (for a week or for good) or from everybody.

-- ---------------------------------------------------------------------------------------------
-- Declined requests are no longer remembered.

create or replace function public.respond_friend_request(p_from uuid, p_accept boolean)
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

create or replace function public.send_friend_request(p_target uuid)
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

create or replace function public.purge_old_social_data()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    delete from public.rate_events where at < now() - interval '2 days';
    delete from public.pokes where created_at < now() - interval '30 days';
    delete from public.reactions where created_at < now() - interval '30 days';
    delete from public.notifications where created_at < now() - interval '30 days';
    delete from public.poke_mutes where until is not null and until < now();
    delete from public.day_snapshots where updated_at < now() - interval '3 days';
    delete from public.shared_tasks where week_start < (now() at time zone 'Europe/Prague')::date - 60;
    delete from public.week_snapshots where week_start < (now() at time zone 'Europe/Prague')::date - 400;
    delete from public.witness_requests where created_at < now() - interval '180 days';
    delete from public.activities where starts_at < now() - interval '30 days';
    delete from public.challenges where ends_on < (now() at time zone 'Europe/Prague')::date - 60;
    delete from public.bets where status <> 'open' and settled_at < now() - interval '180 days';
    delete from public.reports where status = 'done' and created_at < now() - interval '365 days';
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Muting pokes. A muted poke still arrives in the list, it only makes no sound or animation.

alter table public.profiles add column pokes_muted boolean not null default false;

create table public.poke_mutes (
    muter uuid not null references auth.users (id) on delete cascade,
    muted uuid not null references auth.users (id) on delete cascade,
    -- Null means for good.
    until timestamptz,
    primary key (muter, muted)
);
create index poke_mutes_muted on public.poke_mutes (muted);
alter table public.poke_mutes enable row level security;
revoke all on public.poke_mutes from anon, authenticated;

create function public.is_poke_muted(p_recipient uuid, p_sender uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
    select coalesce((select pokes_muted from public.profiles where id = p_recipient), false)
        or exists (select 1 from public.poke_mutes
                    where muter = p_recipient and muted = p_sender and (until is null or until > now()));
$$;
revoke all on function public.is_poke_muted(uuid, uuid) from public, anon, authenticated;

create or replace function public.notify_pokes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if not public.is_poke_muted(new.recipient, new.sender) then
        perform public.notify(new.recipient, new.sender, 'poke', new.id, nullif(new.body, ''));
    end if;
    return new;
end;
$$;

-- p_days 0 means for good; null removes the mute.
create function public.mute_pokes(p_from uuid, p_days int)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    if p_days is null then
        delete from public.poke_mutes where muter = v_uid and muted = p_from;
        return;
    end if;
    if p_from is null or p_from = v_uid or p_days < 0 then
        raise exception 'invalid_target' using errcode = '22023';
    end if;
    insert into public.poke_mutes (muter, muted, until)
    values (v_uid, p_from, case when p_days = 0 then null else now() + make_interval(days => p_days) end)
    on conflict (muter, muted) do update set until = excluded.until;
end;
$$;

create function public.set_pokes_muted(p_muted boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    update public.profiles set pokes_muted = coalesce(p_muted, false) where id = v_uid;
end;
$$;

-- Whom the caller has muted, and until when (null = for good).
create function public.my_poke_mutes()
returns table (muted uuid, until timestamptz)
language sql
security definer
set search_path = ''
stable
as $$
    select m.muted, m.until from public.poke_mutes m
     where m.muter = (select auth.uid()) and (m.until is null or m.until > now());
$$;

-- ---------------------------------------------------------------------------------------------
-- A poke once a minute per person (was once every three hours).

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
    if v_body ~* '(https?://|www\.|\m[a-z0-9-]+\.(com|cz|sk|net|org|io|me|ly|app|eu|gg)\M)' then
        raise exception 'links_not_allowed' using errcode = '22023';
    end if;
    if public.is_dnd(p_to) then
        raise exception 'do_not_disturb' using errcode = '55000';
    end if;
    if exists (select 1 from public.pokes where sender = v_uid and recipient = p_to and created_at > now() - interval '1 minute') then
        raise exception 'too_soon' using errcode = '55000';
    end if;
    perform public.check_rate(v_uid, 'poke', 120, interval '1 hour');
    insert into public.pokes (sender, recipient, body) values (v_uid, p_to, v_body) returning created_at into v_sent;
    return v_sent;
end;
$$;

create or replace function public.poke_cooldowns()
returns table (recipient uuid, available_at timestamptz)
language sql
security definer
set search_path = ''
stable
as $$
    select p.recipient, max(p.created_at) + interval '1 minute'
      from public.pokes p
     where p.sender = (select auth.uid()) and p.created_at > now() - interval '1 minute'
     group by p.recipient;
$$;

drop table public.declined_requests;

-- The bell needs to know who did it, so a poke can be muted right from its notification.
drop function public.my_notifications(timestamptz);
create function public.my_notifications(p_since timestamptz)
returns table (id uuid, kind text, actor_id uuid, actor_name text, ref uuid, body text, created_at timestamptz, seen boolean)
language sql
security definer
set search_path = ''
stable
as $$
    select n.id, n.kind, n.actor, p.display_name, n.ref, n.body, n.created_at, n.seen_at is not null
      from public.notifications n
      left join public.profiles p on p.id = n.actor
     where n.recipient = (select auth.uid()) and n.created_at > coalesce(p_since, now() - interval '30 days')
     order by n.created_at desc
     limit 100;
$$;

do $$
declare f text;
begin
    foreach f in array array['mute_pokes(uuid, int)', 'set_pokes_muted(boolean)', 'my_poke_mutes()', 'my_notifications(timestamptz)'] loop
        execute format('revoke all on function public.%s from public, anon', f);
        execute format('grant execute on function public.%s to authenticated', f);
    end loop;
end $$;
