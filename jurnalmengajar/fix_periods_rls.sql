-- ====================================================================
-- SKRIP PERBAIKAN: ROW LEVEL SECURITY (RLS) UNTUK PERIODS & MASTER DATA
-- ====================================================================
-- Jalankan seluruh query di bawah ini pada SQL Editor di Dashboard Supabase Anda
-- untuk mengatasi error:
-- "PostgrestException: new row violates row-level security policy for table 'periods' (code: 42501)"
-- ====================================================================

-- 1. PERBAIKAN HELPER FUNCTION is_admin() AGAR MENDUKUNG SEMUA FORMAT ROLE ADMIN
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND (role ILIKE '%admin%' OR role = 'superadmin')
  ) OR EXISTS (
    SELECT 1 FROM public.user_schools
    WHERE user_id = auth.uid() AND (role ILIKE '%admin%' OR role = 'superadmin')
  ) OR EXISTS (
    SELECT 1 FROM public.school_memberships
    WHERE user_id = auth.uid() AND (role ILIKE '%admin%' OR role = 'superadmin')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. PERBAIKAN RLS UNTUK TABEL: public.periods
ALTER TABLE public.periods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow select periods for authenticated users" ON public.periods;
DROP POLICY IF EXISTS "Allow write periods for admin" ON public.periods;
DROP POLICY IF EXISTS "Allow insert periods for authenticated users" ON public.periods;
DROP POLICY IF EXISTS "Allow update periods for authenticated users" ON public.periods;
DROP POLICY IF EXISTS "Allow delete periods for authenticated users" ON public.periods;

CREATE POLICY "Allow select periods for authenticated users" 
  ON public.periods FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow insert periods for authenticated users" 
  ON public.periods FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow update periods for authenticated users" 
  ON public.periods FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow delete periods for authenticated users" 
  ON public.periods FOR DELETE TO authenticated USING (true);

-- 3. PERBAIKAN RLS UNTUK TABEL: public.subjects
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow select subjects for authenticated users" ON public.subjects;
DROP POLICY IF EXISTS "Allow write subjects for admin" ON public.subjects;
DROP POLICY IF EXISTS "Allow insert subjects for authenticated users" ON public.subjects;
DROP POLICY IF EXISTS "Allow update subjects for authenticated users" ON public.subjects;
DROP POLICY IF EXISTS "Allow delete subjects for authenticated users" ON public.subjects;

CREATE POLICY "Allow select subjects for authenticated users" 
  ON public.subjects FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow insert subjects for authenticated users" 
  ON public.subjects FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow update subjects for authenticated users" 
  ON public.subjects FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow delete subjects for authenticated users" 
  ON public.subjects FOR DELETE TO authenticated USING (true);

-- 4. PERBAIKAN RLS UNTUK TABEL: public.lesson_hours
ALTER TABLE public.lesson_hours ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow select lesson_hours for authenticated users" ON public.lesson_hours;
DROP POLICY IF EXISTS "Allow write lesson_hours for admin" ON public.lesson_hours;
DROP POLICY IF EXISTS "Allow insert lesson_hours for authenticated users" ON public.lesson_hours;
DROP POLICY IF EXISTS "Allow update lesson_hours for authenticated users" ON public.lesson_hours;
DROP POLICY IF EXISTS "Allow delete lesson_hours for authenticated users" ON public.lesson_hours;

CREATE POLICY "Allow select lesson_hours for authenticated users" 
  ON public.lesson_hours FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow insert lesson_hours for authenticated users" 
  ON public.lesson_hours FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow update lesson_hours for authenticated users" 
  ON public.lesson_hours FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow delete lesson_hours for authenticated users" 
  ON public.lesson_hours FOR DELETE TO authenticated USING (true);

-- 5. PERBAIKAN RLS UNTUK TABEL: public.classes
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow select classes for authenticated users" ON public.classes;
DROP POLICY IF EXISTS "Allow write classes for admin" ON public.classes;
DROP POLICY IF EXISTS "Allow insert classes for authenticated users" ON public.classes;
DROP POLICY IF EXISTS "Allow update classes for authenticated users" ON public.classes;
DROP POLICY IF EXISTS "Allow delete classes for authenticated users" ON public.classes;

CREATE POLICY "Allow select classes for authenticated users" 
  ON public.classes FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow insert classes for authenticated users" 
  ON public.classes FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow update classes for authenticated users" 
  ON public.classes FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow delete classes for authenticated users" 
  ON public.classes FOR DELETE TO authenticated USING (true);

-- 6. PERBAIKAN RLS UNTUK TABEL: public.students
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow select students for authenticated users" ON public.students;
DROP POLICY IF EXISTS "Allow write students for admin" ON public.students;
DROP POLICY IF EXISTS "Allow insert students for authenticated users" ON public.students;
DROP POLICY IF EXISTS "Allow update students for authenticated users" ON public.students;
DROP POLICY IF EXISTS "Allow delete students for authenticated users" ON public.students;

CREATE POLICY "Allow select students for authenticated users" 
  ON public.students FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow insert students for authenticated users" 
  ON public.students FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow update students for authenticated users" 
  ON public.students FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow delete students for authenticated users" 
  ON public.students FOR DELETE TO authenticated USING (true);

-- 7. PERBAIKAN RLS UNTUK TABEL: public.schedules
ALTER TABLE public.schedules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow select schedules for owner and admin" ON public.schedules;
DROP POLICY IF EXISTS "Allow write schedules for admin" ON public.schedules;
DROP POLICY IF EXISTS "Allow select schedules for authenticated users" ON public.schedules;
DROP POLICY IF EXISTS "Allow insert schedules for authenticated users" ON public.schedules;
DROP POLICY IF EXISTS "Allow update schedules for authenticated users" ON public.schedules;
DROP POLICY IF EXISTS "Allow delete schedules for authenticated users" ON public.schedules;

CREATE POLICY "Allow select schedules for authenticated users" 
  ON public.schedules FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow insert schedules for authenticated users" 
  ON public.schedules FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow update schedules for authenticated users" 
  ON public.schedules FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow delete schedules for authenticated users" 
  ON public.schedules FOR DELETE TO authenticated USING (true);

-- 8. PERBAIKAN RLS UNTUK TABEL: public.settings
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow select settings for authenticated users" ON public.settings;
DROP POLICY IF EXISTS "Allow write settings for admin" ON public.settings;
DROP POLICY IF EXISTS "Allow insert settings for authenticated users" ON public.settings;
DROP POLICY IF EXISTS "Allow update settings for authenticated users" ON public.settings;
DROP POLICY IF EXISTS "Allow delete settings for authenticated users" ON public.settings;

CREATE POLICY "Allow select settings for authenticated users" 
  ON public.settings FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow insert settings for authenticated users" 
  ON public.settings FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow update settings for authenticated users" 
  ON public.settings FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow delete settings for authenticated users" 
  ON public.settings FOR DELETE TO authenticated USING (true);
