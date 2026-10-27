-- ====================================================================
-- MIGRASI DATABASE: FITUR CUTI GURU & PENUGASAN GURU PENGGANTI
-- ====================================================================

-- 1. TABEL CUTI GURU (TEACHER LEAVES)
CREATE TABLE IF NOT EXISTS public.teacher_leaves (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    teacher_id UUID NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT,
    status TEXT DEFAULT 'active',
    substitutes JSONB DEFAULT '[]'::jsonb,
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. KOLOM GURU PENGGANTI PADA TABEL SCHEDULES
ALTER TABLE public.schedules ADD COLUMN IF NOT EXISTS substitute_teacher_id UUID;

-- 3. ROW LEVEL SECURITY (RLS) UNTUK TEACHER_LEAVES
ALTER TABLE public.teacher_leaves ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated read teacher_leaves" ON public.teacher_leaves;
CREATE POLICY "Allow authenticated read teacher_leaves"
ON public.teacher_leaves FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Allow authenticated insert teacher_leaves" ON public.teacher_leaves;
CREATE POLICY "Allow authenticated insert teacher_leaves"
ON public.teacher_leaves FOR INSERT
TO authenticated
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow authenticated update teacher_leaves" ON public.teacher_leaves;
CREATE POLICY "Allow authenticated update teacher_leaves"
ON public.teacher_leaves FOR UPDATE
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Allow authenticated delete teacher_leaves" ON public.teacher_leaves;
CREATE POLICY "Allow authenticated delete teacher_leaves"
ON public.teacher_leaves FOR DELETE
TO authenticated
USING (true);
