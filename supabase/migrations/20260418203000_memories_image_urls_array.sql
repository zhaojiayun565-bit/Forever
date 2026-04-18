-- Multiple photos per memory (Postgres text[] maps to JSON string array in API)
ALTER TABLE public.memories ADD COLUMN IF NOT EXISTS image_urls TEXT[];

ALTER TABLE public.memories ALTER COLUMN image_url DROP NOT NULL;

UPDATE public.memories
SET image_urls = ARRAY[image_url]::text[]
WHERE (image_urls IS NULL OR cardinality(image_urls) = 0)
  AND image_url IS NOT NULL;
