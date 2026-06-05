-- Shared drawing-board background URL (one per couple).

ALTER TABLE public.couples
    ADD COLUMN IF NOT EXISTS board_wallpaper_url text;

CREATE POLICY "Members can update their couple"
    ON public.couples
    FOR UPDATE
    TO authenticated
    USING (
        (SELECT auth.uid()) = user1_id
        OR (SELECT auth.uid()) = user2_id
    )
    WITH CHECK (
        (SELECT auth.uid()) = user1_id
        OR (SELECT auth.uid()) = user2_id
    );
