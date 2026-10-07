-- The notes bucket had INSERT/UPDATE policies open to the public role, so anyone with the
-- publishable key could upload or overwrite any object (avatars, wallpapers, notes).
-- Replace them with authenticated, path-scoped policies matching what the app writes:
--   <uuid>.jpg                 partner note
--   archive/<uuid>.jpg         archived drawing
--   <couple_id>/<uuid>.jpg     couple memory photo
--   solo/<user_id>/<uuid>.jpg  memory photo before pairing
-- wallpaper/ and avatars/ keep their own dedicated policies.

drop policy if exists "Allow uploads to notes bucket" on storage.objects;
drop policy if exists "Allow updates to notes bucket" on storage.objects;

create policy "Users can upload notes, drawings and memory photos"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'notes'
  and (
    (storage.foldername(name))[1] is null
    or (storage.foldername(name))[1] = 'archive'
    or (
      (storage.foldername(name))[1] = 'solo'
      and lower((storage.foldername(name))[2]) = lower(auth.uid()::text)
    )
    or lower((storage.foldername(name))[1]) in (
      select lower(c.id::text) from public.couples c
      where auth.uid() in (c.user1_id, c.user2_id)
    )
  )
);

-- The app writes avatar paths with uppercase UUIDs; auth.uid()::text is lowercase.
drop policy if exists "Users can upload own avatar" on storage.objects;
drop policy if exists "Users can update own avatar" on storage.objects;
drop policy if exists "Users can delete own avatar" on storage.objects;

create policy "Users can upload own avatar"
on storage.objects for insert to authenticated
with check (bucket_id = 'notes' and lower(name) = 'avatars/' || lower(auth.uid()::text) || '.jpg');

create policy "Users can update own avatar"
on storage.objects for update to authenticated
using (bucket_id = 'notes' and lower(name) = 'avatars/' || lower(auth.uid()::text) || '.jpg')
with check (bucket_id = 'notes' and lower(name) = 'avatars/' || lower(auth.uid()::text) || '.jpg');

create policy "Users can delete own avatar"
on storage.objects for delete to authenticated
using (bucket_id = 'notes' and lower(name) = 'avatars/' || lower(auth.uid()::text) || '.jpg');
