-- Questions feature: categories, questions, couple answers, streak tracking.

-- 1. Categories
create table public.question_categories (
    id uuid primary key default gen_random_uuid(),
    title text not null,
    description text,
    icon_name text,
    is_premium boolean not null default false,
    sort_order integer not null default 0
);

-- 2. Questions
create table public.questions (
    id uuid primary key default gen_random_uuid(),
    category_id uuid not null references public.question_categories (id) on delete cascade,
    question_text text not null,
    is_daily boolean not null default false
);

-- 3. Couple answers (one row per couple + question)
create table public.couple_answers (
    id uuid primary key default gen_random_uuid(),
    couple_id uuid not null references public.couples (id) on delete cascade,
    question_id uuid not null references public.questions (id) on delete cascade,

    partner_a_id uuid not null references auth.users (id),
    partner_a_response text,
    partner_a_answered_at timestamptz,

    partner_b_id uuid not null references auth.users (id),
    partner_b_response text,
    partner_b_answered_at timestamptz,

    unique (couple_id, question_id)
);

create index couple_answers_couple_id_idx on public.couple_answers (couple_id);
create index couple_answers_question_id_idx on public.couple_answers (question_id);
create index questions_category_id_idx on public.questions (category_id);
create index questions_is_daily_idx on public.questions (is_daily) where is_daily = true;

-- 4. Streak column on couples
alter table public.couples
    add column if not exists questions_streak_count integer not null default 0;

-- RLS: question_categories (read-only catalog)
alter table public.question_categories enable row level security;

create policy "Authenticated users can read question categories"
    on public.question_categories
    for select
    to authenticated
    using (true);

-- RLS: questions (read-only catalog)
alter table public.questions enable row level security;

create policy "Authenticated users can read questions"
    on public.questions
    for select
    to authenticated
    using (true);

-- RLS: couple_answers (read via membership; writes via RPC only)
alter table public.couple_answers enable row level security;

create policy "Couple members can read couple answers"
    on public.couple_answers
    for select
    to authenticated
    using (
        couple_id in (
            select id from public.couples
            where user1_id = auth.uid() or user2_id = auth.uid()
        )
    );

-- RPC: submit a partner's answer securely
create or replace function public.submit_question_answer(
    p_question_id uuid,
    p_response text
)
returns public.couple_answers
language plpgsql
security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
    v_couple public.couples%rowtype;
    v_answer public.couple_answers%rowtype;
    v_is_daily boolean;
    v_today date := (now() at time zone 'utc')::date;
    v_yesterday date := v_today - 1;
    v_both_answered_today boolean;
    v_yesterday_completed boolean;
begin
    if v_uid is null then
        raise exception 'Not authenticated';
    end if;

    if trim(p_response) = '' then
        raise exception 'Response cannot be empty';
    end if;

    select * into v_couple
    from public.couples
    where user1_id = v_uid or user2_id = v_uid
    order by created_at asc
    limit 1;

    if not found then
        raise exception 'No couple found for user';
    end if;

    select is_daily into v_is_daily
    from public.questions
    where id = p_question_id;

    if not found then
        raise exception 'Question not found';
    end if;

    insert into public.couple_answers (
        couple_id,
        question_id,
        partner_a_id,
        partner_b_id,
        partner_a_response,
        partner_a_answered_at,
        partner_b_response,
        partner_b_answered_at
    )
    values (
        v_couple.id,
        p_question_id,
        v_couple.user1_id,
        v_couple.user2_id,
        case when v_uid = v_couple.user1_id then trim(p_response) else null end,
        case when v_uid = v_couple.user1_id then now() else null end,
        case when v_uid = v_couple.user2_id then trim(p_response) else null end,
        case when v_uid = v_couple.user2_id then now() else null end
    )
    on conflict (couple_id, question_id) do update set
        partner_a_response = case
            when v_uid = v_couple.user1_id then trim(p_response)
            else couple_answers.partner_a_response
        end,
        partner_a_answered_at = case
            when v_uid = v_couple.user1_id then now()
            else couple_answers.partner_a_answered_at
        end,
        partner_b_response = case
            when v_uid = v_couple.user2_id then trim(p_response)
            else couple_answers.partner_b_response
        end,
        partner_b_answered_at = case
            when v_uid = v_couple.user2_id then now()
            else couple_answers.partner_b_answered_at
        end
    returning * into v_answer;

    -- Update streak when both partners complete a daily question today
    if v_is_daily
        and v_answer.partner_a_answered_at is not null
        and v_answer.partner_b_answered_at is not null
        and (v_answer.partner_a_answered_at at time zone 'utc')::date = v_today
        and (v_answer.partner_b_answered_at at time zone 'utc')::date = v_today
    then
        select exists (
            select 1
            from public.couple_answers ca
            join public.questions q on q.id = ca.question_id
            where ca.couple_id = v_couple.id
              and q.is_daily = true
              and ca.question_id <> p_question_id
              and ca.partner_a_answered_at is not null
              and ca.partner_b_answered_at is not null
              and (ca.partner_a_answered_at at time zone 'utc')::date = v_yesterday
              and (ca.partner_b_answered_at at time zone 'utc')::date = v_yesterday
        ) into v_yesterday_completed;

        update public.couples
        set questions_streak_count = case
            when v_yesterday_completed then questions_streak_count + 1
            else 1
        end
        where id = v_couple.id;
    end if;

    return v_answer;
