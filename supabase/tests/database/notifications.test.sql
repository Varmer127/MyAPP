-- Notifications, poking without text and spam limits. Runs in CI against a local copy of the database.
begin;
select plan(8);

create temp table out(step text primary key, result text);
grant all on out to authenticated;
insert into auth.users (id, instance_id, aud, role, email) values
 ('00000000-0000-0000-0000-0000000000a1','00000000-0000-0000-0000-000000000000','authenticated','authenticated','a@test.invalid'),
 ('00000000-0000-0000-0000-0000000000b2','00000000-0000-0000-0000-000000000000','authenticated','authenticated','b@test.invalid');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
select public.create_profile('Jana', 2000, 1, true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
select public.create_profile('Petr', 1999, 5, true);
do $$
begin
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 perform public.send_friend_request('00000000-0000-0000-0000-0000000000b2');
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 insert into out select 'request_note', string_agg(kind || ':' || actor_name, ',') from public.my_notifications(null);
 perform public.respond_friend_request('00000000-0000-0000-0000-0000000000a1', false);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 begin perform public.send_friend_request('00000000-0000-0000-0000-0000000000b2'); insert into out values ('after_decline','ok'); exception when others then insert into out values ('after_decline',sqlerrm); end;
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 perform public.respond_friend_request('00000000-0000-0000-0000-0000000000a1', false);

end $$;
reset role;
delete from public.rate_events;
set local role authenticated;
do $$
begin
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 perform public.send_friend_request('00000000-0000-0000-0000-0000000000b2');
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 perform public.respond_friend_request('00000000-0000-0000-0000-0000000000a1', true);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 insert into out select 'accepted_note', string_agg(kind, ',' order by created_at) from public.my_notifications(null);
 begin perform public.send_poke('00000000-0000-0000-0000-0000000000b2', ''); insert into out values ('empty_poke','ok'); exception when others then insert into out values ('empty_poke',sqlerrm); end;

 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 insert into out select 'poke_note', (select kind || ':' || coalesce(body, '-') from public.my_notifications(null) where kind = 'poke');
 perform public.mark_notifications_seen();
 insert into out select 'seen', bool_and(seen)::text from public.my_notifications(null);
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
select public.mute_pokes('00000000-0000-0000-0000-0000000000a1', 7);
reset role;
delete from public.pokes;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
do $$
begin
 perform public.send_poke('00000000-0000-0000-0000-0000000000b2', 'ztlumeno');
 begin perform public.send_poke('00000000-0000-0000-0000-0000000000b2', 'hned znovu'); insert into out values ('minute','ok'); exception when others then insert into out values ('minute',sqlerrm); end;
end $$;
reset role;
insert into out select 'muted', count(*)::text from public.notifications where recipient = '00000000-0000-0000-0000-0000000000b2' and body = 'ztlumeno';

select is((select result from out where step = 'request_note'), 'friend_request:Jana', 'a request is announced to the recipient');
select is((select result from out where step = 'after_decline'), 'ok', 'a declined request can be sent again');
select is((select result from out where step = 'accepted_note'), 'friend_accepted', 'the requester hears that the request was accepted');
select is((select result from out where step = 'empty_poke'), 'ok', 'a poke can be sent without text');
select is((select result from out where step = 'poke_note'), 'poke:-', 'the poke is announced');
select is((select result from out where step = 'seen'), 'true', 'notifications can be marked as seen');
select is((select result from out where step = 'minute'), 'too_soon', 'the same person can be poked once a minute');
select is((select result from out where step = 'muted'), '0', 'a muted poke makes no notification');

select * from finish();
rollback;
