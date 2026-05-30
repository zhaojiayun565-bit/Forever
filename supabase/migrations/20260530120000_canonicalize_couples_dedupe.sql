-- Canonicalize couples: one row per unordered user pair (keep earliest), repoint children, dedupe, then enforce uniqueness.

-- Repoint memories to the canonical (earliest) couple for each pair.
UPDATE public.memories m
SET couple_id = map.canonical_id
FROM (
    SELECT c.id AS old_id,
           first_value(c.id) OVER (
               PARTITION BY LEAST(c.user1_id, c.user2_id), GREATEST(c.user1_id, c.user2_id)
               ORDER BY c.created_at ASC, c.id ASC
           ) AS canonical_id
    FROM public.couples c
) map
WHERE m.couple_id = map.old_id
  AND map.old_id <> map.canonical_id;

-- Repoint drawing strokes to the canonical couple for each pair.
UPDATE public.drawing_strokes d
SET couple_id = map.canonical_id
FROM (
    SELECT c.id AS old_id,
           first_value(c.id) OVER (
               PARTITION BY LEAST(c.user1_id, c.user2_id), GREATEST(c.user1_id, c.user2_id)
               ORDER BY c.created_at ASC, c.id ASC
           ) AS canonical_id
    FROM public.couples c
) map
WHERE d.couple_id = map.old_id
  AND map.old_id <> map.canonical_id;

-- Remove duplicate couple rows (children already repointed, so CASCADE is harmless here).
DELETE FROM public.couples c
USING (
    SELECT c.id AS old_id,
           first_value(c.id) OVER (
               PARTITION BY LEAST(c.user1_id, c.user2_id), GREATEST(c.user1_id, c.user2_id)
               ORDER BY c.created_at ASC, c.id ASC
           ) AS canonical_id
    FROM public.couples c
) map
WHERE c.id = map.old_id
  AND map.old_id <> map.canonical_id;

-- Guarantee a single couple per unordered user pair going forward.
CREATE UNIQUE INDEX IF NOT EXISTS couples_unique_pair
    ON public.couples (LEAST(user1_id, user2_id), GREATEST(user1_id, user2_id));
