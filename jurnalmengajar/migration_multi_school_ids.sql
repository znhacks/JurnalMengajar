-- ====================================================================
-- MIGRATION: Multi-Tenant & Multi-School Array Support + RLS Hardening
-- Mendukung user dengan role ganda (Guru & Admin) dan multi-sekolah
-- Arsitektur: USER -> MEMBERSHIP (user_schools) -> SCHOOL_ID + ROLE -> AUTHORIZATION -> DATA
-- ====================================================================

-- 1. Tambah kolom `school_ids` tipe ARRAY of TEXT / TEXT[] pada tabel `users`
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS school_ids TEXT[] DEFAULT '{}';

-- 2. Helper function: user_has_school_access(target_school_id)
-- Mengecek apakah user yang sedang login (auth.uid()) memiliki akses ke sekolah tertentu.
-- Aman terhadap tipe data Array, JSON, string koma, maupun tabel relasi (user_schools / school_memberships).
CREATE OR REPLACE FUNCTION public.user_has_school_access(target_school_id text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_uid UUID;
  user_role TEXT;
  user_single_school TEXT;
  user_array_schools TEXT[];
  clean_target_uuid UUID;
BEGIN
  current_uid := auth.uid();
  IF current_uid IS NULL OR target_school_id IS NULL OR trim(target_school_id) = '' THEN
    RETURN false;
  END IF;

  -- 1. Cek apakah Superadmin (selalu punya akses penuh)
  SELECT lower(role), school_id, school_ids INTO user_role, user_single_school, user_array_schools
  FROM public.users
  WHERE id = current_uid;

  IF user_role = 'superadmin' THEN
    RETURN true;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = current_uid AND is_superadmin = true
  ) THEN
    RETURN true;
  END IF;

  -- Konversi target_school_id ke UUID jika memungkinkan
  BEGIN
    clean_target_uuid := target_school_id::uuid;
  EXCEPTION WHEN OTHERS THEN
    clean_target_uuid := NULL;
  END;

  -- 2. Cek kecocokan di tabel user_schools
  IF EXISTS (
    SELECT 1 FROM public.user_schools
    WHERE user_id = current_uid 
      AND (
        school_id::text = target_school_id 
        OR (clean_target_uuid IS NOT NULL AND school_id = clean_target_uuid)
      )
      AND (status IS NULL OR lower(status) = 'active')
  ) THEN
    RETURN true;
  END IF;

  -- 3. Cek kecocokan di kolom users.school_id
  IF user_single_school IS NOT NULL AND (
    user_single_school = target_school_id 
    OR user_single_school LIKE '%' || target_school_id || '%'
  ) THEN
    RETURN true;
  END IF;

  -- 4. Cek kecocokan di array users.school_ids
  IF user_array_schools IS NOT NULL AND target_school_id = ANY(user_array_schools) THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;

-- 3. Helper function: is_admin()
-- Mendukung Admin Utama maupun Admin Tambahan (baik via users.role maupun user_schools.role)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND lower(role) IN ('admin', 'school_admin', 'superadmin')
  ) OR EXISTS (
    SELECT 1 FROM public.user_schools
    WHERE user_id = auth.uid()
      AND lower(role) IN ('admin', 'school_admin', 'superadmin')
      AND (status IS NULL OR lower(status) = 'active')
  ) OR EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND is_superadmin = true
  );
END;
$$;

