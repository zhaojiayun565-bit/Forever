-- Pairing was a direct client INSERT into couples, guarded only by "caller is a member".
-- Anyone could pair themselves with any user id (no code needed), users could be in several
-- couples, and members could rewrite user ids on their couple. Pairing now goes through
-- pair_with_code(), which checks the code, rate-limits guesses, and enforces one couple per user.

-- One couple per user, regardless of how the row is written.
create or replace function public.enforce_single_couple()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if exists (
        select 1 from public.couples c
        where c.id <> NEW.id
          and (c.user1_id in (NEW.user1_id, NEW.user2_id) or c.user2_id in (NEW.user1_id, NEW.user2_id))
    ) then
        raise exception 'already_paired';
    end if;
    return NEW;
end;
$$;

revoke execute on function public.enforce_single_couple() from public, anon, authenticated;

drop trigger if exists couples_enforce_single_couple on public.couples;
create trigger couples_enforce_single_couple
before insert or update of user1_id, user2_id on public.couples
for each row execute function public.enforce_single_couple();

-- Failed code attempts, for rate limiting.
create table if not exists public.pairing_attempts (
    user_id uuid not null references auth.users(id) on delete cascade,
    attempted_at timestamptz not null default now()
);
create index if not exists pairing_attempts_user_time on public.pairing_attempts (user_id, attempted_at desc);
alter table public.pairing_attempts enable row level security;
revoke all on public.pairing_attempts from anon, authenticated;

-- Pairs the caller with the owner of p_code. Returns the couple, or no rows when the code is wrong.
-- Raises already_paired / partner_already_paired / too_many_attempts.
create or replace function public.pair_with_code(p_code text)
returns setof public.couples
language plpgsql
security definer
set search_path = public
as $$
declare
    v_caller uuid := auth.uid();
    v_partner uuid;
    v_couple public.couples;
begin
    if v_caller is null then
        raise exception 'not_authenticated';
    end if;

    if (select count(*) from public.pairing_attempts
        where user_id = v_caller and attempted_at > now() - interval '1 hour') >= 10 then
        raise exception 'too_many_attempts';
    end if;

    select p.id into v_partner
    from public.profiles p
    where p.pairing_code is not null
      and p.pairing_code = trim(p_code)
      and p.id <> v_caller
    limit 1;

    if v_partner is null then
        insert into public.pairing_attempts (user_id) values (v_caller);
        return;
    end if;

    -- Serialize concurrent pairings involving either user (fixed order avoids deadlocks).
    perform pg_advisory_xact_lock(hashtextextended(least(v_caller, v_partner)::text, 0));
    perform pg_advisory_xact_lock(hashtextextended(greatest(v_caller, v_partner)::text, 0));

    select * into v_couple from public.couples c
    where (c.user1_id = v_caller and c.user2_id = v_partner)
       or (c.user1_id = v_partner and c.user2_id = v_caller)
    order by c.created_at
    limit 1;
    if found then
        return next v_couple;
        return;
    end if;

    if exists (select 1 from public.couples c where v_caller in (c.user1_id, c.user2_id)) then
        raise exception 'already_paired';
    end if;
    if exists (select 1 from public.couples c where v_partner in (c.user1_id, c.user2_id)) then
        raise exception 'partner_already_paired';
    end if;

    insert into public.couples (user1_id, user2_id)
    values (v_caller, v_partner)
    returning * into v_couple;

    delete from public.pairing_attempts where user_id = v_caller;
    return next v_couple;
end;
$$;

revoke execute on function public.pair_with_code(text) from public, anon;
grant execute on function public.pair_with_code(text) to authenticated;

-- Clients no longer insert couples or look up user ids by code directly.
drop policy if exists "Users can insert couple when they are a member" on public.couples;
revoke execute on function public.find_partner_by_pairing_code(text) from public, anon, authenticated;

-- Members may only change the board wallpaper columns.
revoke update on public.couples from anon, authenticated;
grant update (board_wallpaper_url, board_wallpaper_updated_by) on public.couples to authenticated;
