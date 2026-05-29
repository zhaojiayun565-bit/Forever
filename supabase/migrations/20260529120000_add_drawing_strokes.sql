-- Shared Lockscreen Drawing Board: durable, couple-scoped stroke storage.
-- Live sync happens over Realtime Broadcast; this table is the source of truth on load.

CREATE TABLE public.drawing_strokes (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    couple_id UUID NOT NULL REFERENCES public.couples(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    color_hex TEXT NOT NULL,
    width DOUBLE PRECISION NOT NULL,
    -- Flattened, width-normalized points: [x0, y0, x1, y1, ...]
    points JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    PRIMARY KEY (id)
);

-- Fast ordered load per couple.
CREATE INDEX idx_drawing_strokes_couple ON public.drawing_strokes (couple_id, created_at);

-- Turn on Security
ALTER TABLE public.drawing_strokes ENABLE ROW LEVEL SECURITY;

-- Members of the couple can read all strokes on the board.
CREATE POLICY "Users can view their couple's strokes" ON public.drawing_strokes
    FOR SELECT USING (
        couple_id IN (
            SELECT id FROM public.couples
            WHERE user1_id = auth.uid() OR user2_id = auth.uid()
        )
    );

-- A user may only insert strokes they authored, onto a board for their couple.
CREATE POLICY "Users can insert strokes for their couple" ON public.drawing_strokes
    FOR INSERT WITH CHECK (
        author_id = auth.uid() AND
        couple_id IN (
            SELECT id FROM public.couples
            WHERE user1_id = auth.uid() OR user2_id = auth.uid()
        )
    );

-- Either partner can delete strokes on their shared board (powers Undo / Clear).
CREATE POLICY "Users can delete their couple's strokes" ON public.drawing_strokes
    FOR DELETE USING (
        couple_id IN (
            SELECT id FROM public.couples
            WHERE user1_id = auth.uid() OR user2_id = auth.uid()
        )
    );
