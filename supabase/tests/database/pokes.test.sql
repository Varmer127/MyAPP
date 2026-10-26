-- Pokes and "do not disturb". Runs in CI against a local copy of the database.
begin;
select plan(16);

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
declare poke uuid;
begin
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 begin perform public.send_poke('00000000-0000-0000-0000-0000000000b2', '  Hej, jak jde slib?  '); insert into out values ('poke1','ok'); exception when others then insert into out values ('poke1',sqlerrm); end;
 begin perform public.send_poke('00000000-0000-0000-0000-0000000000b2', 'Ještě jednou'); insert into out values ('poke_again','ok'); exception when others then insert into out values ('poke_again',sqlerrm); end;
 begin perform public.send_poke('00000000-0000-0000-0000-0000000000c3', 'Ahoj'); insert into out values ('poke_stranger','ok'); exception when others then insert into out values ('poke_stranger',sqlerrm); end;
 begin perform public.send_poke('00000000-0000-0000-0000-0000000000b2', '   '); insert into out values ('poke_empty','ok'); exception when others then insert into out values ('poke_empty',sqlerrm); end;
 begin perform public.send_poke('00000000-0000-0000-0000-0000000000b2', repeat('x', 101)); insert into out values ('poke_long','ok'); exception when others then insert into out values ('poke_long',sqlerrm); end;
 begin perform public.send_poke('00000000-0000-0000-0000-0000000000b2', 'mrkni na https://example.com'); insert into out values ('poke_link','ok'); exception when others then insert into out values ('poke_link',sqlerrm); end;
 begin perform public.send_poke('00000000-0000-0000-0000-0000000000b2', 'viz kept.cz'); insert into out values ('poke_domain','ok'); exception when others then insert into out values ('poke_domain',sqlerrm); end;

 insert into out select 'cooldown_rows', count(*)::text from public.poke_cooldowns();
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 insert into out select 'inbox', body||'/'||sender_name||'/'||seen::text from public.pokes_inbox();
 perform public.mark_pokes_seen();
 insert into out select 'inbox_seen', seen::text from public.pokes_inbox();
 perform public.set_dnd(true, 'custom', 'Jsem na horách a bez signálu', true, 0);
 insert into out select 'dnd_self', dnd_active::text from public.profiles where id = '00000000-0000-0000-0000-0000000000b2';
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 insert into out select 'friend_sees_dnd', dnd::text||'/'||coalesce(dnd_reason_text,'-') from public.my_friends();
 begin perform public.send_poke('00000000-0000-0000-0000-0000000000b2', 'Nerušit?'); insert into out values ('poke_dnd','ok'); exception when others then insert into out values ('poke_dnd',sqlerrm); end;

 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 begin perform public.set_dnd(true, 'custom', 'jedna dva tři čtyři pět šest sedm', true, 0); insert into out values ('dnd_seven_words','ok'); exception when others then insert into out values ('dnd_seven_words',sqlerrm); end;
 perform public.set_dnd(true, 'work', null, false, 0);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 insert into out select 'reason_hidden', dnd::text||'/'||coalesce(dnd_reason_key,'-') from public.my_friends();
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 perform public.set_dnd(false, null, null, false, 0);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 insert into out select 'dnd_off', dnd::text from public.my_friends();
end $$;
reset role;

-- Move the first poke back in time so the 3-hour wait is over, then poke again and report it.
update public.pokes set created_at = now() - interval '4 hours';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
do $$
begin
 begin perform public.send_poke('00000000-0000-0000-0000-0000000000b2', 'Zase já, nedáš to?'); insert into out values ('poke_after_wait','ok'); exception when others then insert into out values ('poke_after_wait',sqlerrm); end;

end $$;
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
do $$
declare v_id uuid;
begin
 select id into v_id from public.pokes_inbox() order by created_at desc limit 1;
 perform public.report_poke(v_id, 'abuse');
 insert into out select 'reported_hidden', count(*)::text from public.pokes_inbox() where id = v_id;
end $$;
reset role;
update public.profiles set poke_banned_at = now() where id = '00000000-0000-0000-0000-0000000000a1';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
do $$
begin
 begin perform public.send_poke('00000000-0000-0000-0000-0000000000b2', 'Ještě jedno'); insert into out values ('poke_banned','ok'); exception when others then insert into out values ('poke_banned',sqlerrm); end;

end $$;
reset role;

select is((select result from out where step = 'poke1'), 'ok', 'a friend can be poked with own text');
select is((select result from out where step = 'poke_again'), 'too_soon', 'the same person cannot be poked twice within 3 hours');
select is((select result from out where step = 'poke_stranger'), 'not_found', 'only friends can be poked');
select is((select result from out where step = 'poke_empty'), 'invalid_text', 'an empty text is refused');
select is((select result from out where step = 'poke_long'), 'invalid_text', 'a text over 100 characters is refused');
select is((select result from out where step = 'poke_link'), 'links_not_allowed', 'links are refused');
select is((select result from out where step = 'poke_domain'), 'links_not_allowed', 'a bare web address is refused');
select is((select result from out where step = 'cooldown_rows'), '1', 'the sender sees who is still waiting');
select is((select result from out where step = 'inbox'), 'Hej, jak jde slib?/Jana/false', 'the recipient sees the text, the name and that it is new');
select is((select result from out where step = 'inbox_seen'), 'true', 'a poke can be marked as seen');
select is((select result from out where step = 'friend_sees_dnd'), 'true/Jsem na horách a bez signálu', 'friends see do-not-disturb with a shared reason');
select is((select result from out where step = 'poke_dnd'), 'do_not_disturb', 'nobody can poke someone who is not to be disturbed');
select is((select result from out where step = 'dnd_seven_words'), 'invalid_reason', 'a reason longer than six words is refused');
select is((select result from out where step = 'reason_hidden'), 'true/-', 'an unshared reason stays hidden');
select is((select result from out where step = 'reported_hidden') || '/' || (select result from out where step = 'poke_banned'), '0/poke_banned', 'a reported poke disappears and a banned sender cannot poke');
select is((select count(*)::int from public.reports where reason = 'abuse' and note like 'poke:%'), 1, 'the report carries the poke text for the moderator');

select * from finish();
rollback;
