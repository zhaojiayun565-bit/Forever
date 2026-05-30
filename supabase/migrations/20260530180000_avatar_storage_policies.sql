-- Avatar profile photos in the notes bucket (path: avatars/{user_id}.jpg).
-- Scoped write access per user; read access for all authenticated users (partners).

create policy "Users can upload own avatar"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'notes'
    and name = 'avatars/' || auth.uid()::text || '.jpg'
  );

create policy "Users can update own avatar"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'notes'
    and name = 'avatars/' || auth.uid()::text || '.jpg'
  )
  with check (
    bucket_id = 'notes'
    and name = 'avatars/' || auth.uid()::text || '.jpg'
  );

create policy "Users can read avatars"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'notes'
    and (storage.foldername(name))[1] = 'avatars'
  );
