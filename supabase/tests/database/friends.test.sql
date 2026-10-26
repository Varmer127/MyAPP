-- Friends, blocking, reporting and the limits around them. Runs in CI against a local copy of the database.
begin;
select plan(24);

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
do $$
declare ja record; pe record; ev record; code text; r text;
begin
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 select 'x' into r;
 select handle_number, invite_code into ja from public.profiles where id='00000000-0000-0000-0000-0000000000a1';
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 insert into out select 'find_by_handle', count(*)::text from public.find_profile('jana#'||ja.handle_number);
 insert into out select 'find_by_code', count(*)::text from public.find_profile(ja.invite_code);
 insert into out select 'find_name_only', count(*)::text from public.find_profile('Jana');
 insert into out select 'find_self', count(*)::text from public.find_profile('petr#'||(select handle_number from public.profiles where id='00000000-0000-0000-0000-0000000000b2'));
 insert into out select 'request', public.send_friend_request('00000000-0000-0000-0000-0000000000a1');
 begin perform public.send_friend_request('00000000-0000-0000-0000-0000000000a1'); insert into out values ('request_twice','ok'); exception when others then insert into out values ('request_twice',sqlerrm); end;
 insert into out select 'b_sees_outgoing', count(*)::text from public.my_requests() where direction='outgoing';
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 insert into out select 'a_sees_incoming', display_name||'/'||initial||'/'||direction from public.my_requests();
 begin perform public.respond_friend_request('00000000-0000-0000-0000-0000000000c3', true); insert into out values ('accept_wrong','ok'); exception when others then insert into out values ('accept_wrong',sqlerrm); end;
 perform public.respond_friend_request('00000000-0000-0000-0000-0000000000b2', true);
 insert into out select 'a_friends', string_agg(handle,',') from public.my_friends();
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 insert into out select 'b_friends', count(*)::text from public.my_friends();
 begin perform public.send_friend_request('00000000-0000-0000-0000-0000000000a1'); insert into out values ('already_friends','ok'); exception when others then insert into out values ('already_friends',sqlerrm); end;
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000c3","role":"authenticated"}',true);
 insert into out select 'c_sees_friendships', count(*)::text from public.friendships;
 insert into out select 'c_sends_a', public.send_friend_request('00000000-0000-0000-0000-0000000000a1');
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 perform public.block_user('00000000-0000-0000-0000-0000000000c3');
 insert into out select 'blocked_pending_gone', count(*)::text from public.my_requests();
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000c3","role":"authenticated"}',true);
 begin perform public.send_friend_request('00000000-0000-0000-0000-0000000000a1'); insert into out values ('blocked_rerequest','ok'); exception when others then insert into out values ('blocked_rerequest',sqlerrm); end;
 insert into out select 'blocked_cannot_find', count(*)::text from public.find_profile('jana#'||ja.handle_number);
 begin perform public.report_user('00000000-0000-0000-0000-0000000000a1','abuse','test'); insert into out values ('report','ok'); exception when others then insert into out values ('report',sqlerrm); end;
 begin perform public.report_user('00000000-0000-0000-0000-0000000000a1','nonsense','test'); insert into out values ('report_bad','ok'); exception when others then insert into out values ('report_bad',left(sqlerrm,40)); end;
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 perform public.remove_friend('00000000-0000-0000-0000-0000000000a1');
 insert into out select 'removed', count(*)::text from public.my_friends();
 begin insert into public.friendships values ('00000000-0000-0000-0000-0000000000a1','00000000-0000-0000-0000-0000000000b2','00000000-0000-0000-0000-0000000000a1','accepted',now(),now()); insert into out values ('direct','ok'); exception when others then insert into out values ('direct','refused'); end;
 begin perform count(*) from public.reports; insert into out values ('reports_read','ok'); exception when others then insert into out values ('reports_read','refused'); end;
end $$;
reset role;

update public.profiles set suspended_at = now() where id = '00000000-0000-0000-0000-0000000000b2';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
do $$ begin
 begin perform public.find_profile('abc#1234'); insert into out values ('suspended','ok'); exception when others then insert into out values ('suspended',sqlerrm); end;
 begin perform public.send_friend_request('00000000-0000-0000-0000-0000000000a1'); insert into out values ('suspended_request','ok'); exception when others then insert into out values ('suspended_request',sqlerrm); end;
end $$;
reset role;

select is((select result from out where step = 'find_by_handle'), '1', 'a person is found by the whole identifier');
select is((select result from out where step = 'find_by_code'), '1', 'a person is found by the code from the QR code');
select is((select result from out where step = 'find_name_only'), '0', 'a bare name finds nobody');
select is((select result from out where step = 'find_self'), '0', 'nobody finds themselves');
select is((select result from out where step = 'request'), 'requested', 'a request is created');
select is((select result from out where step = 'request_twice'), 'already_requested', 'the same request cannot be sent twice');
select is((select result from out where step = 'b_sees_outgoing'), '1', 'the sender sees the open request');
select matches((select result from out where step = 'a_sees_incoming'), '^Petr/P/incoming', 'the receiver sees only name and initial');
select is((select result from out where step = 'accept_wrong'), 'not_found', 'only a real request can be accepted');
select matches((select result from out where step = 'a_friends'), '^Petr#', 'friends are listed with their identifier');
select is((select result from out where step = 'b_friends'), '1', 'the friendship is mutual');
select is((select result from out where step = 'already_friends'), 'already_friends', 'friends cannot ask again');
select is((select result from out where step = 'c_sees_friendships'), '0', 'strangers see no friendships');
select is((select result from out where step = 'c_sends_a'), 'requested', 'a request from a third person');
select is((select result from out where step = 'blocked_pending_gone'), '0', 'blocking removes pending requests');
select is((select result from out where step = 'blocked_rerequest'), 'not_found', 'a blocked person cannot ask again');
select is((select result from out where step = 'blocked_cannot_find'), '0', 'a blocked person cannot find the blocker');
select is((select result from out where step = 'report'), 'ok', 'reporting works');
select is((select result from out where step = 'removed'), '0', 'removing a friend ends the friendship');
select is((select result from out where step = 'direct'), 'refused', 'friendships cannot be written directly');
select is((select result from out where step = 'reports_read'), 'refused', 'people cannot read the reports');
select is((select result from out where step = 'suspended_request'), 'suspended', 'a suspended account cannot send requests');
select is((select result from out where step = 'suspended'), 'suspended', 'a suspended account is refused');
select is((select count(*)::int from public.reports), 1, 'the report was stored for the moderator');

select * from finish();
rollback;
