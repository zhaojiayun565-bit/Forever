-- Profiles push hook (note, drawing started, location) as a tracked trigger using the Vault-authenticated
-- invoke_apns_sync helper. Replaces the dashboard-created Database Webhook pointing at apns-sync.

do $$
declare
    t record;
begin
    for t in
        select tg.tgname
        from pg_trigger tg
        join pg_proc p on p.oid = tg.tgfoid
        where tg.tgrelid = 'public.profiles'::regclass
          and not tg.tgisinternal
          and p.proname = 'http_request'
          and encode(tg.tgargs, 'escape') like '%apns-sync%'
    loop
        execute format('drop trigger %I on public.profiles', t.tgname);
    end loop;
end;
$$;

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

drop trigger if exists profiles_push_trigger on public.profiles;
create trigger profiles_push_trigger
    after update on public.profiles
    for each row
    execute function public.notify_profile_push();
