-- Sharing the week, leaderboards and reactions. Runs in CI against a local copy of the database.
begin;
select plan(12);

create temp table out(step text primary key, result text);
grant all on out to authenticated;
insert into auth.users (id, instance_id, aud, role, email) values
 ('00000000-0000-0000-0000-0000000000a1','00000000-0000-0000-0000-000000000000','authenticated','authenticated','a@test.invalid'),
 ('00000000-0000-0000-0000-0000000000b2','00000000-0000-0000-0000-000000000000','authenticated','authenticated','b@test.invalid'),
 ('00000000-0000-0000-0000-0000000000c3','00000000-0000-0000-0000-000000000000','authenticated','authenticated','c@test.invalid');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
select public.create_profile('Jana', 2000, 1, '0.1');
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
select public.create_profile('Petr', 1999, 5, '0.1');
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000c3","role":"authenticated"}',true);
select public.create_profile('Eva', 1998, 7, '0.1');
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
select public.send_friend_request('00000000-0000-0000-0000-0000000000b2');
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
select public.respond_friend_request('00000000-0000-0000-0000-0000000000a1', true);
do $$
declare w date := date_trunc('week', (now() at time zone 'Europe/Prague'))::date;
begin
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 perform public.push_week(w, 80, 4, 5, 3, 7, true, ('[{"day":"'||w||'","title":"Gym","category":"gym","status":"done"},{"day":"'||(w+2)||'","title":"Čtení","category":"reading","status":"open"},{"day":"'||(w+9)||'","title":"Mimo týden","category":"work","status":"open"}]')::jsonb);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 perform public.push_week(w, 60, 3, 5, 1, 2, true, '[]'::jsonb);
 insert into out select 'none_level', (public.friend_week('00000000-0000-0000-0000-0000000000a1', w)) ->> 'level';
 insert into out select 'none_hides', coalesce((public.friend_week('00000000-0000-0000-0000-0000000000a1', w)) ->> 'reliability', '-');
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 perform public.set_sharing('summary', true);
 perform public.push_week(w, 80, 4, 5, 3, 7, true, ('[{"day":"'||w||'","title":"Gym","category":"gym","status":"done"},{"day":"'||(w+2)||'","title":"Čtení","category":"reading","status":"open"},{"day":"'||(w+9)||'","title":"Mimo týden","category":"work","status":"open"}]')::jsonb);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 insert into out select 'summary', (public.friend_week('00000000-0000-0000-0000-0000000000a1', w)) ->> 'reliability' || '/' || coalesce((public.friend_week('00000000-0000-0000-0000-0000000000a1', w)) ->> 'tasks', '-');
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 perform public.set_sharing('plan', true);
 perform public.push_week(w, 80, 4, 5, 3, 7, true, ('[{"day":"'||w||'","title":"Gym","category":"gym","status":"done"},{"day":"'||(w+2)||'","title":"Čtení","category":"reading","status":"open"},{"day":"'||(w+9)||'","title":"Mimo týden","category":"work","status":"open"}]')::jsonb);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 insert into out select 'plan_tasks', jsonb_array_length((public.friend_week('00000000-0000-0000-0000-0000000000a1', w)) -> 'tasks')::text;
 insert into out select 'board', string_agg(display_name || ':' || reliability, ',' order by reliability desc) from public.leaderboard(w);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000c3","role":"authenticated"}',true);
 begin perform public.friend_week('00000000-0000-0000-0000-0000000000a1', w); insert into out values ('stranger_week','ok'); exception when others then insert into out values ('stranger_week',sqlerrm); end;
 begin perform public.push_week(w + 1, 50, 1, 2, 0, 0, false, '[]'::jsonb); insert into out values ('bad_week','ok'); exception when others then insert into out values ('bad_week',sqlerrm); end;

 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 insert into out select 'react_on', public.toggle_reaction('00000000-0000-0000-0000-0000000000a1', w, 'fire')::text;
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 insert into out select 'received', string_agg(sender_name || ':' || kind, ',') from public.my_reactions();
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 insert into out select 'react_off', public.toggle_reaction('00000000-0000-0000-0000-0000000000a1', w, 'fire')::text;
 perform public.toggle_reaction('00000000-0000-0000-0000-0000000000a1', w, 'clap');
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 perform public.set_sharing('plan', false);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 insert into out select 'board_opt_out', string_agg(display_name, ',') from public.leaderboard(w);
 perform public.remove_friend('00000000-0000-0000-0000-0000000000a1');
end $$;
reset role;
insert into out select 'reactions_after_removal', count(*)::text from public.reactions;

select is((select result from out where step = 'none_level'), 'none', 'nothing is shared by default');
select is((select result from out where step = 'none_hides'), '-', 'without sharing no numbers are visible');
select is((select result from out where step = 'summary'), '80/-', 'a summary shows numbers but no plan');
select is((select result from out where step = 'plan_tasks'), '2', 'the shared plan keeps only tasks of that week');
select is((select result from out where step = 'board'), 'Jana:80,Petr:60', 'the leaderboard ranks the caller and friends');
select is((select result from out where step = 'stranger_week'), 'not_found', 'strangers cannot see a week');
select is((select result from out where step = 'bad_week'), 'invalid_week', 'only real week starts are accepted');
select is((select result from out where step = 'react_on'), 'true', 'a reaction can be given');
select is((select result from out where step = 'received'), 'Petr:fire', 'the friend sees who cheered');
select is((select result from out where step = 'react_off'), 'false', 'tapping again takes the reaction back');
select is((select result from out where step = 'board_opt_out'), 'Petr', 'turning leaderboards off removes the person from them');
select is((select result from out where step = 'reactions_after_removal'), '0', 'ending the friendship removes reactions');

select * from finish();
rollback;
