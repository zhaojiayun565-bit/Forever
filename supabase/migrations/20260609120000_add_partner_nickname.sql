-- Per-user nickname for how they refer to their partner in-app and on widgets.
alter table public.profiles
  add column if not exists partner_nickname text;