end;
$$;

grant execute on function public.submit_question_answer(uuid, text) to authenticated;

-- Realtime for instant reveal when partner answers
alter publication supabase_realtime add table public.couple_answers;

-- Seed categories
insert into public.question_categories (title, description, icon_name, sort_order) values
('The Daily Spark', 'Light and fun questions to keep the connection strong every day.', 'sparkles', 1),
('Deep Dive', 'Explore your relationship, values, and dreams together.', 'heart.text.square', 2),
('Would You Rather', 'Quick, fun, and sometimes ridiculous choices.', 'arrow.left.arrow.right', 3),
('Looking Back', 'Reminisce about your favorite memories and milestones.', 'clock.arrow.circlepath', 4);

-- Seed daily questions
insert into public.questions (category_id, question_text, is_daily)
select id, 'What is a small thing I did this week that made you smile?', true from public.question_categories where title = 'The Daily Spark'
union all
select id, 'What is something you are looking forward to this weekend?', true from public.question_categories where title = 'The Daily Spark'
union all
select id, 'If you could instantly transport us anywhere for dinner tonight, where are we going?', true from public.question_categories where title = 'The Daily Spark'
union all
select id, 'What is a song that always reminds you of me?', true from public.question_categories where title = 'The Daily Spark'
union all
select id, 'What is the best part of waking up next to each other?', true from public.question_categories where title = 'The Daily Spark';

-- Seed Deep Dive questions
insert into public.questions (category_id, question_text, is_daily)
select id, 'What is a dream or goal you have not shared with me yet?', false from public.question_categories where title = 'Deep Dive'
union all
select id, 'When do you feel most loved and appreciated by me?', false from public.question_categories where title = 'Deep Dive'
union all
select id, 'What is a habit we have as a couple that you absolutely love?', false from public.question_categories where title = 'Deep Dive'
union all
select id, 'In what ways do you think we balance each other out?', false from public.question_categories where title = 'Deep Dive'
union all
select id, 'What is a fear you have about our future, and how can I support you?', false from public.question_categories where title = 'Deep Dive';

-- Seed Would You Rather questions
insert into public.questions (category_id, question_text, is_daily)
select id, 'Would you rather we have a personal chef or a live-in housekeeper?', false from public.question_categories where title = 'Would You Rather'
union all
select id, 'Would you rather always have to sing instead of speaking, or dance everywhere you go?', false from public.question_categories where title = 'Would You Rather'
union all
select id, 'Would you rather plan a detailed vacation itinerary or wing it entirely?', false from public.question_categories where title = 'Would You Rather'
union all
select id, 'Would you rather lose the ability to lie to me, or have me lose the ability to lie to you?', false from public.question_categories where title = 'Would You Rather'
union all
select id, 'Would you rather never be able to eat sweet foods again, or never eat savory foods again?', false from public.question_categories where title = 'Would You Rather';

-- Seed Looking Back questions
insert into public.questions (category_id, question_text, is_daily)
select id, 'What was your exact first impression of me?', false from public.question_categories where title = 'Looking Back'
union all
select id, 'When was the exact moment you realized you had feelings for me?', false from public.question_categories where title = 'Looking Back'
union all
select id, 'What is your favorite memory from our first year together?', false from public.question_categories where title = 'Looking Back'
union all
select id, 'What was the funniest disaster or mishap we have experienced on a date?', false from public.question_categories where title = 'Looking Back'
union all
select id, 'Which outfit of mine from when we first started dating do you remember the most?', false from public.question_categories where title = 'Looking Back';
