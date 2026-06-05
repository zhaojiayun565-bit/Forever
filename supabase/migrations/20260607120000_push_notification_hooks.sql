-- Push notification hooks: timezone, wallpaper actor, streak reminders, triggers, pg_cron.
--
-- One-time setup (Supabase Dashboard -> Project Settings -> Vault):
--   Create secrets named `supabase_project_url` (e.g. https://xxx.supabase.co)
--   and `supabase_service_role_key` (service role JWT).
-- Also enable pg_cron and pg_net extensions in Dashboard if this migration fails.

alter table public.profiles
    add column if not exists timezone text not null default 'UTC';

alter table public.couples
    add column if not exists board_wallpaper_updated_by uuid references auth.users (id);

create table if not exists public.streak_reminder_log (
    id uuid primary key default gen_random_uuid(),
    couple_id uuid not null references public.couples (id) on delete cascade,
    user_id uuid not null references auth.users (id) on delete cascade,
    reminder_date date not null,
    sent_at timestamptz not null default now(),
    unique (couple_id, user_id, reminder_date)
);

create index if not exists streak_reminder_log_user_date_idx
    on public.streak_reminder_log (user_id, reminder_date);

alter table public.streak_reminder_log enable row level security;

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema extensions;

create or replace function public.stable_hash_djb2(p_text text)
returns bigint
language plpgsql
immutable
as $$
declare
    v_hash bigint := 5381;
    v_bytes bytea;
    i int;
begin
    v_bytes := convert_to(p_text, 'UTF8');
    for i in 0 .. octet_length(v_bytes) - 1 loop
        v_hash := ((v_hash << 5) + v_hash) + get_byte(v_bytes, i);
    end loop;
    return v_hash;
end;
$$;

create or replace function public.resolve_todays_daily_question_id(
    p_couple_id uuid,
    p_date date default (now() at time zone 'UTC')::date
)
returns uuid
language plpgsql
stable
as $$
declare
    v_ids uuid[];
    v_count int;
    v_seed text;
    v_index int;
begin
    select array_agg(id order by lower(id::text))
    into v_ids
    from public.questions
    where is_daily = true;

    v_count := coalesce(array_length(v_ids, 1), 0);
    if v_count = 0 then
        return null;
    end if;

    v_seed := lower(p_couple_id::text) || to_char(p_date, 'YYYY-MM-DD');
    v_index := (public.stable_hash_djb2(v_seed) % v_count)::int + 1;
    return v_ids[v_index];
end;
$$;

create or replace function public.invoke_apns_sync(p_body jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_url text;
    v_key text;
begin
    select decrypted_secret into v_url
    from vault.decrypted_secrets
    where name = 'supabase_project_url'
    limit 1;

    select decrypted_secret into v_key
    from vault.decrypted_secrets
    where name = 'supabase_service_role_key'
    limit 1;

    if v_url is null or v_key is null then
        raise warning 'apns-sync vault secrets missing (supabase_project_url, supabase_service_role_key)';
        return;
    end if;

    perform net.http_post(
        url := rtrim(v_url, '/') || '/functions/v1/apns-sync',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || v_key
        ),
        body := p_body
    );
end;
$$;

create or replace function public.notify_couple_answer_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_a_answered boolean;
    v_b_answered boolean;
    v_is_daily boolean;
begin
    v_a_answered := NEW.partner_a_response is not null;
    v_b_answered := NEW.partner_b_response is not null;

    if v_a_answered = v_b_answered then
        return NEW;
    end if;

    select is_daily into v_is_daily
    from public.questions
    where id = NEW.question_id;

    if not coalesce(v_is_daily, false) then
        return NEW;
    end if;

    perform public.invoke_apns_sync(jsonb_build_object(
        'table', 'couple_answers',
        'type', TG_OP,
        'record', to_jsonb(NEW),
        'old_record', case when TG_OP = 'UPDATE' then to_jsonb(OLD) else '{}'::jsonb end
    ));

    return NEW;
end;
$$;

drop trigger if exists couple_answers_push_trigger on public.couple_answers;
create trigger couple_answers_push_trigger
    after insert or update on public.couple_answers
    for each row
    execute function public.notify_couple_answer_push();

create or replace function public.notify_wallpaper_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if NEW.board_wallpaper_url is not distinct from OLD.board_wallpaper_url then
        return NEW;
    end if;

    if NEW.board_wallpaper_updated_by is null then
        return NEW;
    end if;

    perform public.invoke_apns_sync(jsonb_build_object(
        'table', 'couples',
        'type', 'UPDATE',
        'record', to_jsonb(NEW),
        'old_record', to_jsonb(OLD)
    ));

    return NEW;
end;
$$;

drop trigger if exists couples_wallpaper_push_trigger on public.couples;
create trigger couples_wallpaper_push_trigger
    after update on public.couples
    for each row
    execute function public.notify_wallpaper_push();

create or replace function public.send_streak_savior_reminders()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    r record;
    v_question_id uuid;
    v_answer public.couple_answers%rowtype;
    v_local_date date;
    v_body text;
    v_partner_name text;
    v_both_null boolean;
    v_tz text;
begin
    for r in
        select
            p.id as user_id,
            p.device_token,
            p.timezone,
            c.id as couple_id
        from public.profiles p
        join public.couples c
            on c.user1_id = p.id or c.user2_id = p.id
        where p.device_token is not null
    loop
        v_tz := coalesce(nullif(trim(r.timezone), ''), 'UTC');

        if extract(hour from (now() at time zone v_tz)) != 20 then
            continue;
        end if;

        v_local_date := (now() at time zone v_tz)::date;

        if exists (
            select 1
            from public.streak_reminder_log
            where couple_id = r.couple_id
              and user_id = r.user_id
              and reminder_date = v_local_date
        ) then
            continue;
        end if;

        v_question_id := public.resolve_todays_daily_question_id(
            r.couple_id,
            (now() at time zone 'UTC')::date
        );

        if v_question_id is null then
            continue;
        end if;

        select * into v_answer
        from public.couple_answers
        where couple_id = r.couple_id
          and question_id = v_question_id;

        v_both_null := v_answer.id is null
            or (v_answer.partner_a_response is null and v_answer.partner_b_response is null);

        if v_both_null then
            v_body := '🔥 Don''t let your streak break! Today''s question is waiting for you both.';
        elsif v_answer.id is not null
            and r.user_id = v_answer.partner_a_id
            and v_answer.partner_a_response is null
        then
            select coalesce(display_name, 'Your partner') into v_partner_name
            from public.profiles
            where id = v_answer.partner_b_id;
            v_body := format(
                '💬 %s hasn''t heard your answer to today''s question yet. Tap to reply!',
                v_partner_name
            );
        elsif v_answer.id is not null
            and r.user_id = v_answer.partner_b_id
            and v_answer.partner_b_response is null
        then
            select coalesce(display_name, 'Your partner') into v_partner_name
            from public.profiles
            where id = v_answer.partner_a_id;
            v_body := format(
                '💬 %s hasn''t heard your answer to today''s question yet. Tap to reply!',
                v_partner_name
            );
        else
            continue;
        end if;

        perform public.invoke_apns_sync(jsonb_build_object(
            'mode', 'direct',
            'recipient_id', r.user_id,
            'title', 'Daily Question',
            'body', v_body,
            'type', 'streak_reminder',
            'route', 'home',
            'question_id', v_question_id
        ));

        insert into public.streak_reminder_log (couple_id, user_id, reminder_date)
        values (r.couple_id, r.user_id, v_local_date)
        on conflict do nothing;
    end loop;
end;
$$;

do $$
begin
    perform cron.unschedule('streak-savior-hourly');
exception
    when others then null;
end;
$$;

select cron.schedule(
    'streak-savior-hourly',
    '0 * * * *',
    $$ select public.send_streak_savior_reminders(); $$
);
