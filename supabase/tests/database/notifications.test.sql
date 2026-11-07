-- Notifications, poking without text and spam limits. Runs in CI against a local copy of the database.
begin;
select plan(7);

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

end $$;
reset role;
delete from public.declined_requests;
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
update public.profiles set created_at = now() where id = '00000000-0000-0000-0000-0000000000a1';
delete from public.rate_events;
insert into auth.users (id, instance_id, aud, role, email)
select gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'x' || g || '@test.invalid' from generate_series(1, 6) g;
insert into public.profiles (id, display_name, handle_number, age_confirmed_at, terms_accepted_at)
select id, 'Test', 1000 + row_number() over (), now(), now() from auth.users where email like 'x%@test.invalid';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
do $$
declare t uuid; n int := 0;
begin
 for t in select p.id from public.profiles p where p.display_name = 'Test' loop
   begin perform public.send_friend_request(t); n := n + 1; exception when others then null; end;
 end loop;
 insert into out values ('new_account_limit', n::text);
end $$;
reset role;

select is((select result from out where step = 'request_note'), 'friend_request:Jana', 'a request is announced to the recipient');
select is((select result from out where step = 'after_decline'), 'already_requested', 'a declined request cannot be sent again right away');
select is((select result from out where step = 'accepted_note'), 'friend_accepted', 'the requester hears that the request was accepted');
select is((select result from out where step = 'empty_poke'), 'ok', 'a poke can be sent without text');
select is((select result from out where step = 'poke_note'), 'poke:-', 'the poke is announced');
select is((select result from out where step = 'seen'), 'true', 'notifications can be marked as seen');
select is((select result from out where step = 'new_account_limit'), '5', 'a new account sends at most 5 requests on its first day');

select * from finish();
rollback;
