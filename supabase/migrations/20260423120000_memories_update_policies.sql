-- Allow updating memory rows (e.g. note) for shared couple memories and for solo memories still unpaired.

CREATE POLICY "Users can update their couple's memories" ON public.memories
    FOR UPDATE
    USING (
        couple_id IS NOT NULL
        AND couple_id IN (
            SELECT id FROM public.couples
            WHERE user1_id = auth.uid() OR user2_id = auth.uid()
        )
    )
    WITH CHECK (
        couple_id IS NOT NULL
        AND couple_id IN (
            SELECT id FROM public.couples
            WHERE user1_id = auth.uid() OR user2_id = auth.uid()
        )
    );

CREATE POLICY "Users can update their solo memories in place" ON public.memories
    FOR UPDATE
    USING (creator_id = auth.uid() AND couple_id IS NULL)
    WITH CHECK (creator_id = auth.uid() AND couple_id IS NULL);
