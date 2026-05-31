-- Broadcast memory INSERT/UPDATE/DELETE over Realtime so both partners' map pins
-- refresh immediately. RLS still gates delivery to couple members only.
ALTER PUBLICATION supabase_realtime ADD TABLE public.memories;