-- 4. Helper function: is_admin_in_school(p_school_id uuid/text)
CREATE OR REPLACE FUNCTION public.is_admin_in_school(p_school_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF auth.uid() IS NULL OR p_school_id IS NULL THEN
    RETURN false;
  END IF;

  -- Superadmin has access to all schools
  IF EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND lower(role) = 'superadmin'
  ) OR EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND is_superadmin = true
  ) THEN
    RETURN true;
  END IF;

  -- Active membership in user_schools for this school
  IF EXISTS (
    SELECT 1 FROM public.user_schools
    WHERE user_id = auth.uid()
      AND school_id = p_school_id
      AND lower(role) IN ('admin', 'school_admin', 'superadmin')
      AND (status IS NULL OR lower(status) = 'active')
  ) THEN
    RETURN true;
  END IF;

  -- Direct assignment in users table
  IF EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
      AND lower(role) IN ('admin', 'school_admin', 'superadmin')
      AND (
        school_id = p_school_id::text
        OR school_id LIKE '%' || p_school_id::text || '%'
        OR (school_ids IS NOT NULL AND p_school_id::text = ANY(school_ids))
      )
  ) THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION public.is_admin_in_school(p_school_id text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF p_school_id IS NULL OR trim(p_school_id) = '' THEN
    RETURN false;
  END IF;
  BEGIN
    RETURN public.is_admin_in_school(p_school_id::uuid);
  EXCEPTION WHEN OTHERS THEN
    RETURN false;
  END;
END;
$$;

-- 5. RLS Policies: Schedules
DROP POLICY IF EXISTS "Allow select schedules for owner and admin" ON public.schedules;
DROP POLICY IF EXISTS "schedules_select_policy" ON public.schedules;

CREATE POLICY "Allow select schedules for owner and admin" ON public.schedules
FOR SELECT TO authenticated
USING (
  is_superadmin()
  OR is_admin_in_school(school_id)
  OR (
    teacher_id = auth.uid() 
    AND (school_id IS NULL OR user_has_school_access(school_id::text))
  )
  OR is_admin()
);

DROP POLICY IF EXISTS "Allow write schedules for admin" ON public.schedules;
CREATE POLICY "Allow write schedules for admin" ON public.schedules
FOR ALL TO authenticated
USING (
  is_superadmin() OR is_admin_in_school(school_id) OR is_admin()
)
WITH CHECK (
  is_superadmin() OR is_admin_in_school(school_id) OR is_admin()
);

-- 6. RLS Policies: Classes, Subjects, Periods, Lesson Hours, Students
DROP POLICY IF EXISTS "Allow write classes for admin" ON public.classes;
CREATE POLICY "Allow write classes for admin" ON public.classes
FOR ALL TO authenticated
USING (is_superadmin() OR is_admin_in_school(school_id) OR is_admin())
WITH CHECK (is_superadmin() OR is_admin_in_school(school_id) OR is_admin());

DROP POLICY IF EXISTS "Allow write subjects for admin" ON public.subjects;
CREATE POLICY "Allow write subjects for admin" ON public.subjects
FOR ALL TO authenticated
USING (is_superadmin() OR is_admin_in_school(school_id) OR is_admin())
WITH CHECK (is_superadmin() OR is_admin_in_school(school_id) OR is_admin());

DROP POLICY IF EXISTS "Allow write periods for admin" ON public.periods;
CREATE POLICY "Allow write periods for admin" ON public.periods
FOR ALL TO authenticated
USING (is_superadmin() OR is_admin_in_school(school_id) OR is_admin())
WITH CHECK (is_superadmin() OR is_admin_in_school(school_id) OR is_admin());

DROP POLICY IF EXISTS "Allow write lesson_hours for admin" ON public.lesson_hours;
CREATE POLICY "Allow write lesson_hours for admin" ON public.lesson_hours
FOR ALL TO authenticated
USING (is_superadmin() OR is_admin_in_school(school_id) OR is_admin())
WITH CHECK (is_superadmin() OR is_admin_in_school(school_id) OR is_admin());

DROP POLICY IF EXISTS "Allow write students for admin" ON public.students;
CREATE POLICY "Allow write students for admin" ON public.students
FOR ALL TO authenticated
USING (is_superadmin() OR is_admin_in_school(school_id) OR is_admin())
WITH CHECK (is_superadmin() OR is_admin_in_school(school_id) OR is_admin());

-- 7. RLS Policies: Journals
DROP POLICY IF EXISTS "Allow select journals for owner and admin" ON public.journals;
CREATE POLICY "Allow select journals for owner and admin" ON public.journals
FOR SELECT TO authenticated
USING (
  is_superadmin() 
  OR is_admin_in_school(school_id) 
  OR teacher_id = auth.uid() 
  OR is_admin()
);

DROP POLICY IF EXISTS "Allow insert journals for owner and admin" ON public.journals;
CREATE POLICY "Allow insert journals for owner and admin" ON public.journals
FOR INSERT TO authenticated
WITH CHECK (
  is_superadmin() 
  OR is_admin_in_school(school_id) 
  OR teacher_id = auth.uid() 
  OR is_admin()
);

DROP POLICY IF EXISTS "Allow update journals for owner and admin" ON public.journals;
CREATE POLICY "Allow update journals for owner and admin" ON public.journals
FOR UPDATE TO authenticated
USING (
  is_superadmin() 
  OR is_admin_in_school(school_id) 
  OR teacher_id = auth.uid() 
  OR is_admin()
)
WITH CHECK (
  is_superadmin() 
  OR is_admin_in_school(school_id) 
  OR teacher_id = auth.uid() 
  OR is_admin()
);

DROP POLICY IF EXISTS "Allow delete journals for owner and admin" ON public.journals;
CREATE POLICY "Allow delete journals for owner and admin" ON public.journals
FOR DELETE TO authenticated
USING (
  is_superadmin() 
  OR is_admin_in_school(school_id) 
  OR teacher_id = auth.uid() 
  OR is_admin()
);

-- 8. RLS Policies: Warning Letters
DROP POLICY IF EXISTS "Allow select warning_letters for owner and admin" ON public.warning_letters;
CREATE POLICY "Allow select warning_letters for owner and admin" ON public.warning_letters
FOR SELECT TO authenticated
USING (
  is_superadmin() 
  OR is_admin_in_school(school_id) 
  OR teacher_id = auth.uid() 
  OR is_admin()
);

DROP POLICY IF EXISTS "Allow insert warning_letters for admin" ON public.warning_letters;
CREATE POLICY "Allow insert warning_letters for admin" ON public.warning_letters
FOR INSERT TO authenticated
WITH CHECK (
  is_superadmin() 
  OR is_admin_in_school(school_id) 
  OR is_admin()
);

DROP POLICY IF EXISTS "Allow update warning_letters for owner and admin" ON public.warning_letters;
CREATE POLICY "Allow update warning_letters for owner and admin" ON public.warning_letters
FOR UPDATE TO authenticated
USING (
  is_superadmin() 
  OR is_admin_in_school(school_id) 
  OR teacher_id = auth.uid() 
  OR is_admin()
)
WITH CHECK (
  is_superadmin() 
  OR is_admin_in_school(school_id) 
  OR teacher_id = auth.uid() 
  OR is_admin()
);

DROP POLICY IF EXISTS "Allow delete warning_letters for owner and admin" ON public.warning_letters;
CREATE POLICY "Allow delete warning_letters for owner and admin" ON public.warning_letters
FOR DELETE TO authenticated
USING (
  is_superadmin() 
  OR is_admin_in_school(school_id) 
  OR teacher_id = auth.uid() 
  OR is_admin()
);
