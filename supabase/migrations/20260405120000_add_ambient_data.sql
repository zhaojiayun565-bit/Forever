-- Ambient data for Home Screen widget: last known location and battery.
alter table public.profiles
  add column latitude double precision,
  add column longitude double precision,
  add column battery_level smallint;
