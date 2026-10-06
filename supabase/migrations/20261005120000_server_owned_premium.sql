-- Premium columns are server-owned: only service_role (revenuecat-sync edge function) may write them.
-- Clients keep the broad "update own profile" policy for every other column.

create or replace function public.guard_profile_premium_columns()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    if current_user not in ('authenticated', 'anon') then
        return NEW;
    end if;

    if TG_OP = 'INSERT' then
        NEW.is_premium := false;
        NEW.premium_expires_at := null;
        NEW.premium_updated_at := now();
        return NEW;
    end if;

    if NEW.is_premium is distinct from OLD.is_premium
        or NEW.premium_expires_at is distinct from OLD.premium_expires_at
        or NEW.premium_updated_at is distinct from OLD.premium_updated_at
    then
        raise exception 'Premium status can only be changed by the server'
            using errcode = '42501';
    end if;

    return NEW;
end;
$$;

drop trigger if exists profiles_guard_premium on public.profiles;
create trigger profiles_guard_premium
    before insert or update on public.profiles
    for each row
    execute function public.guard_profile_premium_columns();

-- Clear any premium a client may have self-granted; revenuecat-sync re-derives real state on next launch.
update public.profiles
set is_premium = false,
    premium_expires_at = null,
    premium_updated_at = now()
where is_premium = true;
