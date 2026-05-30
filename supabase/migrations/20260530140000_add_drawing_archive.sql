-- Shared archive of sent drawing-board snapshots (full board + wallpaper).
create table if not exists public.drawing_archive (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  image_url text not null,
  created_at timestamptz not null default now()
);

create index if not exists drawing_archive_couple_idx
  on public.drawing_archive (couple_id, created_at desc);

alter table public.drawing_archive enable row level security;

create policy "Users can view their couple's archive" on public.drawing_archive
  for select using (
    couple_id in (
      select id from public.couples
      where user1_id = auth.uid() or user2_id = auth.uid()
    )
  );

create policy "Users can insert into their couple's archive" on public.drawing_archive
  for insert with check (
    couple_id in (
      select id from public.couples
      where user1_id = auth.uid() or user2_id = auth.uid()
    )
    and author_id = auth.uid()
  );

create policy "Users can delete their couple's archive" on public.drawing_archive
  for delete using (
    couple_id in (
      select id from public.couples
      where user1_id = auth.uid() or user2_id = auth.uid()
    )
  );
