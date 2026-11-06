-- Clean-up when a friendship ends, the nightly purge and the moderation queue. Runs in CI.
begin;
select plan(5);

create temp table ids(name text primary key, id uuid);
grant all on ids to authenticated;
insert into auth.users (id, instance_id, aud, role, email) values
 ('00000000-0000-0000-0000-0000000000a1','00000000-0000-0000-0000-000000000000','authenticated','authenticated','a@test.invalid'),
 ('00000000-0000-0000-0000-0000000000b2','00000000-0000-0000-0000-000000000000','authenticated','authenticated','b@test.invalid');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
select public.create_profile('Jana', 2000, 1, true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
select public.create_profile('Petr', 1999, 5, true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
select public.send_friend_request('00000000-0000-0000-0000-0000000000b2');
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
select public.respond_friend_request('00000000-0000-0000-0000-0000000000a1', true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
insert into ids select 'group', public.create_group('Rodina', array['00000000-0000-0000-0000-0000000000b2']::uuid[]);
insert into ids select 'challenge', public.create_challenge('Výzva', null, 10, 30, array['00000000-0000-0000-0000-0000000000b2']::uuid[]);
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
select public.respond_group((select id from ids where name = 'group'), true);
select public.respond_challenge((select id from ids where name = 'challenge'), true);
select public.report_user('00000000-0000-0000-0000-0000000000a1', 'spam', 'test');
select public.remove_friend('00000000-0000-0000-0000-0000000000a1');
reset role;

select is((select count(*)::int from public.group_members where group_id = (select id from ids where name = 'group') and user_id = '00000000-0000-0000-0000-0000000000b2'), 0,
          'ending the friendship removes the friend from the owner''s group');
select is((select count(*)::int from public.challenge_members where challenge_id = (select id from ids where name = 'challenge') and user_id = '00000000-0000-0000-0000-0000000000b2'), 0,
          'ending the friendship removes the friend from the creator''s challenge');
select is((select count(*)::int from public.moderation_queue()), 1, 'the moderator sees the open report');
select is(has_function_privilege('authenticated', 'public.moderation_queue()', 'execute'), false, 'the app cannot read the moderation queue');

insert into public.rate_events (user_id, kind, at) values ('00000000-0000-0000-0000-0000000000a1', 'old', now() - interval '5 days');
select public.purge_old_social_data();
select is((select count(*)::int from public.rate_events where kind = 'old'), 0, 'the nightly purge removes old rows');

select * from finish();
rollback;
