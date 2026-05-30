-- Presence signal for the shared drawing board: stamped when a partner begins drawing,
-- which fires the profiles webhook so the other partner gets a "started drawing" push.
alter table public.profiles add column if not exists drawing_started_at timestamptz;
