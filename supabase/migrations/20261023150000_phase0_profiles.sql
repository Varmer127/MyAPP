-- Kept social layer, phase 0: profile, age gate, server time, account deletion.
-- Only allow-listed fields live here. Weight, diary, health, photos and notes never reach the server.

create table public.profiles (
    id uuid primary key references auth.users (id) on delete cascade,
    display_name text not null check (char_length(display_name) between 1 and 24),
    -- Four digits that make "Name#1234" unique even when two people pick the same name.
    handle_number smallint not null check (handle_number between 1000 and 9999),
    -- Only the fact that the age gate was passed is stored, never the birth date.
    age_confirmed_at timestamptz not null,
    terms_accepted_at timestamptz not null,
    -- When the name was last changed; used to limit renaming to once a week.
    name_changed_at timestamptz,
    created_at timestamptz not null default now()
);

create unique index profiles_handle_key on public.profiles (lower(display_name), handle_number);

alter table public.profiles enable row level security;

-- A person reads only their own profile. Friends get their own narrow view in a later phase.
create policy profiles_select_own on public.profiles
    for select to authenticated
    using (id = (select auth.uid()));

-- Writes go through the functions below only, so there is no insert, update or delete policy.

-- Current server time, so the app can compare it with the phone clock.
create function public.server_time()
returns timestamptz
language sql
stable
security invoker
set search_path = ''
as $$ select now(); $$;

-- Creates the caller's profile after the age gate. The birth year and month are used for the check and thrown away.
create function public.create_profile(p_display_name text, p_birth_year int, p_birth_month int, p_terms_accepted boolean)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := (select auth.uid());
    v_name text := btrim(p_display_name);
    v_age int;
    v_row public.profiles;
    v_try int := 0;
begin
    if v_uid is null then
        raise exception 'not_signed_in' using errcode = '28000';
    end if;
    if v_name is null or char_length(v_name) not between 1 and 24 then
        raise exception 'invalid_name' using errcode = '22023';
    end if;
    if p_terms_accepted is not true then
        raise exception 'terms_required' using errcode = '22023';
    end if;
    if p_birth_year is null or p_birth_month is null
       or p_birth_month not between 1 and 12
       or p_birth_year not between 1900 and extract(year from now())::int then
        raise exception 'invalid_birth_date' using errcode = '22023';
    end if;

    -- The day of birth is unknown, so assume the last day of the birth month: nobody under 16 gets in, a 16-year-old may wait up to a month.
    v_age := extract(year from age(current_date, (make_date(p_birth_year, p_birth_month, 1) + interval '1 month - 1 day')::date))::int;
    if v_age < 16 then
        raise exception 'too_young' using errcode = '22023';
    end if;

    if exists (select 1 from public.profiles where id = v_uid) then
        raise exception 'profile_exists' using errcode = '23505';
    end if;

    loop
        v_try := v_try + 1;
        begin
            insert into public.profiles (id, display_name, handle_number, age_confirmed_at, terms_accepted_at)
            values (v_uid, v_name, 1000 + floor(random() * 9000)::int, now(), now())
            returning * into v_row;
            return v_row;
        exception when unique_violation then
            if v_try >= 20 then
                raise exception 'handle_unavailable' using errcode = '53000';
            end if;
        end;
    end loop;
end;
$$;

-- Changes the caller's name. The number stays when it is still free for the new name, otherwise a new one is drawn.
-- Friends are linked by account, not by the written identifier, so QR codes and existing friendships keep working.
create function public.rename_profile(p_display_name text)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := (select auth.uid());
    v_name text := btrim(p_display_name);
    v_row public.profiles;
    v_try int := 0;
begin
    if v_uid is null then
        raise exception 'not_signed_in' using errcode = '28000';
    end if;
    if v_name is null or char_length(v_name) not between 1 and 24 then
        raise exception 'invalid_name' using errcode = '22023';
    end if;

    select * into v_row from public.profiles where id = v_uid for update;
    if not found then
        raise exception 'no_profile' using errcode = 'P0002';
    end if;
    if v_row.name_changed_at is not null and v_row.name_changed_at > now() - interval '7 days' then
        raise exception 'renamed_too_recently' using errcode = '55000';
    end if;

    loop
        v_try := v_try + 1;
        begin
            update public.profiles
               set display_name = v_name,
                   handle_number = case when v_try = 1 then handle_number else 1000 + floor(random() * 9000)::int end,
                   name_changed_at = now()
             where id = v_uid
            returning * into v_row;
            return v_row;
        exception when unique_violation then
            if v_try >= 20 then
                raise exception 'handle_unavailable' using errcode = '53000';
            end if;
        end;
    end loop;
end;
$$;

-- Deletes the caller's account and everything hanging off it.
create function public.delete_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := (select auth.uid());
begin
    if v_uid is null then
        raise exception 'not_signed_in' using errcode = '28000';
    end if;
    delete from auth.users where id = v_uid;
end;
$$;

revoke all on function public.server_time() from public, anon;
revoke all on function public.create_profile(text, int, int, boolean) from public, anon;
revoke all on function public.rename_profile(text) from public, anon;
revoke all on function public.delete_account() from public, anon;
grant execute on function public.server_time() to authenticated;
grant execute on function public.create_profile(text, int, int, boolean) to authenticated;
grant execute on function public.rename_profile(text) to authenticated;
grant execute on function public.delete_account() to authenticated;
