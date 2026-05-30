-- Broadcast profile UPDATEs (latitude/longitude/battery) over Realtime so a partner's
-- live distance and widgets refresh the moment the other person uploads a new location.
-- RLS still gates delivery: each client only receives rows it can SELECT
-- (own profile + the "Users can read partner profile" policy).
ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
