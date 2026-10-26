-- Access rules and age gate of the account tables. Runs in CI against a local copy of the database.
-- The work is done as a signed-in user and recorded in a temp table; the assertions are made as the owner.
begin;
select plan(14);

insert into auth.users (id, instance_id, aud, role, email) values
    ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'a@test.invalid'),
    ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'b@test.invalid');

create temp table outcome (step text primary key, result text);
grant all on outcome to authenticated, anon;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
do $$
declare y int := extract(year from now())::int;
begin
    begin perform public.create_profile('Mladý', y - 15, 1, true); insert into outcome values ('young', 'ok'); exception when others then insert into outcome values ('young', sqlerrm); end;
    begin perform public.create_profile('Jana', y - 20, 1, false); insert into outcome values ('terms', 'ok'); exception when others then insert into outcome values ('terms', sqlerrm); end;
    begin perform public.create_profile('', y - 20, 1, true); insert into outcome values ('empty', 'ok'); exception when others then insert into outcome values ('empty', sqlerrm); end;
    begin perform public.create_profile('Jana', y - 20, 1, true); insert into outcome values ('adult', 'ok'); exception when others then insert into outcome values ('adult', sqlerrm); end;
    begin perform public.create_profile('Jana', y - 20, 1, true); insert into outcome values ('twice', 'ok'); exception when others then insert into outcome values ('twice', sqlerrm); end;
    begin perform public.rename_profile('Hanka'); insert into outcome values ('rename1', 'ok'); exception when others then insert into outcome values ('rename1', sqlerrm); end;
    begin perform public.rename_profile('Eva'); insert into outcome values ('rename2', 'ok'); exception when others then insert into outcome values ('rename2', sqlerrm); end;
    insert into outcome select 'own_rows', count(*)::text from public.profiles;
end $$;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
do $$
begin
    insert into outcome select 'foreign_rows', count(*)::text from public.profiles;
    begin
        insert into public.profiles values ('00000000-0000-0000-0000-0000000000b2', 'X', 1234, now(), now(), null, now());
        insert into outcome values ('direct_insert', 'ok');
    exception when others then insert into outcome values ('direct_insert', 'refused'); end;
end $$;

set local role anon;
do $$
begin
    begin perform public.server_time(); insert into outcome values ('anon_time', 'ok'); exception when others then insert into outcome values ('anon_time', 'refused'); end;
end $$;
reset role;

select is((select result from outcome where step = 'young'), 'too_young', 'a 15-year-old is turned away');
select is((select result from outcome where step = 'terms'), 'terms_required', 'terms must be accepted');
select is((select result from outcome where step = 'empty'), 'invalid_name', 'an empty name is refused');
select is((select result from outcome where step = 'adult'), 'ok', 'an adult gets a profile');
select is((select result from outcome where step = 'twice'), 'profile_exists', 'a second profile is refused');
select is((select result from outcome where step = 'rename1'), 'ok', 'renaming works');
select is((select result from outcome where step = 'rename2'), 'renamed_too_recently', 'renaming twice in a week is refused');
select is((select result from outcome where step = 'own_rows'), '1', 'a person reads their own profile');
select is((select result from outcome where step = 'foreign_rows'), '0', 'a person does not read other profiles');
select is((select result from outcome where step = 'direct_insert'), 'refused', 'the table cannot be written directly');
select is((select result from outcome where step = 'anon_time'), 'refused', 'signed-out callers cannot use the functions');
select is((select handle_number between 1000 and 9999 from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), true, 'the number is four digits');
select is((select display_name from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), 'Hanka', 'the new name is stored');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
select public.delete_account();
reset role;
select is((select count(*)::int from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), 0, 'deleting the account removes the profile');

select * from finish();
rollback;
