-- Legacy cherished_texts tables used author_id; keep it in sync with creator_id on write.
update public.cherished_texts
set author_id = creator_id
where author_id is distinct from creator_id;

create or replace function public.sync_cherished_texts_author_id()
returns trigger
language plpgsql
as $$
begin
    if new.creator_id is not null then
        new.author_id := new.creator_id;
    elsif new.author_id is not null then
        new.creator_id := new.author_id;
    end if;
    return new;
end;
$$;

drop trigger if exists cherished_texts_sync_author_creator on public.cherished_texts;

create trigger cherished_texts_sync_author_creator
    before insert or update on public.cherished_texts
    for each row
    execute function public.sync_cherished_texts_author_id();
