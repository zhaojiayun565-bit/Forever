-- Solo Mode: memories may exist before a couple row; migrate them when the user pairs.

ALTER TABLE public.memories
    ALTER COLUMN couple_id DROP NOT NULL;

-- Read solo memories (creator only, not yet attached to a couple).
CREATE POLICY "Users can view their solo memories" ON public.memories
    FOR SELECT USING (
        creator_id = auth.uid() AND couple_id IS NULL
    );

-- Insert memories with no couple yet.
CREATE POLICY "Users can insert solo memories" ON public.memories
    FOR INSERT WITH CHECK (
        creator_id = auth.uid() AND couple_id IS NULL
    );

-- Attach solo rows to a couple after pairing (single-column update).
CREATE POLICY "Users can attach solo memories to a couple" ON public.memories
    FOR UPDATE
    USING (creator_id = auth.uid() AND couple_id IS NULL)
    WITH CHECK (
        couple_id IN (
            SELECT id FROM public.couples
            WHERE user1_id = auth.uid() OR user2_id = auth.uid()
        )
    );

-- Remove solo memories the user created.
CREATE POLICY "Users can delete their solo memories" ON public.memories
    FOR DELETE USING (
        creator_id = auth.uid() AND couple_id IS NULL
    );
