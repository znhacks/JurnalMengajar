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
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. RLS POLICIES FOR: public.users
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
CREATE POLICY "Allow select periods for authenticated users" 
  ON public.periods FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow write periods for admin" 
  ON public.periods FOR ALL TO authenticated 
  USING (public.is_admin()) 
  WITH CHECK (public.is_admin());

-- 5. RLS POLICIES FOR: public.subjects
CREATE POLICY "Allow select subjects for authenticated users" 
  ON public.subjects FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow write subjects for admin" 
  ON public.subjects FOR ALL TO authenticated 
  USING (public.is_admin()) 
  WITH CHECK (public.is_admin());

-- 6. RLS POLICIES FOR: public.lesson_hours
CREATE POLICY "Allow select lesson_hours for authenticated users" 
  ON public.lesson_hours FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow write lesson_hours for admin" 
  ON public.lesson_hours FOR ALL TO authenticated 
  USING (public.is_admin()) 
  WITH CHECK (public.is_admin());

-- 7. RLS POLICIES FOR: public.classes
CREATE POLICY "Allow select classes for authenticated users" 
  ON public.classes FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow write classes for admin" 
  ON public.classes FOR ALL TO authenticated 
  USING (public.is_admin()) 
  WITH CHECK (public.is_admin());

-- 8. RLS POLICIES FOR: public.students
CREATE POLICY "Allow select students for authenticated users" 
  ON public.students FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow write students for admin" 
  ON public.students FOR ALL TO authenticated 
  USING (public.is_admin()) 
  WITH CHECK (public.is_admin());

-- 9. RLS POLICIES FOR: public.schedules
CREATE POLICY "Allow select schedules for owner and admin" 
  ON public.schedules FOR SELECT TO authenticated 
  USING (teacher_id = auth.uid() OR public.is_admin());

CREATE POLICY "Allow write schedules for admin" 
  ON public.schedules FOR ALL TO authenticated 
  USING (public.is_admin()) 
  WITH CHECK (public.is_admin());

-- 10. RLS POLICIES FOR: public.journals
CREATE POLICY "Allow select journals for owner and admin" 
  ON public.journals FOR SELECT TO authenticated 
  USING (teacher_id = auth.uid() OR public.is_admin());

CREATE POLICY "Allow insert journals for owner and admin" 
  ON public.journals FOR INSERT TO authenticated 
  WITH CHECK (teacher_id = auth.uid() OR public.is_admin());

CREATE POLICY "Allow update journals for owner and admin" 
  ON public.journals FOR UPDATE TO authenticated 
  USING (teacher_id = auth.uid() OR public.is_admin()) 
  WITH CHECK (teacher_id = auth.uid() OR public.is_admin());

CREATE POLICY "Allow delete journals for owner and admin" 
  ON public.journals FOR DELETE TO authenticated 
  USING (teacher_id = auth.uid() OR public.is_admin());

-- 11. RLS POLICIES FOR: public.settings
CREATE POLICY "Allow select settings for authenticated users" 
  ON public.settings FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow write settings for admin" 
  ON public.settings FOR ALL TO authenticated 
  USING (public.is_admin()) 
  WITH CHECK (public.is_admin());

-- 12. RLS POLICIES FOR: public.warning_letters
CREATE POLICY "Allow select warning_letters for owner and admin" 
  ON public.warning_letters FOR SELECT TO authenticated 
  USING (teacher_id = auth.uid() OR public.is_admin());

CREATE POLICY "Allow insert warning_letters for admin" 
  ON public.warning_letters FOR INSERT TO authenticated 
  WITH CHECK (public.is_admin());

CREATE POLICY "Allow update warning_letters for owner and admin" 
  ON public.warning_letters FOR UPDATE TO authenticated 
  USING (teacher_id = auth.uid() OR public.is_admin()) 
  WITH CHECK (teacher_id = auth.uid() OR public.is_admin());

CREATE POLICY "Allow delete warning_letters for admin" 
  ON public.warning_letters FOR DELETE TO authenticated 
  USING (public.is_admin());

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
