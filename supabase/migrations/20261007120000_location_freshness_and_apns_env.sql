-- Distance reliability:
-- 1. location_updated_at: server-set time of each location report, so widgets can show how fresh a distance is.
-- 2. update_my_location(): single entry point for location uploads that stamps location_updated_at.
-- 3. apns_environment: which APNs host (sandbox vs production) a device token belongs to.
-- 4. Push trigger also fires on location heartbeats (stationary partner still refreshes "updated" time).

alter table public.profiles
    add column if not exists location_updated_at timestamptz,
    add column if not exists apns_environment text
        check (apns_environment in ('development', 'production'));

update public.profiles
set location_updated_at = coalesce(location_updated_at, now())
where latitude is not null and longitude is not null;

create or replace function public.update_my_location(
    p_latitude double precision,
    p_longitude double precision,
    p_battery_level integer
)
returns timestamptz
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_now timestamptz := now();
begin
    if auth.uid() is null then
        raise exception 'Not authenticated' using errcode = '42501';
    end if;
    if p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then
        raise exception 'Invalid coordinate' using errcode = '22023';
    end if;

    update public.profiles
    set latitude = p_latitude,
        longitude = p_longitude,
        battery_level = p_battery_level,
        location_updated_at = v_now
    where id = auth.uid();

    return v_now;
end;
$$;

revoke all on function public.update_my_location(double precision, double precision, integer) from public, anon;
grant execute on function public.update_my_location(double precision, double precision, integer) to authenticated;

create or replace function public.notify_profile_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if NEW.latest_note_url is not distinct from OLD.latest_note_url
        and NEW.drawing_started_at is not distinct from OLD.drawing_started_at
        and NEW.latitude is not distinct from OLD.latitude
        and NEW.longitude is not distinct from OLD.longitude
        and NEW.location_updated_at is not distinct from OLD.location_updated_at
    then
        return NEW;
    end if;

    perform public.invoke_apns_sync(jsonb_build_object(
        'table', 'profiles',
        'type', 'UPDATE',
        'record', to_jsonb(NEW),
        'old_record', to_jsonb(OLD)
    ));

    return NEW;
end;
$$;
