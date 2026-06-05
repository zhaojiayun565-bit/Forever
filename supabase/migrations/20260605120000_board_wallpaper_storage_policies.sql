-- Board wallpaper in notes bucket (path: wallpaper/{couple_id}.jpg).
-- Swift uploads uppercase UUIDs; compare with lower() like cherished_texts policies.

create policy "Couple members can upload board wallpaper"
    on storage.objects
    for insert
    to authenticated
    with check (
        bucket_id = 'notes'
        and (storage.foldername(name))[1] = 'wallpaper'
        and lower(replace(split_part(name, '/', 2), '.jpg', '')) in (
            select lower(id::text)
            from public.couples
            where auth.uid() = user1_id or auth.uid() = user2_id
        )
    );

create policy "Couple members can update board wallpaper"
    on storage.objects
    for update
    to authenticated
    using (
        bucket_id = 'notes'
        and (storage.foldername(name))[1] = 'wallpaper'
        and lower(replace(split_part(name, '/', 2), '.jpg', '')) in (
            select lower(id::text)
            from public.couples
            where auth.uid() = user1_id or auth.uid() = user2_id
        )
    )
    with check (
        bucket_id = 'notes'
        and (storage.foldername(name))[1] = 'wallpaper'
        and lower(replace(split_part(name, '/', 2), '.jpg', '')) in (
            select lower(id::text)
            from public.couples
            where auth.uid() = user1_id or auth.uid() = user2_id
        )
    );

create policy "Couple members can read board wallpaper"
    on storage.objects
    for select
    to authenticated
    using (
        bucket_id = 'notes'
        and (storage.foldername(name))[1] = 'wallpaper'
        and lower(replace(split_part(name, '/', 2), '.jpg', '')) in (
            select lower(id::text)
            from public.couples
            where auth.uid() = user1_id or auth.uid() = user2_id
        )
    );
