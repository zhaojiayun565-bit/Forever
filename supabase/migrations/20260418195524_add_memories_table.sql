CREATE TABLE public.memories (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    couple_id UUID NOT NULL REFERENCES public.couples(id) ON DELETE CASCADE,
    creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    PRIMARY KEY (id)
);

-- Turn on Security
ALTER TABLE public.memories ENABLE ROW LEVEL SECURITY;

-- Allow users to read memories for their couple
CREATE POLICY "Users can view their couple's memories" ON public.memories
    FOR SELECT USING (
        couple_id IN (
            SELECT id FROM public.couples 
            WHERE user1_id = auth.uid() OR user2_id = auth.uid()
        )
    );

-- Allow users to insert memories for their couple
CREATE POLICY "Users can insert memories for their couple" ON public.memories
    FOR INSERT WITH CHECK (
        couple_id IN (
            SELECT id FROM public.couples 
            WHERE user1_id = auth.uid() OR user2_id = auth.uid()
        )
    );