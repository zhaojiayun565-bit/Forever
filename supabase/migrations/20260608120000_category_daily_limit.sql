-- Enforce one non-daily (category) question answer per couple per UTC day.

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
    v_already_answered_category_today boolean;
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

    if not v_is_daily then
        select exists (
            select 1
            from public.couple_answers ca
            join public.questions q on q.id = ca.question_id
            where ca.couple_id = v_couple.id
              and q.is_daily = false
              and ca.question_id <> p_question_id
              and (
                  (ca.partner_a_answered_at is not null
                   and (ca.partner_a_answered_at at time zone 'utc')::date = v_today)
                  or
                  (ca.partner_b_answered_at is not null
                   and (ca.partner_b_answered_at at time zone 'utc')::date = v_today)
              )
        ) into v_already_answered_category_today;

        if v_already_answered_category_today then
            raise exception 'Daily category question limit reached';
        end if;
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
