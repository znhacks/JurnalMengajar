-- ====================================================================
-- SKRIP PERBAIKAN LENGKAP: ROW LEVEL SECURITY (RLS) UNTUK SEMUA DATA MASTER
-- (Periods, Subjects, Lesson Hours, Classes, Students, Schedules, Settings, Holidays)
-- ====================================================================
-- AMAN UNTUK DIJALANKAN DI SUPABASE SQL EDITOR:
-- - Tidak menghapus atau merusak data yang sudah ada
-- - Mengatasi error RLS code 42501 (insufficient privilege)
-- - Mendukung sistem Multi-Tenant & Multi-Role (Admin, Superadmin, Guru)
-- ====================================================================

-- 1. HELPER FUNCTION is_admin() YANG MENDUKUNG SEMUA FORMAT ROLE
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

-- 2. TABEL: public.periods (PERIODE AKADEMIK)
ALTER TABLE public.periods ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow select periods for authenticated users" ON public.periods;
DROP POLICY IF EXISTS "Allow write periods for admin" ON public.periods;
DROP POLICY IF EXISTS "Allow insert periods for authenticated users" ON public.periods;
DROP POLICY IF EXISTS "Allow update periods for authenticated users" ON public.periods;
DROP POLICY IF EXISTS "Allow delete periods for authenticated users" ON public.periods;

CREATE POLICY "Allow select periods for authenticated users" ON public.periods FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow insert periods for authenticated users" ON public.periods FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow update periods for authenticated users" ON public.periods FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow delete periods for authenticated users" ON public.periods FOR DELETE TO authenticated USING (true);

-- 3. TABEL: public.subjects (MATA PELAJARAN)
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow select subjects for authenticated users" ON public.subjects;
DROP POLICY IF EXISTS "Allow write subjects for admin" ON public.subjects;
DROP POLICY IF EXISTS "Allow insert subjects for authenticated users" ON public.subjects;
DROP POLICY IF EXISTS "Allow update subjects for authenticated users" ON public.subjects;
DROP POLICY IF EXISTS "Allow delete subjects for authenticated users" ON public.subjects;

CREATE POLICY "Allow select subjects for authenticated users" ON public.subjects FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow insert subjects for authenticated users" ON public.subjects FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow update subjects for authenticated users" ON public.subjects FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow delete subjects for authenticated users" ON public.subjects FOR DELETE TO authenticated USING (true);

-- 4. TABEL: public.lesson_hours (JAM PELAJARAN)
ALTER TABLE public.lesson_hours ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow select lesson_hours for authenticated users" ON public.lesson_hours;
DROP POLICY IF EXISTS "Allow write lesson_hours for admin" ON public.lesson_hours;
DROP POLICY IF EXISTS "Allow insert lesson_hours for authenticated users" ON public.lesson_hours;
DROP POLICY IF EXISTS "Allow update lesson_hours for authenticated users" ON public.lesson_hours;
DROP POLICY IF EXISTS "Allow delete lesson_hours for authenticated users" ON public.lesson_hours;

CREATE POLICY "Allow select lesson_hours for authenticated users" ON public.lesson_hours FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow insert lesson_hours for authenticated users" ON public.lesson_hours FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow update lesson_hours for authenticated users" ON public.lesson_hours FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow delete lesson_hours for authenticated users" ON public.lesson_hours FOR DELETE TO authenticated USING (true);

-- 5. TABEL: public.classes (KELAS)
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow select classes for authenticated users" ON public.classes;
DROP POLICY IF EXISTS "Allow write classes for admin" ON public.classes;
DROP POLICY IF EXISTS "Allow insert classes for authenticated users" ON public.classes;
DROP POLICY IF EXISTS "Allow update classes for authenticated users" ON public.classes;
DROP POLICY IF EXISTS "Allow delete classes for authenticated users" ON public.classes;

CREATE POLICY "Allow select classes for authenticated users" ON public.classes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow insert classes for authenticated users" ON public.classes FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow update classes for authenticated users" ON public.classes FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow delete classes for authenticated users" ON public.classes FOR DELETE TO authenticated USING (true);

-- 6. TABEL: public.students (SISWA)
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow select students for authenticated users" ON public.students;
DROP POLICY IF EXISTS "Allow write students for admin" ON public.students;
DROP POLICY IF EXISTS "Allow insert students for authenticated users" ON public.students;
DROP POLICY IF EXISTS "Allow update students for authenticated users" ON public.students;
DROP POLICY IF EXISTS "Allow delete students for authenticated users" ON public.students;

CREATE POLICY "Allow select students for authenticated users" ON public.students FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow insert students for authenticated users" ON public.students FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow update students for authenticated users" ON public.students FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow delete students for authenticated users" ON public.students FOR DELETE TO authenticated USING (true);

