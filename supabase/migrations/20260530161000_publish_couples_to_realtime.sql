-- Broadcast couple INSERTs over Realtime so a waiting partner's app transitions
-- automatically the moment the other person enters their pairing code.
-- subscribeToCoupleLink() listens for these events; without publication they never fire.
-- RLS still gates delivery via the "Users can read couples they belong to" policy.
ALTER PUBLICATION supabase_realtime ADD TABLE public.couples;
