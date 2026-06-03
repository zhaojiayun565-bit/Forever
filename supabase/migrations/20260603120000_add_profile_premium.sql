-- Premium subscription state on profiles (subscriber's row; partner reads via couple RLS).

alter table public.profiles
  add column if not exists is_premium boolean not null default false,
  add column if not exists premium_expires_at timestamptz,
  add column if not exists premium_updated_at timestamptz not null default now();

-- Partner can read linked partner's profile (location, premium, etc.).
drop policy if exists "Users can read partner profile" on public.profiles;
create policy "Users can read partner profile"
  on public.profiles
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.couples c
      where (
        (c.user1_id = (select auth.uid()) and c.user2_id = profiles.id)
        or (c.user2_id = (select auth.uid()) and c.user1_id = profiles.id)
      )
    )
  );

-- Own profile updates (ambient data, premium sync from RevenueCat, etc.).
drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- Drop narrow pairing_code-only update policy superseded by the above.
drop policy if exists "Users can update own pairing_code" on public.profiles;
