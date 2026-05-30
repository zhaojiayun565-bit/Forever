-- Profile photo URL for distance widget avatars (stored in Supabase Storage).
alter table public.profiles
  add column if not exists avatar_url text;
