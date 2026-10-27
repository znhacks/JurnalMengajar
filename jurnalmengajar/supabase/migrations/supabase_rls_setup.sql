-- ====================================================================
-- SUPABASE ROW LEVEL SECURITY (RLS) & SYNC SETUP
-- Jurnal Mengajar Database Security hardening
-- ====================================================================

-- 1. ENABLE ROW LEVEL SECURITY (RLS) ON ALL TABLES
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_hours ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warning_letters ENABLE ROW LEVEL SECURITY;

-- 2. HELPER FUNCTION TO CHECK IF A USER IS AN ADMIN
-- Defined with SECURITY DEFINER to avoid infinite recursion when querying public.users
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

-- 3. RLS POLICIES FOR: public.users
DROP POLICY IF EXISTS "Allow select users for authenticated users" ON public.users;
DROP POLICY IF EXISTS "Allow insert users for owners" ON public.users;
DROP POLICY IF EXISTS "Allow update users for owners and admin" ON public.users;
DROP POLICY IF EXISTS "Allow delete users for owners and admin" ON public.users;

CREATE POLICY "Allow select users for authenticated users" 
  ON public.users FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow insert users for owners" 
  ON public.users FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

CREATE POLICY "Allow update users for owners and admin" 
  ON public.users FOR UPDATE TO authenticated 
  USING (auth.uid() = id OR public.is_admin()) 
  WITH CHECK (auth.uid() = id OR public.is_admin());

CREATE POLICY "Allow delete users for owners and admin" 
  ON public.users FOR DELETE TO authenticated USING (auth.uid() = id OR public.is_admin());

-- 4. RLS POLICIES FOR: public.periods
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

-- 5. RLS POLICIES FOR: public.subjects
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

-- 6. RLS POLICIES FOR: public.lesson_hours
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

-- 7. RLS POLICIES FOR: public.classes
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

-- 8. RLS POLICIES FOR: public.students
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

-- 9. RLS POLICIES FOR: public.schedules
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

-- 10. RLS POLICIES FOR: public.journals
DROP POLICY IF EXISTS "Allow select journals for owner and admin" ON public.journals;
DROP POLICY IF EXISTS "Allow insert journals for owner and admin" ON public.journals;
DROP POLICY IF EXISTS "Allow update journals for owner and admin" ON public.journals;
DROP POLICY IF EXISTS "Allow delete journals for owner and admin" ON public.journals;
DROP POLICY IF EXISTS "Allow select journals for authenticated users" ON public.journals;
DROP POLICY IF EXISTS "Allow insert journals for authenticated users" ON public.journals;
DROP POLICY IF EXISTS "Allow update journals for authenticated users" ON public.journals;
DROP POLICY IF EXISTS "Allow delete journals for authenticated users" ON public.journals;

CREATE POLICY "Allow select journals for authenticated users" 
  ON public.journals FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow insert journals for authenticated users" 
  ON public.journals FOR INSERT TO authenticated 
  WITH CHECK (true);

CREATE POLICY "Allow update journals for authenticated users" 
  ON public.journals FOR UPDATE TO authenticated 
  USING (true) 
  WITH CHECK (true);

CREATE POLICY "Allow delete journals for authenticated users" 
  ON public.journals FOR DELETE TO authenticated 
  USING (true);

-- 11. RLS POLICIES FOR: public.settings
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

-- 12. RLS POLICIES FOR: public.warning_letters
DROP POLICY IF EXISTS "Allow select warning_letters for owner and admin" ON public.warning_letters;
DROP POLICY IF EXISTS "Allow insert warning_letters for admin" ON public.warning_letters;
DROP POLICY IF EXISTS "Allow update warning_letters for owner and admin" ON public.warning_letters;
DROP POLICY IF EXISTS "Allow delete warning_letters for admin" ON public.warning_letters;
DROP POLICY IF EXISTS "Allow select warning_letters for authenticated users" ON public.warning_letters;
DROP POLICY IF EXISTS "Allow insert warning_letters for authenticated users" ON public.warning_letters;
DROP POLICY IF EXISTS "Allow update warning_letters for authenticated users" ON public.warning_letters;
DROP POLICY IF EXISTS "Allow delete warning_letters for authenticated users" ON public.warning_letters;

CREATE POLICY "Allow select warning_letters for authenticated users" 
  ON public.warning_letters FOR SELECT TO authenticated 
  USING (true);

CREATE POLICY "Allow insert warning_letters for authenticated users" 
  ON public.warning_letters FOR INSERT TO authenticated 
  WITH CHECK (true);

CREATE POLICY "Allow update warning_letters for authenticated users" 
  ON public.warning_letters FOR UPDATE TO authenticated 
  USING (true) 
  WITH CHECK (true);

CREATE POLICY "Allow delete warning_letters for authenticated users" 
  ON public.warning_letters FOR DELETE TO authenticated 
  USING (true);

-- ====================================================================
-- TRIGGERS TO AUTOMATICALLY SYNC AUTH.USERS TO PUBLIC.USERS
-- ====================================================================

-- Function to handle auto-creation of a public.users record when a new user signs up in auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email, full_name, role, phone, position, address, photo_url)
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    COALESCE(new.raw_user_meta_data->>'role', 'pending_guru'),
    new.raw_user_meta_data->>'phone_number',
    new.raw_user_meta_data->>'position',
    new.raw_user_meta_data->>'address',
    new.raw_user_meta_data->>'photo_url'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to run handle_new_user on insert to auth.users
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Function to handle auto-update of public.users.email when auth.users.email changes
CREATE OR REPLACE FUNCTION public.handle_update_user()
RETURNS trigger AS $$
BEGIN
  UPDATE public.users
  SET email = new.email
  WHERE id = new.id;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to run handle_update_user on email update in auth.users
CREATE OR REPLACE TRIGGER on_auth_user_updated
  AFTER UPDATE OF email ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_update_user();
