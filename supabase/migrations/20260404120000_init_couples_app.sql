-- Profiles: one row per auth user; pairing_code is unique when set.
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  pairing_code text unique,
  created_at timestamptz not null default now()
);

-- Couples: links two profile/user ids.
create table public.couples (
  id uuid primary key default gen_random_uuid(),
  user1_id uuid references public.profiles (id) on delete cascade,
  user2_id uuid references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.couples enable row level security;

create policy "Users can read own profile"
  on public.profiles
  for select
  to authenticated
  using ((select auth.uid()) = id);

create policy "Users can insert own profile"
  on public.profiles
  for insert
  to authenticated
  with check ((select auth.uid()) = id);

create policy "Users can update own pairing_code"
  on public.profiles
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create policy "Users can insert couple when they are a member"
  on public.couples
  for insert
  to authenticated
  with check (
    (select auth.uid()) = user1_id
    or (select auth.uid()) = user2_id
  );

create policy "Users can read couples they belong to"
  on public.couples
  for select
  to authenticated
  using (
    (select auth.uid()) = user1_id
    or (select auth.uid()) = user2_id
  );
