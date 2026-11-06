-- Kept social layer, phase 4 (first part): bets for points between friends.
-- Points never mean money. Each participant's stake is held until the bet ends: the winner takes all stakes,
-- and when nobody wins or the participants disagree, everybody gets their stake back.
-- Points are counted in the app; the server records who staked what and how each bet ended.

create table public.bets (
    id uuid primary key default gen_random_uuid(),
    creator uuid not null references auth.users (id) on delete cascade,
    -- 'week': whoever has the higher reliability this week wins (decided from the week numbers).
    -- 'goal': the first to reach a goal wins, confirmed by the others.
    kind text not null check (kind in ('week', 'goal')),
    title text not null check (char_length(title) between 1 and 80),
    -- What the participants agreed on besides points ("who loses cooks dinner"). The app only shows it.
    terms text check (char_length(terms) <= 200),
    stake int not null check (stake between 200 and 1000000),
    week_start date,
    ends_at timestamptz not null,
    status text not null default 'open' check (status in ('open', 'settled', 'refunded', 'cancelled')),
    winner uuid references auth.users (id) on delete set null,
    claimant uuid references auth.users (id) on delete set null,
    claimed_at timestamptz,
    settled_at timestamptz,
    created_at timestamptz not null default now()
);

create table public.bet_participants (
    bet_id uuid not null references public.bets (id) on delete cascade,
    user_id uuid not null references auth.users (id) on delete cascade,
    status text not null check (status in ('invited', 'accepted', 'declined')),
    responded_at timestamptz,
    -- The participant's answer to the current claim.
    verdict text check (verdict in ('confirm', 'dispute')),
    primary key (bet_id, user_id)
);
create index bet_participants_user on public.bet_participants (user_id);

alter table public.bets enable row level security;
alter table public.bet_participants enable row level security;
revoke all on public.bets, public.bet_participants from anon, authenticated;

