-- Account deletion support: let auth.users deletes cascade cleanly, and expose a
-- service-role-only listing of the storage objects that belong to an account.

alter table public.couple_answers
    drop constraint if exists couple_answers_partner_a_id_fkey,
    drop constraint if exists couple_answers_partner_b_id_fkey;

alter table public.couple_answers
    add constraint couple_answers_partner_a_id_fkey
        foreign key (partner_a_id) references auth.users (id) on delete cascade,
    add constraint couple_answers_partner_b_id_fkey
        foreign key (partner_b_id) references auth.users (id) on delete cascade;

alter table public.couples
    drop constraint if exists couples_board_wallpaper_updated_by_fkey;

alter table public.couples
    add constraint couples_board_wallpaper_updated_by_fkey
        foreign key (board_wallpaper_updated_by) references auth.users (id) on delete set null;

-- Objects uploaded by the user, plus everything under their couple's folder (shared data is
-- wiped with the couple, matching unpair_couple).
create or replace function public.account_storage_objects(p_user_id uuid)
returns table (bucket_id text, name text)
language sql
stable
security definer
set search_path = public, storage
as $$
    select o.bucket_id, o.name
    from storage.objects o
    where o.owner_id = p_user_id::text
       or exists (
           select 1
           from public.couples c
           where (c.user1_id = p_user_id or c.user2_id = p_user_id)
             and split_part(o.name, '/', 1) = c.id::text
       );
$$;

revoke all on function public.account_storage_objects(uuid) from public, anon, authenticated;
grant execute on function public.account_storage_objects(uuid) to service_role;
