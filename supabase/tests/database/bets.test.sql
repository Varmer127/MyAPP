-- Bets for points between friends. Runs in CI against a local copy of the database.
begin;
select plan(11);

create temp table out(step text primary key, result text);
create temp table ids(name text primary key, id uuid);
grant all on out, ids to authenticated;
insert into auth.users (id, instance_id, aud, role, email) values
 ('00000000-0000-0000-0000-0000000000a1','00000000-0000-0000-0000-000000000000','authenticated','authenticated','a@test.invalid'),
 ('00000000-0000-0000-0000-0000000000b2','00000000-0000-0000-0000-000000000000','authenticated','authenticated','b@test.invalid'),
 ('00000000-0000-0000-0000-0000000000c3','00000000-0000-0000-0000-000000000000','authenticated','authenticated','c@test.invalid');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
select public.create_profile('Jana', 2000, 1, true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
select public.create_profile('Petr', 1999, 5, true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000c3","role":"authenticated"}',true);
select public.create_profile('Eva', 1998, 7, true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
select public.send_friend_request('00000000-0000-0000-0000-0000000000b2');
select public.send_friend_request('00000000-0000-0000-0000-0000000000c3');
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
select public.respond_friend_request('00000000-0000-0000-0000-0000000000a1', true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000c3","role":"authenticated"}',true);
select public.respond_friend_request('00000000-0000-0000-0000-0000000000a1', true);
do $$
declare v uuid; w uuid; d uuid;
begin
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 begin perform public.create_bet('goal', 'Bench 100 kg', null, 100, 365, array['00000000-0000-0000-0000-0000000000b2']::uuid[]); insert into out values ('low_stake','ok'); exception when others then insert into out values ('low_stake',sqlerrm); end;

 v := public.create_bet('goal', 'Bench 100 kg', 'Kdo prohraje, vaří', 300, 365, array['00000000-0000-0000-0000-0000000000b2','00000000-0000-0000-0000-0000000000c3']::uuid[]);
 insert into ids values ('goal', v);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 perform public.respond_bet(v, true);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000c3","role":"authenticated"}',true);
 perform public.respond_bet(v, false);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 perform public.claim_bet(v);
 begin perform public.judge_bet(v, true); insert into out values ('self_judge','ok'); exception when others then insert into out values ('self_judge',sqlerrm); end;

 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 perform public.judge_bet(v, true);
 insert into out select 'my_bets_count', jsonb_array_length(public.my_bets())::text;

 d := public.create_bet('goal', 'Maraton', null, 200, 30, array['00000000-0000-0000-0000-0000000000b2']::uuid[]);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 perform public.respond_bet(d, true);
 perform public.claim_bet(d);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 perform public.judge_bet(d, false);
 insert into ids values ('dispute', d);

 w := public.create_bet('week', '', null, 250, 0, array['00000000-0000-0000-0000-0000000000b2']::uuid[]);
 insert into ids values ('week', w);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 perform public.respond_bet(w, true);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000c3","role":"authenticated"}',true);
 begin perform public.create_bet('week', '', null, 250, 0, array['00000000-0000-0000-0000-0000000000b2']::uuid[]); insert into out values ('stranger_bet','ok'); exception when others then insert into out values ('stranger_bet',sqlerrm); end;

end $$;
reset role;
insert into out select 'goal_result', status || '/' || (winner = '00000000-0000-0000-0000-0000000000b2')::text from public.bets where id = (select id from ids where name = 'goal');
insert into out select 'dispute', status from public.bets where id = (select id from ids where name = 'dispute');
insert into public.week_snapshots (user_id, week_start, reliability, done, total)
select user_id, (select week_start from public.bets where id = (select id from ids where name = 'week')), case when user_id = '00000000-0000-0000-0000-0000000000a1' then 90 else 70 end, 3, 4
  from public.bet_participants where bet_id = (select id from ids where name = 'week');
update public.bets set ends_at = now() - interval '1 minute' where id = (select id from ids where name = 'week');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
select public.my_bets();
reset role;
insert into out select 'week_result', status || '/' || (winner = '00000000-0000-0000-0000-0000000000a1')::text from public.bets where id = (select id from ids where name = 'week');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
do $$
declare x uuid;
begin
 x := public.create_bet('goal', 'Kliky', null, 200, 10, array['00000000-0000-0000-0000-0000000000c3']::uuid[]);
 insert into ids values ('removal', x);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000c3","role":"authenticated"}',true);
 perform public.respond_bet(x, true);
 perform public.remove_friend('00000000-0000-0000-0000-0000000000a1');
end $$;
reset role;
insert into out select 'removal_refund', status from public.bets where id = (select id from ids where name = 'removal');
insert into out select 'week_title', title from public.bets where id = (select id from ids where name = 'week');

select is((select result from out where step = 'low_stake'), 'stake_too_low', 'the lowest stake is 200 points');
select is((select result from out where step = 'self_judge'), 'not_found', 'nobody judges their own claim');
select is((select result from out where step = 'goal_result'), 'settled/true', 'a confirmed claim wins the goal bet');
select is((select result from out where step = 'my_bets_count'), '1', 'the participants see the bet');
select is((select result from out where step = 'dispute'), 'refunded', 'a dispute refunds everybody');
select is((select result from out where step = 'stranger_bet'), 'not_found', 'bets are only between friends');
select is((select result from out where step = 'week_result'), 'settled/true', 'the higher reliability wins the week bet');
select is((select result from out where step = 'removal_refund'), 'refunded', 'ending a friendship refunds open bets');
select is((select result from out where step = 'week_title'), 'Kdo bude mít tento týden vyšší spolehlivost', 'a week bet gets its title');
select is((select count(*)::int from public.bet_participants where status = 'declined'), 1, 'a declined invitation is recorded');
select is((select count(*)::int from public.bets where status = 'open'), 0, 'no bet is left open in this test');

select * from finish();
rollback;
