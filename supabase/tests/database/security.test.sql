-- The rules that keep strangers out: nothing open without sign-in, closed by default, safe texts, firm limits.
-- Runs in CI against a local copy of the database; a migration that opens something by mistake fails here.
begin;
select plan(17);

-- ---------------------------------------------------------------------------------------------
-- The whole "public" schema, whatever a later migration adds to it.

select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute')
              and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')), 0,
          'without sign-in no function can be called');
select is((select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity), 0,
          'every table has row level security on');
select is((select count(*)::int from information_schema.role_table_grants
            where table_schema = 'public' and grantee = 'anon'), 0,
          'without sign-in no table can be touched');
select is((select count(*)::int from information_schema.role_table_grants
            where table_schema = 'public' and grantee = 'authenticated'
              and privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')), 0,
          'the app cannot write to any table directly, only through functions');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.prosecdef
              and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')), 0,
          'every function with the owner''s rights has a fixed search path');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.prosrc ~* '\mexecute\M'
              and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')), 0,
          'no function builds SQL from text');

set local role postgres;
create table public.audit_probe (id int);
reset role;
select is(has_table_privilege('anon', 'public.audit_probe', 'select')
       or has_table_privilege('authenticated', 'public.audit_probe', 'select'), false,
          'a new table starts closed for the app');
drop table public.audit_probe;

-- ---------------------------------------------------------------------------------------------
-- Texts and limits

create temp table out(step text primary key, result text);
grant all on out to authenticated;
insert into auth.users (id, instance_id, aud, role, email) values
 ('00000000-0000-0000-0000-0000000000a1','00000000-0000-0000-0000-000000000000','authenticated','authenticated','a@test.invalid'),
 ('00000000-0000-0000-0000-0000000000b2','00000000-0000-0000-0000-000000000000','authenticated','authenticated','b@test.invalid');
set local role authenticated;
do $$
begin
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 begin perform public.create_profile('bit.ly/vyhra', 2000, 1, '0.1'); insert into out values ('name_link','ok'); exception when others then insert into out values ('name_link',sqlerrm); end;
 begin perform public.create_profile('Ja' || chr(8203) || 'na', 2000, 1, '0.1'); insert into out values ('name_zero_width','ok'); exception when others then insert into out values ('name_zero_width',sqlerrm); end;
 begin perform public.create_profile('Jana' || chr(8238) || 'x', 2000, 1, '0.1'); insert into out values ('name_turned','ok'); exception when others then insert into out values ('name_turned',sqlerrm); end;
 begin perform public.create_profile('Žaneta 👨‍👩‍👧', 2000, 1, '0.1'); insert into out values ('name_fine','ok'); exception when others then insert into out values ('name_fine',sqlerrm); end;
 begin perform public.rename_profile('www.spam.cz'); insert into out values ('rename_link','ok'); exception when others then insert into out values ('rename_link',sqlerrm); end;

 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}',true);
 perform public.create_profile('Petr', 1999, 5, '0.1');
 perform public.send_friend_request('00000000-0000-0000-0000-0000000000a1');
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',true);
 perform public.respond_friend_request('00000000-0000-0000-0000-0000000000b2', true);

 perform public.create_group('Ro' || chr(8203) || 'dina', array['00000000-0000-0000-0000-0000000000b2']::uuid[]);
 perform public.create_bet('goal', 'Kdo dřív' || chr(8238) || ' uběhne 10 km', E'Kdo prohraje,\nvaří', 200, 30, array['00000000-0000-0000-0000-0000000000b2']::uuid[]);
 perform public.set_dnd(true, 'custom', 'Jsem' || chr(8203) || ' na horách', true, 0);
 begin perform public.send_poke('00000000-0000-0000-0000-0000000000b2', 'Ahoj' || chr(8238) || '!'); insert into out values ('poke','ok'); exception when others then insert into out values ('poke',sqlerrm); end;
 begin perform public.send_poke('00000000-0000-0000-0000-0000000000b2', 'A znovu'); insert into out values ('poke_again','ok'); exception when others then insert into out values ('poke_again',sqlerrm); end;
 begin perform public.send_poke('00000000-0000-0000-0000-0000000000b2', 'mrkni na t.me/vyhra'); insert into out values ('poke_link','ok'); exception when others then insert into out values ('poke_link',sqlerrm); end;
end $$;
reset role;

do $$
begin
 perform public.check_rate('00000000-0000-0000-0000-0000000000a1', 'probe', 2, interval '1 hour');
 perform public.check_rate('00000000-0000-0000-0000-0000000000a1', 'probe', 2, interval '1 hour');
 begin perform public.check_rate('00000000-0000-0000-0000-0000000000a1', 'probe', 2, interval '1 hour'); insert into out values ('rate','ok'); exception when others then insert into out values ('rate',sqlerrm); end;
end $$;

select is((select result from out where step = 'name_link'), 'invalid_name', 'a name cannot be a link');
select is((select result from out where step = 'name_zero_width'), 'invalid_name', 'a name cannot hide a zero-width character');
select is((select result from out where step = 'name_turned'), 'invalid_name', 'a name cannot turn the text around');
select is((select result from out where step = 'name_fine'), 'ok', 'a name with Czech letters and a family emoji is fine');
select is((select result from out where step = 'rename_link'), 'invalid_name', 'renaming to a link is refused too');
select is((select name from public.groups), 'Rodina', 'a group name loses invisible characters');
select is((select title || ' / ' || terms from public.bets), 'Kdo dřív uběhne 10 km / Kdo prohraje,vaří', 'a bet loses invisible characters and new lines');
select is((select dnd_reason_text from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), 'Jsem na horách', 'a reason loses invisible characters');
select is((select string_agg(step || '=' || result, ' ' order by step) from out where step like 'poke%')
          || ' / ' || (select body from public.pokes),
          'poke=ok poke_again=too_soon poke_link=links_not_allowed / Ahoj!', 'a poke is cleaned, limited to one a minute and carries no link');
select is((select result from out where step = 'rate'), 'rate_limited', 'the limit refuses the call after the allowed number');

select * from finish();
rollback;
