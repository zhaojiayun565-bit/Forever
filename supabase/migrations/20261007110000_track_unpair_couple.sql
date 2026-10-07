-- unpair_couple() previously existed only in the dashboard; tracked here unchanged so new environments match.
create or replace function public.unpair_couple()
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
    v_couple_id uuid;
begin
    select id into v_couple_id
    from couples
    where user1_id = auth.uid() or user2_id = auth.uid()
    limit 1;

    if v_couple_id is null then
        return;
    end if;

    delete from drawing_strokes where couple_id = v_couple_id;
    delete from memories       where couple_id = v_couple_id;
    delete from couples        where id = v_couple_id;
end;
$$;

revoke all on function public.unpair_couple() from public, anon;
grant execute on function public.unpair_couple() to authenticated;
