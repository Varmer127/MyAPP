-- Kept: more than one buddy. Up to five accepted buddies per person; accepting one no longer cancels the
-- other open requests, and ending is per buddy.

create or replace function public.buddy_count(p_user uuid)
returns int
language sql
security definer
set search_path = ''
stable
as $$
    select count(*)::int from public.buddies where status = 'accepted' and p_user in (user_a, user_b);
$$;
revoke all on function public.buddy_count(uuid) from public, anon, authenticated;

create or replace function public.request_buddy(p_friend uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.active_user();
    v_row public.buddies;
begin
    if p_friend = v_uid or not public.are_friends(v_uid, p_friend) then
        raise exception 'not_found' using errcode = 'P0002';
    end if;
    perform public.check_rate(v_uid, 'request_buddy', 20, interval '1 hour');
    select * into v_row from public.buddies where user_a = least(v_uid, p_friend) and user_b = greatest(v_uid, p_friend);
    if found then
        if v_row.status = 'accepted' then
            raise exception 'already_paired' using errcode = '23505';
        end if;
        if v_row.requested_by <> v_uid then
            if public.buddy_count(v_uid) >= 5 or public.buddy_count(p_friend) >= 5 then
                raise exception 'buddy_limit' using errcode = '23505';
            end if;
            update public.buddies set status = 'accepted' where user_a = v_row.user_a and user_b = v_row.user_b;
            return 'accepted';
        end if;
        return 'requested';
    end if;
    if public.buddy_count(v_uid) >= 5 or public.buddy_count(p_friend) >= 5 then
        raise exception 'buddy_limit' using errcode = '23505';
    end if;
    insert into public.buddies (user_a, user_b, requested_by, status)
    values (least(v_uid, p_friend), greatest(v_uid, p_friend), v_uid, 'pending');
    return 'requested';
end;
$$;

create or replace function public.respond_buddy(p_from uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    if p_accept then
        if public.buddy_count(v_uid) >= 5 or public.buddy_count(p_from) >= 5 then
            raise exception 'buddy_limit' using errcode = '23505';
        end if;
        update public.buddies set status = 'accepted'
         where user_a = least(v_uid, p_from) and user_b = greatest(v_uid, p_from) and requested_by = p_from and status = 'pending';
        if not found then
            raise exception 'not_found' using errcode = 'P0002';
        end if;
    else
        delete from public.buddies
         where user_a = least(v_uid, p_from) and user_b = greatest(v_uid, p_from) and requested_by = p_from and status = 'pending';
    end if;
end;
$$;

drop function if exists public.end_buddy();

create function public.end_buddy(p_friend uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := public.active_user();
begin
    delete from public.buddies where user_a = least(v_uid, p_friend) and user_b = greatest(v_uid, p_friend);
end;
$$;

revoke all on function public.request_buddy(uuid) from public, anon;
revoke all on function public.respond_buddy(uuid, boolean) from public, anon;
revoke all on function public.end_buddy(uuid) from public, anon;
grant execute on function public.request_buddy(uuid) to authenticated;
grant execute on function public.respond_buddy(uuid, boolean) to authenticated;
grant execute on function public.end_buddy(uuid) to authenticated;
