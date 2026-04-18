-- Optional caption for each memory pin
ALTER TABLE public.memories
    ADD COLUMN IF NOT EXISTS note TEXT;
