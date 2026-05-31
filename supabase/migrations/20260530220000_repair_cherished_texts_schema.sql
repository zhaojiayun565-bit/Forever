-- Idempotent repair for cherished_texts when the table was created manually
-- or before the full migration was applied (e.g. missing creator_id).

create table if not exists public.cherished_texts (
    id uuid primary key default gen_random_uuid(),
    couple_id uuid not null references public.couples (id) on delete cascade,
    image_url text not null,
    extracted_text text not null default '',
    created_at timestamptz not null default now()
);

alter table public.cherished_texts
    add column if not exists creator_id uuid references auth.users (id) on delete cascade;

alter table public.cherished_texts
    add column if not exists extracted_text text not null default '';

-- Backfill creator_id for legacy rows missing it.
update public.cherished_texts ct
set creator_id = c.user1_id
from public.couples c
where ct.couple_id = c.id
  and ct.creator_id is null;

alter table public.cherished_texts
    alter column creator_id set not null;

create index if not exists cherished_texts_couple_id_idx
    on public.cherished_texts (couple_id);

create index if not exists cherished_texts_created_at_idx
    on public.cherished_texts (created_at desc);

alter table public.cherished_texts enable row level security;

do $$
begin
    create policy "Couple members can read cherished texts"
        on public.cherished_texts
        for select
        to authenticated
        using (
            couple_id in (
                select id from public.couples
                where user1_id = auth.uid() or user2_id = auth.uid()
            )
        );
exception
    when duplicate_object then null;
end $$;

do $$
begin
    create policy "Couple members can insert cherished texts"
        on public.cherished_texts
        for insert
        to authenticated
        with check (
            creator_id = auth.uid()
            and couple_id in (
                select id from public.couples
                where user1_id = auth.uid() or user2_id = auth.uid()
            )
        );
exception
    when duplicate_object then null;
end $$;

do $$
begin
    create policy "Couple members can delete cherished texts"
        on public.cherished_texts
        for delete
        to authenticated
        using (
            couple_id in (
                select id from public.couples
                where user1_id = auth.uid() or user2_id = auth.uid()
            )
        );
exception
    when duplicate_object then null;
end $$;

insert into storage.buckets (id, name, public)
values ('cherished_texts_images', 'cherished_texts_images', true)
on conflict (id) do nothing;

do $$
begin
    create policy "Couple members can upload cherished text images"
        on storage.objects
        for insert
        to authenticated
        with check (
            bucket_id = 'cherished_texts_images'
            and (storage.foldername(name))[1] in (
                select id::text from public.couples
                where user1_id = auth.uid() or user2_id = auth.uid()
            )
        );
exception
    when duplicate_object then null;
end $$;

do $$
begin
    create policy "Couple members can read cherished text images"
        on storage.objects
        for select
        to authenticated
        using (
            bucket_id = 'cherished_texts_images'
            and (storage.foldername(name))[1] in (
                select id::text from public.couples
                where user1_id = auth.uid() or user2_id = auth.uid()
            )
        );
exception
    when duplicate_object then null;
end $$;

do $$
begin
    create policy "Couple members can delete cherished text images"
        on storage.objects
        for delete
        to authenticated
        using (
            bucket_id = 'cherished_texts_images'
            and (storage.foldername(name))[1] in (
                select id::text from public.couples
                where user1_id = auth.uid() or user2_id = auth.uid()
            )
        );
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter publication supabase_realtime add table public.cherished_texts;
exception
    when duplicate_object then null;
end $$;
