CREATE POLICY "Users can delete their couple's memories" ON public.memories
    FOR DELETE USING (
        couple_id IN (
            SELECT id FROM public.couples
            WHERE user1_id = auth.uid() OR user2_id = auth.uid()
        )
    );
