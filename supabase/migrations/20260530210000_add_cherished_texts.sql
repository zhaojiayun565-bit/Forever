-- Cherished Texts: couple-scoped screenshot messages synced between partners.

create table public.cherished_texts (
    id uuid primary key default gen_random_uuid(),
    couple_id uuid not null references public.couples (id) on delete cascade,
    creator_id uuid not null references auth.users (id) on delete cascade,
    image_url text not null,
    extracted_text text not null default '',
    created_at timestamptz not null default now()
);

create index cherished_texts_couple_id_idx on public.cherished_texts (couple_id);
create index cherished_texts_created_at_idx on public.cherished_texts (created_at desc);

alter table public.cherished_texts enable row level security;

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

-- Storage bucket for screenshot images (path: {couple_id}/{text_id}.jpg).
insert into storage.buckets (id, name, public)
values ('cherished_texts_images', 'cherished_texts_images', true)
on conflict (id) do nothing;

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

-- Broadcast INSERT/DELETE over Realtime so both partners refresh immediately.
alter publication supabase_realtime add table public.cherished_texts;
