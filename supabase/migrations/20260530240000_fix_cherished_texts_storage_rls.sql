-- Fix cherished_texts_images storage RLS: UUID folder names from Swift are uppercase
-- but Postgres id::text is lowercase. Also add UPDATE policy for upsert retries.

drop policy if exists "Couple members can upload cherished text images" on storage.objects;
drop policy if exists "Couple members can read cherished text images" on storage.objects;
drop policy if exists "Couple members can delete cherished text images" on storage.objects;
drop policy if exists "Couple members can update cherished text images" on storage.objects;

create policy "Couple members can upload cherished text images"
    on storage.objects
    for insert
    to authenticated
    with check (
        bucket_id = 'cherished_texts_images'
        and lower((storage.foldername(name))[1]) in (
            select lower(id::text) from public.couples
            where user1_id = auth.uid() or user2_id = auth.uid()
        )
    );

create policy "Couple members can update cherished text images"
    on storage.objects
    for update
    to authenticated
    using (
        bucket_id = 'cherished_texts_images'
        and lower((storage.foldername(name))[1]) in (
            select lower(id::text) from public.couples
            where user1_id = auth.uid() or user2_id = auth.uid()
        )
    )
    with check (
        bucket_id = 'cherished_texts_images'
        and lower((storage.foldername(name))[1]) in (
            select lower(id::text) from public.couples
            where user1_id = auth.uid() or user2_id = auth.uid()
        )
    );

create policy "Couple members can read cherished text images"
    on storage.objects
    for select
    to authenticated
    using (
        bucket_id = 'cherished_texts_images'
        and lower((storage.foldername(name))[1]) in (
            select lower(id::text) from public.couples
            where user1_id = auth.uid() or user2_id = auth.uid()
        )
    );

create policy "Couple members can delete cherished text images"
    on storage.objects
    for delete
    to authenticated
    using (
        bucket_id = 'cherished_texts_images'
        and lower((storage.foldername(name))[1]) in (
            select lower(id::text) from public.couples
            where user1_id = auth.uid() or user2_id = auth.uid()
        )
    );