-- Ends a bet: a winner takes the stakes, otherwise everybody is refunded.
create function public.close_bet(p_bet uuid, p_winner uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    update public.bets
       set status = case when p_winner is null then 'refunded' else 'settled' end,
           winner = p_winner, settled_at = now()
     where id = p_bet and status = 'open';
end;
$$;
revoke all on function public.close_bet(uuid, uuid) from public, anon, authenticated;

-- Bets past their end are decided when someone in them next looks: week bets by the week numbers
-- (a single highest reliability wins, a tie refunds), goal bets without a confirmed winner are refunded.
create function public.settle_due_bets(p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_bet public.bets;
    v_best int;
    v_leaders uuid[];
begin
    for v_bet in
        select b.* from public.bets b
          join public.bet_participants p on p.bet_id = b.id and p.user_id = p_user
         where b.status = 'open' and b.ends_at <= now()
    loop
        if v_bet.kind = 'week' then
            select max(s.reliability) into v_best
              from public.bet_participants p
              join public.week_snapshots s on s.user_id = p.user_id and s.week_start = v_bet.week_start
             where p.bet_id = v_bet.id and p.status = 'accepted';
            select array_agg(p.user_id) into v_leaders
              from public.bet_participants p
              join public.week_snapshots s on s.user_id = p.user_id and s.week_start = v_bet.week_start
             where p.bet_id = v_bet.id and p.status = 'accepted' and s.reliability = v_best;
            perform public.close_bet(v_bet.id, case when array_length(v_leaders, 1) = 1 then v_leaders[1] end);
        else
            perform public.close_bet(v_bet.id, null);
        end if;
    end loop;
end;
$$;
revoke all on function public.settle_due_bets(uuid) from public, anon, authenticated;

-- Ending a friendship refunds the open bets both people are in.
create function public.refund_bets_between()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_id uuid;
begin
    for v_id in
        select a.bet_id from public.bet_participants a
          join public.bet_participants b on b.bet_id = a.bet_id
          join public.bets x on x.id = a.bet_id and x.status = 'open'
         where a.user_id = old.user_a and b.user_id = old.user_b
    loop
        perform public.close_bet(v_id, null);
    end loop;
    return old;
end;
$$;
revoke all on function public.refund_bets_between() from public, anon, authenticated;
create trigger friendships_refund_bets after delete on public.friendships
    for each row execute function public.refund_bets_between();

-- ---------------------------------------------------------------------------------------------

-- p_days is the length of a goal bet (1 to 365); a week bet always runs to the end of this week.
create function public.create_bet(p_kind text, p_title text, p_terms text, p_stake int, p_days int, p_invitees uuid[])
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.active_user();
    v_id uuid;
    v_friend uuid;
    v_week date := date_trunc('week', now() at time zone 'Europe/Prague')::date;
    v_title text := btrim(p_title);
begin
    if p_kind not in ('week', 'goal') then
        raise exception 'invalid_kind' using errcode = '22023';
    end if;
    if p_stake is null or p_stake < 200 then
        raise exception 'stake_too_low' using errcode = '22023';
    end if;
    if p_invitees is null or cardinality(p_invitees) not between 1 and 9 then
        raise exception 'invalid_invitees' using errcode = '22023';
    end if;
    if p_kind = 'week' then
        v_title := coalesce(nullif(v_title, ''), 'Kdo bude mít tento týden vyšší spolehlivost');
    elsif v_title is null or v_title = '' or p_days is null or p_days not between 1 and 365 then
        raise exception 'invalid_goal' using errcode = '22023';
    end if;
    foreach v_friend in array p_invitees loop
        if v_friend = v_uid or not public.are_friends(v_uid, v_friend) then
            raise exception 'not_found' using errcode = 'P0002';
        end if;
    end loop;
    perform public.check_rate(v_uid, 'bet', 30, interval '1 day');

    insert into public.bets (creator, kind, title, terms, stake, week_start, ends_at)
    values (v_uid, p_kind, left(v_title, 80), nullif(left(btrim(coalesce(p_terms, '')), 200), ''), p_stake,
            case when p_kind = 'week' then v_week end,
            case when p_kind = 'week'
                 then ((v_week + 7)::timestamp at time zone 'Europe/Prague') + interval '12 hours'
                 else now() + make_interval(days => p_days) end)
    returning id into v_id;
    insert into public.bet_participants (bet_id, user_id, status, responded_at) values (v_id, v_uid, 'accepted', now());
    insert into public.bet_participants (bet_id, user_id, status)
    select v_id, x, 'invited' from (select distinct unnest(p_invitees) as x) i;
    return v_id;
end;
$$;

create function public.respond_bet(p_bet uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    if not exists (select 1 from public.bets where id = p_bet and status = 'open' and ends_at > now()) then
        raise exception 'not_open' using errcode = '55000';
    end if;
    update public.bet_participants
       set status = case when p_accept then 'accepted' else 'declined' end, responded_at = now()
     where bet_id = p_bet and user_id = v_uid and status = 'invited';
    if not found then
        raise exception 'not_found' using errcode = 'P0002';
    end if;
end;
$$;

-- The creator can add more friends while the bet is open, up to ten people in all.
create function public.invite_to_bet(p_bet uuid, p_invitees uuid[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.active_user();
    v_friend uuid;
begin
    if not exists (select 1 from public.bets where id = p_bet and creator = v_uid and status = 'open' and ends_at > now()) then
        raise exception 'not_found' using errcode = 'P0002';
    end if;
    foreach v_friend in array coalesce(p_invitees, '{}') loop
        if v_friend = v_uid or not public.are_friends(v_uid, v_friend) then
            raise exception 'not_found' using errcode = 'P0002';
        end if;
    end loop;
    insert into public.bet_participants (bet_id, user_id, status)
    select p_bet, x, 'invited' from (select distinct unnest(p_invitees) as x) i
    on conflict do nothing;
    if (select count(*) from public.bet_participants where bet_id = p_bet and status <> 'declined') > 10 then
        raise exception 'too_many_people' using errcode = '54000';
    end if;
end;
$$;

-- "I made it" in a goal bet. The other participants confirm or dispute.
create function public.claim_bet(p_bet uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    if not exists (select 1 from public.bet_participants where bet_id = p_bet and user_id = v_uid and status = 'accepted') then
        raise exception 'not_found' using errcode = 'P0002';
    end if;
    update public.bets set claimant = v_uid, claimed_at = now()
     where id = p_bet and kind = 'goal' and status = 'open' and ends_at > now() and claimant is null;
    if not found then
        raise exception 'not_claimable' using errcode = '55000';
    end if;
    update public.bet_participants set verdict = null where bet_id = p_bet;
end;
$$;

-- A dispute refunds everybody; when all the others confirm, the claimant wins.
create function public.judge_bet(p_bet uuid, p_confirm boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.active_user();
    v_bet public.bets;
begin
    select * into v_bet from public.bets where id = p_bet and status = 'open' and claimant is not null;
    if not found or v_bet.claimant = v_uid
       or not exists (select 1 from public.bet_participants where bet_id = p_bet and user_id = v_uid and status = 'accepted') then
        raise exception 'not_found' using errcode = 'P0002';
    end if;
    update public.bet_participants set verdict = case when p_confirm then 'confirm' else 'dispute' end
     where bet_id = p_bet and user_id = v_uid;
    if not p_confirm then
        perform public.close_bet(p_bet, null);
    elsif not exists (select 1 from public.bet_participants
                       where bet_id = p_bet and status = 'accepted' and user_id <> v_bet.claimant
                         and verdict is distinct from 'confirm') then
        perform public.close_bet(p_bet, v_bet.claimant);
    end if;
end;
$$;

-- The creator can call a bet off while nobody else has joined it.
create function public.cancel_bet(p_bet uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    if not exists (select 1 from public.bets where id = p_bet and creator = v_uid and status = 'open')
       or exists (select 1 from public.bet_participants where bet_id = p_bet and user_id <> v_uid and status = 'accepted') then
        raise exception 'not_cancellable' using errcode = '55000';
    end if;
    update public.bets set status = 'cancelled', settled_at = now() where id = p_bet;
end;
$$;

-- The caller's bets with everyone in them; bets past their end are decided first.
create function public.my_bets()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    perform public.settle_due_bets(v_uid);
    return coalesce((
        select jsonb_agg(jsonb_build_object(
            'id', b.id, 'kind', b.kind, 'title', b.title, 'terms', b.terms, 'stake', b.stake,
            'ends_at', b.ends_at, 'status', b.status, 'winner', b.winner, 'claimant', b.claimant,
            'settled_at', b.settled_at, 'created_at', b.created_at, 'is_creator', b.creator = v_uid,
            'participants', (
                select jsonb_agg(jsonb_build_object(
                    'id', p.user_id, 'name', pr.display_name, 'status', p.status,
                    'responded_at', p.responded_at, 'verdict', p.verdict, 'is_me', p.user_id = v_uid)
                    order by p.responded_at nulls last)
                  from public.bet_participants p join public.profiles pr on pr.id = p.user_id
                 where p.bet_id = b.id)
        ) order by b.created_at desc)
          from public.bets b
          join public.bet_participants me on me.bet_id = b.id and me.user_id = v_uid and me.status <> 'declined'
         where b.status = 'open' or b.settled_at > now() - interval '60 days'
    ), '[]'::jsonb);
end;
$$;

do $$
declare
    f text;
begin
    foreach f in array array[
        'create_bet(text, text, text, int, int, uuid[])', 'respond_bet(uuid, boolean)', 'invite_to_bet(uuid, uuid[])',
        'claim_bet(uuid)', 'judge_bet(uuid, boolean)', 'cancel_bet(uuid)', 'my_bets()'
    ] loop
        execute format('revoke all on function public.%s from public, anon', f);
        execute format('grant execute on function public.%s to authenticated', f);
    end loop;
end $$;