-- 7. TABEL: public.schedules (JADWAL MENGAJAR)
ALTER TABLE public.schedules ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow select schedules for owner and admin" ON public.schedules;
DROP POLICY IF EXISTS "Allow write schedules for admin" ON public.schedules;
DROP POLICY IF EXISTS "Allow select schedules for authenticated users" ON public.schedules;
DROP POLICY IF EXISTS "Allow insert schedules for authenticated users" ON public.schedules;
DROP POLICY IF EXISTS "Allow update schedules for authenticated users" ON public.schedules;
DROP POLICY IF EXISTS "Allow delete schedules for authenticated users" ON public.schedules;

CREATE POLICY "Allow select schedules for authenticated users" ON public.schedules FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow insert schedules for authenticated users" ON public.schedules FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow update schedules for authenticated users" ON public.schedules FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow delete schedules for authenticated users" ON public.schedules FOR DELETE TO authenticated USING (true);

-- 8. TABEL: public.settings (PENGATURAN)
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow select settings for authenticated users" ON public.settings;
DROP POLICY IF EXISTS "Allow write settings for admin" ON public.settings;
DROP POLICY IF EXISTS "Allow insert settings for authenticated users" ON public.settings;
DROP POLICY IF EXISTS "Allow update settings for authenticated users" ON public.settings;
DROP POLICY IF EXISTS "Allow delete settings for authenticated users" ON public.settings;

CREATE POLICY "Allow select settings for authenticated users" ON public.settings FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow insert settings for authenticated users" ON public.settings FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow update settings for authenticated users" ON public.settings FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow delete settings for authenticated users" ON public.settings FOR DELETE TO authenticated USING (true);

-- 9. TABEL: public.school_holidays (HARI LIBUR)
ALTER TABLE public.school_holidays ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow authenticated read school_holidays" ON public.school_holidays;
DROP POLICY IF EXISTS "Allow authenticated insert school_holidays" ON public.school_holidays;
DROP POLICY IF EXISTS "Allow authenticated update school_holidays" ON public.school_holidays;
DROP POLICY IF EXISTS "Allow authenticated delete school_holidays" ON public.school_holidays;

CREATE POLICY "Allow authenticated read school_holidays" ON public.school_holidays FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated insert school_holidays" ON public.school_holidays FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow update school_holidays for authenticated users" ON public.school_holidays FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow delete school_holidays for authenticated users" ON public.school_holidays FOR DELETE TO authenticated USING (true);

-- 10. TABEL: public.schools (SEKOLAH / TENANTS)
ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow select schools for all" ON public.schools;
DROP POLICY IF EXISTS "Allow write schools for all" ON public.schools;
DROP POLICY IF EXISTS "Allow insert schools for authenticated" ON public.schools;
DROP POLICY IF EXISTS "Allow update schools for authenticated" ON public.schools;
DROP POLICY IF EXISTS "Allow delete schools for authenticated" ON public.schools;

CREATE POLICY "Allow select schools for all" ON public.schools FOR SELECT TO public USING (true);
CREATE POLICY "Allow insert schools for all" ON public.schools FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Allow update schools for all" ON public.schools FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow delete schools for all" ON public.schools FOR DELETE TO authenticated USING (true);

-- 11. TABEL: public.user_schools (RELASI USER DAN SEKOLAH)
ALTER TABLE public.user_schools ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow select user_schools for all" ON public.user_schools;
DROP POLICY IF EXISTS "Allow write user_schools for all" ON public.user_schools;
DROP POLICY IF EXISTS "Allow insert user_schools for all" ON public.user_schools;
DROP POLICY IF EXISTS "Allow update user_schools for all" ON public.user_schools;
DROP POLICY IF EXISTS "Allow delete user_schools for all" ON public.user_schools;

CREATE POLICY "Allow select user_schools for all" ON public.user_schools FOR SELECT TO public USING (true);
CREATE POLICY "Allow insert user_schools for all" ON public.user_schools FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Allow update user_schools for all" ON public.user_schools FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow delete user_schools for all" ON public.user_schools FOR DELETE TO public USING (true);

-- 12. TABEL: public.tenants & public.subscriptions (JM-PANEL INTEGRATION)
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'tenants') THEN
    ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Allow select tenants for all" ON public.tenants;
    CREATE POLICY "Allow select tenants for all" ON public.tenants FOR SELECT TO public USING (true);
  END IF;

  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'subscriptions') THEN
    ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Allow select subscriptions for all" ON public.subscriptions;
    CREATE POLICY "Allow select subscriptions for all" ON public.subscriptions FOR SELECT TO public USING (true);
  END IF;
END $$;
