-- ====================================================================
-- MIGRASI DATABASE: FITUR HARI LIBUR / CUTI SEKOLAH & SOFT DELETE JURNAL
-- ====================================================================

-- 1. TABEL HARI LIBUR SEKOLAH (SCHOOL HOLIDAYS)
CREATE TABLE IF NOT EXISTS public.school_holidays (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    description TEXT,
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. TAMBAH KOLOM SOFT-DELETE PADA TABEL JOURNALS
ALTER TABLE public.journals 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL,
ADD COLUMN IF NOT EXISTS is_soft_deleted BOOLEAN DEFAULT FALSE;

-- Index untuk mempercepat query filtering libur dan soft delete
CREATE INDEX IF NOT EXISTS idx_school_holidays_dates ON public.school_holidays(school_id, start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_journals_soft_delete ON public.journals(is_soft_deleted);

-- 3. KONFIGURASI ROW LEVEL SECURITY (RLS) UNTUK SCHOOL_HOLIDAYS
ALTER TABLE public.school_holidays ENABLE ROW LEVEL SECURITY;

-- Policy Select: Semua user terautentikasi dapat membaca data hari libur
DROP POLICY IF EXISTS "Allow authenticated read school_holidays" ON public.school_holidays;
CREATE POLICY "Allow authenticated read school_holidays"
ON public.school_holidays FOR SELECT
TO authenticated
USING (true);

-- Policy Insert: User terautentikasi dapat menambahkan data hari libur
DROP POLICY IF EXISTS "Allow authenticated insert school_holidays" ON public.school_holidays;
CREATE POLICY "Allow authenticated insert school_holidays"
ON public.school_holidays FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy Update: User terautentikasi dapat memperbarui data hari libur
DROP POLICY IF EXISTS "Allow authenticated update school_holidays" ON public.school_holidays;
CREATE POLICY "Allow authenticated update school_holidays"
ON public.school_holidays FOR UPDATE
TO authenticated
USING (true);

-- Policy Delete: User terautentikasi dapat menghapus data hari libur
DROP POLICY IF EXISTS "Allow authenticated delete school_holidays" ON public.school_holidays;
CREATE POLICY "Allow authenticated delete school_holidays"
ON public.school_holidays FOR DELETE
TO authenticated
USING (true);

