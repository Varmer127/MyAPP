-- Kept social layer, phase 5: getting ready for the App Store.
-- Indexes the database advisor asked for, a fuller clean-up when a friendship ends,
-- a daily removal of old social data, and a moderation queue for the dashboard.

-- ---------------------------------------------------------------------------------------------
-- Indexes on foreign keys: deleting an account scans these columns.

create index if not exists activities_creator on public.activities (creator);
create index if not exists bets_creator on public.bets (creator);
create index if not exists bets_winner on public.bets (winner);
create index if not exists bets_claimant on public.bets (claimant);
create index if not exists buddies_user_b on public.buddies (user_b);
create index if not exists buddies_requested_by on public.buddies (requested_by);
create index if not exists challenges_creator on public.challenges (creator);
create index if not exists friendships_requested_by on public.friendships (requested_by);
create index if not exists groups_owner on public.groups (owner);
create index if not exists reports_reported on public.reports (reported);
create index if not exists reports_reporter on public.reports (reporter);

alter table public.rate_events add column id bigint generated always as identity primary key;

-- ---------------------------------------------------------------------------------------------
-- Ending a friendship now also takes each person out of the other's groups and challenges.

create or replace function public.remove_together_between()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    delete from public.witness_requests
     where (owner = old.user_a and witness = old.user_b) or (owner = old.user_b and witness = old.user_a);
    delete from public.buddies where user_a = old.user_a and user_b = old.user_b;
    delete from public.group_members m using public.groups g
     where m.group_id = g.id
       and ((g.owner = old.user_a and m.user_id = old.user_b) or (g.owner = old.user_b and m.user_id = old.user_a));
    delete from public.challenge_members m using public.challenges c
     where m.challenge_id = c.id
       and ((c.creator = old.user_a and m.user_id = old.user_b) or (c.creator = old.user_b and m.user_id = old.user_a));
    return old;
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Old social data is removed every night. Nothing here is needed after these times.

create function public.purge_old_social_data()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    delete from public.rate_events where at < now() - interval '2 days';
    delete from public.pokes where created_at < now() - interval '30 days';
    delete from public.reactions where created_at < now() - interval '30 days';
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
revoke all on function public.purge_old_social_data() from public, anon, authenticated;

create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule('kept-purge-old-social-data', '17 3 * * *', 'select public.purge_old_social_data()');

-- ---------------------------------------------------------------------------------------------
-- Moderation, for the dashboard's SQL editor only (never callable from the app).

create function public.moderation_queue()
returns table (report_id uuid, created_at timestamptz, reason text, note text,
               reporter text, reported_id uuid, reported text, reports_against int,
               suspended boolean, poke_banned boolean)
language sql
security definer
set search_path = ''
stable
as $$
    select r.id, r.created_at, r.reason, r.note,
           rp.display_name || '#' || rp.handle_number,
           r.reported, dp.display_name || '#' || dp.handle_number,
           (select count(*)::int from public.reports x where x.reported = r.reported),
           dp.suspended_at is not null, dp.poke_banned_at is not null
      from public.reports r
      left join public.profiles rp on rp.id = r.reporter
      left join public.profiles dp on dp.id = r.reported
     where r.status = 'open'
     order by r.created_at;
$$;
revoke all on function public.moderation_queue() from public, anon, authenticated;
