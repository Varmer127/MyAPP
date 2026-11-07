-- Kept social layer: notifications, poking without text, and stronger protection against spam.
-- Every event a person should hear about lands in one table. The app shows it in the bell and,
-- until real push arrives (Apple Developer account), as a local notification when iOS lets the app check.

create table public.notifications (
    id uuid primary key default gen_random_uuid(),
    recipient uuid not null references auth.users (id) on delete cascade,
    actor uuid references auth.users (id) on delete cascade,
    kind text not null check (kind in (
        'friend_request', 'friend_accepted', 'poke', 'reaction',
        'bet_invite', 'bet_claim', 'bet_result',
        'challenge_invite', 'group_invite', 'activity_invite',
        'buddy_request', 'buddy_accepted', 'witness_request', 'witness_answer')),
    -- What it is about (a bet, a challenge...), when there is one.
    ref uuid,
    body text check (char_length(body) <= 200),
    created_at timestamptz not null default now(),
    seen_at timestamptz
);
create index notifications_recipient on public.notifications (recipient, created_at desc);
create index notifications_actor on public.notifications (actor);
alter table public.notifications enable row level security;
revoke all on public.notifications from anon, authenticated;

create function public.notify(p_recipient uuid, p_actor uuid, p_kind text, p_ref uuid, p_body text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    if p_recipient is null or p_recipient = p_actor then
        return;
    end if;
    insert into public.notifications (recipient, actor, kind, ref, body) values (p_recipient, p_actor, p_kind, p_ref, left(p_body, 200));
end;
$$;
revoke all on function public.notify(uuid, uuid, text, uuid, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- Triggers turn changes into notifications, so the functions people call stay as they are.

create function public.notify_friendships()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_other uuid;
begin
    v_other := case when new.requested_by = new.user_a then new.user_b else new.user_a end;
    if tg_op = 'INSERT' and new.status = 'pending' then
        perform public.notify(v_other, new.requested_by, 'friend_request', null, null);
    elsif tg_op = 'UPDATE' and old.status = 'pending' and new.status = 'accepted' then
        perform public.notify(new.requested_by, v_other, 'friend_accepted', null, null);
    end if;
    return new;
end;
$$;
create trigger friendships_notify after insert or update on public.friendships
    for each row execute function public.notify_friendships();

create function public.notify_pokes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    perform public.notify(new.recipient, new.sender, 'poke', new.id, nullif(new.body, ''));
    return new;
end;
$$;
create trigger pokes_notify after insert on public.pokes
    for each row execute function public.notify_pokes();

create function public.notify_reactions()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    perform public.notify(new.recipient, new.sender, 'reaction', null, new.kind);
    return new;
end;
$$;
create trigger reactions_notify after insert on public.reactions
    for each row execute function public.notify_reactions();

create function public.notify_bet_participants()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if new.status = 'invited' then
        perform public.notify(new.user_id, (select creator from public.bets where id = new.bet_id), 'bet_invite', new.bet_id,
                              (select title from public.bets where id = new.bet_id));
    end if;
    return new;
end;
$$;
create trigger bet_participants_notify after insert on public.bet_participants
    for each row execute function public.notify_bet_participants();

create function public.notify_bets()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_user uuid;
begin
    if new.claimant is not null and old.claimant is null then
        for v_user in select user_id from public.bet_participants where bet_id = new.id and status = 'accepted' and user_id <> new.claimant loop
            perform public.notify(v_user, new.claimant, 'bet_claim', new.id, new.title);
        end loop;
    end if;
    if old.status = 'open' and new.status <> 'open' then
        for v_user in select user_id from public.bet_participants where bet_id = new.id and status = 'accepted' loop
            perform public.notify(v_user, new.winner, 'bet_result', new.id, new.title);
        end loop;
    end if;
    return new;
end;
$$;
create trigger bets_notify after update on public.bets
    for each row execute function public.notify_bets();

create function public.notify_invites()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if new.status <> 'invited' then
        return new;
    end if;
    if tg_table_name = 'challenge_members' then
        perform public.notify(new.user_id, (select creator from public.challenges where id = new.challenge_id), 'challenge_invite',
                              new.challenge_id, (select title from public.challenges where id = new.challenge_id));
    elsif tg_table_name = 'group_members' then
        perform public.notify(new.user_id, (select owner from public.groups where id = new.group_id), 'group_invite',
                              new.group_id, (select name from public.groups where id = new.group_id));
    elsif tg_table_name = 'activity_members' then
        perform public.notify(new.user_id, (select creator from public.activities where id = new.activity_id), 'activity_invite',
                              new.activity_id, (select title from public.activities where id = new.activity_id));
    end if;
    return new;
end;
$$;
create trigger challenge_members_notify after insert on public.challenge_members for each row execute function public.notify_invites();
create trigger group_members_notify after insert on public.group_members for each row execute function public.notify_invites();
create trigger activity_members_notify after insert on public.activity_members for each row execute function public.notify_invites();

create function public.notify_buddies()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_other uuid;
begin
    v_other := case when new.requested_by = new.user_a then new.user_b else new.user_a end;
    if tg_op = 'INSERT' and new.status = 'pending' then
        perform public.notify(v_other, new.requested_by, 'buddy_request', null, null);
    elsif tg_op = 'UPDATE' and old.status = 'pending' and new.status = 'accepted' then
        perform public.notify(new.requested_by, v_other, 'buddy_accepted', null, null);
    end if;
    return new;
end;
$$;
create trigger buddies_notify after insert or update on public.buddies
    for each row execute function public.notify_buddies();

create function public.notify_witness()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if new.status = 'pending' and (tg_op = 'INSERT' or old.status <> 'pending' or old.witness <> new.witness) then
        perform public.notify(new.witness, new.owner, 'witness_request', new.id, new.title);
    elsif tg_op = 'UPDATE' and old.status = 'pending' and new.status in ('confirmed', 'rejected') then
        perform public.notify(new.owner, new.witness, 'witness_answer', new.id, new.status || ':' || new.title);
    end if;
    return new;
end;
$$;
create trigger witness_requests_notify after insert or update on public.witness_requests
    for each row execute function public.notify_witness();

do $$
declare f text;
begin
    foreach f in array array['notify_friendships()', 'notify_pokes()', 'notify_reactions()', 'notify_bet_participants()',
                             'notify_bets()', 'notify_invites()', 'notify_buddies()', 'notify_witness()'] loop
        execute format('revoke all on function public.%s from public, anon, authenticated', f);
    end loop;
end $$;

-- What the caller should hear about, newest first (optionally only since a moment).
create function public.my_notifications(p_since timestamptz)
returns table (id uuid, kind text, actor_name text, ref uuid, body text, created_at timestamptz, seen boolean)
language sql
security definer
set search_path = ''
stable
as $$
    select n.id, n.kind, p.display_name, n.ref, n.body, n.created_at, n.seen_at is not null
      from public.notifications n
      left join public.profiles p on p.id = n.actor
     where n.recipient = (select auth.uid()) and n.created_at > coalesce(p_since, now() - interval '30 days')
     order by n.created_at desc
     limit 100;
$$;

create function public.mark_notifications_seen()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    update public.notifications set seen_at = now() where recipient = v_uid and seen_at is null;
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Poking without text: the poke itself is the message.

alter table public.pokes drop constraint pokes_body_check;
alter table public.pokes add constraint pokes_body_check check (char_length(body) between 0 and 100);

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
    if exists (select 1 from public.pokes where sender = v_uid and recipient = p_to and created_at > now() - interval '3 hours') then
        raise exception 'too_soon' using errcode = '55000';
    end if;
    perform public.check_rate(v_uid, 'poke', 120, interval '1 hour');
    insert into public.pokes (sender, recipient, body) values (v_uid, p_to, v_body) returning created_at into v_sent;
    return v_sent;
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Spam: a declined request cannot be sent again for 30 days, and a brand-new account
-- (first 24 hours) can send only 5 requests.

create table public.declined_requests (
    requester uuid not null references auth.users (id) on delete cascade,
    recipient uuid not null references auth.users (id) on delete cascade,
    declined_at timestamptz not null default now(),
    primary key (requester, recipient)
);
create index declined_requests_recipient on public.declined_requests (recipient);
alter table public.declined_requests enable row level security;
revoke all on public.declined_requests from anon, authenticated;

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
    if not p_accept then
        insert into public.declined_requests (requester, recipient) values (p_from, v_uid)
        on conflict (requester, recipient) do update set declined_at = now();
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
    if exists (select 1 from public.declined_requests
                where requester = v_uid and recipient = p_target and declined_at > now() - interval '30 days') then
        -- The same answer as for a request still waiting, so a decline is not announced.
        raise exception 'already_requested' using errcode = '23505';
    end if;
    if (select created_at from public.profiles where id = v_uid) > now() - interval '24 hours' then
        perform public.check_rate(v_uid, 'friend_request_new', 5, interval '24 hours');
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

-- The nightly clean-up also removes old notifications and declined requests.
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
    delete from public.declined_requests where declined_at < now() - interval '30 days';
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

do $$
declare f text;
begin
    foreach f in array array['my_notifications(timestamptz)', 'mark_notifications_seen()'] loop
        execute format('revoke all on function public.%s from public, anon', f);
        execute format('grant execute on function public.%s to authenticated', f);
    end loop;
end $$;
