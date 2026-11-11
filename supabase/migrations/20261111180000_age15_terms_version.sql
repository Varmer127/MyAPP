-- Account age limit lowered to 15 (the Czech age of digital consent) and the accepted version of the Terms stored with the time.
-- Accepting the Terms now means sending their version; existing accounts keep an empty version (they accepted before versions existed).

alter table public.profiles add column terms_version text
    constraint profiles_terms_version_format check (terms_version is null or terms_version ~ '^[0-9]{1,3}\.[0-9]{1,3}$');

drop function public.create_profile(text, int, int, boolean);

-- Creates the caller's profile after the age gate. The birth year and month are used for the check and thrown away.
create function public.create_profile(p_display_name text, p_birth_year int, p_birth_month int, p_terms_version text)
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
    if p_terms_version is null or p_terms_version !~ '^[0-9]{1,3}\.[0-9]{1,3}$' then
        raise exception 'terms_required' using errcode = '22023';
    end if;
    if p_birth_year is null or p_birth_month is null
       or p_birth_month not between 1 and 12
       or p_birth_year not between 1900 and extract(year from now())::int then
        raise exception 'invalid_birth_date' using errcode = '22023';
    end if;

    -- The day of birth is unknown, so assume the last day of the birth month: nobody under 15 gets in, a 15-year-old may wait up to a month.
    v_age := extract(year from age(current_date, (make_date(p_birth_year, p_birth_month, 1) + interval '1 month - 1 day')::date))::int;
    if v_age < 15 then
        raise exception 'too_young' using errcode = '22023';
    end if;

    if exists (select 1 from public.profiles where id = v_uid) then
        raise exception 'profile_exists' using errcode = '23505';
    end if;

    loop
        v_try := v_try + 1;
        begin
            insert into public.profiles (id, display_name, handle_number, age_confirmed_at, terms_accepted_at, terms_version)
            values (v_uid, v_name, 1000 + floor(random() * 9000)::int, now(), now(), p_terms_version)
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

revoke all on function public.create_profile(text, int, int, text) from public, anon;
grant execute on function public.create_profile(text, int, int, text) to authenticated;
