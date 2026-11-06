-- Witness, buddy, challenges, groups and shared activities. Runs in CI against a local copy of the database.
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
select public.create_profile('Jana', 2000, 1, true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
select public.create_profile('Petr', 1999, 5, true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000c3","role":"authenticated"}',true);
select public.create_profile('Eva', 1998, 7, true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
select public.send_friend_request('00000000-0000-0000-0000-0000000000b2');
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
select public.respond_friend_request('00000000-0000-0000-0000-0000000000a1', true);
do $$
declare x uuid; ch uuid; g uuid; act uuid; today date := (now() at time zone 'Europe/Prague')::date;
begin
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 perform public.request_witness('00000000-0000-0000-0000-0000000000b2', '11111111-1111-1111-1111-111111111111', 'Gym', today);
 begin perform public.request_witness('00000000-0000-0000-0000-0000000000c3', gen_random_uuid(), 'Gym', today); insert into out values ('witness_stranger','ok'); exception when others then insert into out values ('witness_stranger',sqlerrm); end;

 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 select (public.my_witnessing() -> 'to_answer' -> 0 ->> 'id')::uuid into x;
 insert into out select 'witness_inbox', public.my_witnessing() -> 'to_answer' -> 0 ->> 'title';
 perform public.answer_witness(x, true);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 insert into out select 'witness_result', public.my_witnessing() -> 'mine' -> 0 ->> 'status';

 insert into out select 'buddy_request', public.request_buddy('00000000-0000-0000-0000-0000000000b2');
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 perform public.respond_buddy('00000000-0000-0000-0000-0000000000a1', true);
 perform public.push_day(today, 2, 3);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 insert into out select 'buddy_day', (public.my_buddy() -> 0 ->> 'state') || '/' || (public.my_buddy() -> 0 ->> 'done');
 begin perform public.request_buddy('00000000-0000-0000-0000-0000000000b2'); insert into out values ('buddy_second','ok'); exception when others then insert into out values ('buddy_second',sqlerrm); end;


 ch := public.create_challenge('30 tréninků', 'gym', 30, 30, array['00000000-0000-0000-0000-0000000000b2']::uuid[]);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 perform public.respond_challenge(ch, true);
 perform public.push_challenge_progress(ch, 12);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 insert into out select 'challenge', (select string_agg(m ->> 'name' || ':' || (m ->> 'progress'), ',' order by (m ->> 'progress')::int desc)
                                   from jsonb_array_elements(public.my_challenges() -> 0 -> 'members') m);

 g := public.create_group('Rodina', array['00000000-0000-0000-0000-0000000000b2']::uuid[]);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 insert into out select 'group_invited', public.my_groups() -> 0 ->> 'my_status';
 perform public.respond_group(g, true);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 perform public.leave_group(g);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 insert into out select 'group_ended', jsonb_array_length(public.my_groups())::text;

 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 act := public.create_activity('Běh', 'sport', now() + interval '2 days', 60, array['00000000-0000-0000-0000-0000000000b2']::uuid[]);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 perform public.respond_activity(act, true);
 insert into out select 'activity', (public.my_activities() -> 0 ->> 'title') || '/' || (public.my_activities() -> 0 ->> 'my_status');
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 begin perform public.create_activity('Běh', 'sport', now() - interval '1 day', 60, array['00000000-0000-0000-0000-0000000000b2']::uuid[]); insert into out values ('activity_past','ok'); exception when others then insert into out values ('activity_past',sqlerrm); end;

 perform public.remove_friend('00000000-0000-0000-0000-0000000000b2');
end $$;
reset role;
insert into out select 'after_removal', (select count(*) from public.witness_requests) || '/' || (select count(*) from public.buddies);

select is((select result from out where step = 'witness_stranger'), 'not_found', 'only a friend can be a witness');
select is((select result from out where step = 'witness_inbox'), 'Gym', 'the witness sees what to confirm');
select is((select result from out where step = 'witness_result'), 'confirmed', 'the owner sees the confirmation');
select is((select result from out where step = 'buddy_request'), 'requested', 'a buddy can be asked');
select is((select result from out where step = 'buddy_day'), 'paired/2', 'buddies see each other''s day');
select is((select result from out where step = 'buddy_second'), 'already_paired', 'one buddy per person');
select is((select result from out where step = 'challenge'), 'Petr:12,Jana:0', 'challenge members see each other''s progress');
select is((select result from out where step = 'group_invited'), 'invited', 'an invited friend sees the group');
select is((select result from out where step = 'group_ended'), '0', 'the group ends when the owner leaves');
select is((select result from out where step = 'activity'), 'Běh/accepted', 'an accepted activity is listed');
select is((select result from out where step = 'activity_past'), 'invalid_activity', 'an activity cannot be in the past');
select is((select result from out where step = 'after_removal'), '0/0', 'ending a friendship removes the witness requests and the buddy pair');

select * from finish();
rollback;
