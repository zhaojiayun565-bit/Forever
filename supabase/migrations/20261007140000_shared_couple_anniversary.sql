-- The anniversary lives on each profile, so partners could see different "Days Together" counts.
-- Keep both partners' anniversary_date equal:
--   * On pairing, the inviter's date (couples.user2_id, whose code was entered) wins.
--   * After that, whoever edits it updates it for both.

-- Copies an anniversary change to the partner's profile (RLS forbids clients writing it directly).
create or replace function public.sync_partner_anniversary()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if pg_trigger_depth() > 1 or NEW.anniversary_date is not distinct from OLD.anniversary_date then
        return NEW;
    end if;

    update public.profiles p
    set anniversary_date = NEW.anniversary_date
    from public.couples c
    where ((c.user1_id = NEW.id and p.id = c.user2_id)
        or (c.user2_id = NEW.id and p.id = c.user1_id))
      and p.anniversary_date is distinct from NEW.anniversary_date;

    return NEW;
end;
$$;

revoke execute on function public.sync_partner_anniversary() from public, anon, authenticated;

drop trigger if exists profiles_sync_partner_anniversary on public.profiles;
create trigger profiles_sync_partner_anniversary
after update of anniversary_date on public.profiles
for each row execute function public.sync_partner_anniversary();

-- Aligns a couple's anniversaries, preferring the inviter's (user2) date when set.
create or replace function public.align_couple_anniversary(p_user1 uuid, p_user2 uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_date timestamptz;
begin
    select coalesce(
        (select anniversary_date from public.profiles where id = p_user2),
        (select anniversary_date from public.profiles where id = p_user1)
    ) into v_date;

    if v_date is null then
        return;
    end if;

    update public.profiles
    set anniversary_date = v_date
    where id in (p_user1, p_user2)
      and anniversary_date is distinct from v_date;
end;
$$;

revoke execute on function public.align_couple_anniversary(uuid, uuid) from public, anon, authenticated;

create or replace function public.align_anniversary_on_pairing()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    perform public.align_couple_anniversary(NEW.user1_id, NEW.user2_id);
    return NEW;
end;
$$;

revoke execute on function public.align_anniversary_on_pairing() from public, anon, authenticated;

drop trigger if exists couples_align_anniversary on public.couples;
create trigger couples_align_anniversary
after insert on public.couples
for each row execute function public.align_anniversary_on_pairing();

-- Backfill existing couples.
select public.align_couple_anniversary(user1_id, user2_id) from public.couples;
