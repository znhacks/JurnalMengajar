-- ====================================================================
-- MIGRATION: Multi-Tenant & Multi-School Array Support + RLS Hardening
-- Mendukung user dengan role ganda (Guru & Admin) dan multi-sekolah
-- ====================================================================

-- 1. Tambah kolom `school_ids` tipe ARRAY of TEXT / TEXT[] pada tabel `users`
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS school_ids TEXT[] DEFAULT '{}';

-- 2. Helper function: user_has_school_access(target_school_id)
-- Mengecek apakah user yang sedang login (auth.uid()) memiliki akses ke sekolah tertentu.
-- Aman terhadap tipe data Array, JSON, string koma, maupun tabel relasi (user_schools / school_memberships).
CREATE OR REPLACE FUNCTION public.user_has_school_access(target_school_id TEXT)
RETURNS boolean AS $$
DECLARE
  current_uid UUID;
  user_role TEXT;
  user_single_school TEXT;
  user_array_schools TEXT[];
BEGIN
  current_uid := auth.uid();
  IF current_uid IS NULL THEN
    RETURN false;
  END IF;

  -- 1. Cek apakah Superadmin (selalu punya akses penuh)
  SELECT role, school_id, school_ids INTO user_role, user_single_school, user_array_schools
  FROM public.users
  WHERE id = current_uid;

  IF user_role = 'superadmin' THEN
    RETURN true;
  END IF;

  -- 2. Cek kecocokan di tabel user_schools
  IF EXISTS (
    SELECT 1 FROM public.user_schools
    WHERE user_id = current_uid 
      AND (school_id = target_school_id OR school_id = target_school_id::text)
      AND status = 'active'
  ) THEN
    RETURN true;
  END IF;

  -- 3. Cek kecocokan di tabel school_memberships
  IF EXISTS (
    SELECT 1 FROM public.school_memberships
    WHERE user_id = current_uid 
      AND (school_id = target_school_id OR school_id = target_school_id::text)
  ) THEN
    RETURN true;
  END IF;

  -- 4. Cek kecocokan di kolom users.school_id (baik single ID maupun string koma)
  IF user_single_school IS NOT NULL AND (
    user_single_school = target_school_id 
    OR user_single_school LIKE '%' || target_school_id || '%'
  ) THEN
    RETURN true;
  END IF;

  -- 5. Cek kecocokan di array users.school_ids
  IF user_array_schools IS NOT NULL AND target_school_id = ANY(user_array_schools) THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Contoh RLS Policy yang aman menggunakan user_has_school_access:
-- Jadwal (schedules)
-- CREATE POLICY "Allow select schedules for school members" ON public.schedules
--   FOR SELECT TO authenticated
--   USING (school_id IS NULL OR public.user_has_school_access(school_id::text));

-- 4. Helper RPC untuk mengambil semua user berdasarkan target_school_id (Array & Relasi aware):
CREATE OR REPLACE FUNCTION public.get_users_by_school(target_school_id TEXT)
RETURNS SETOF public.users AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT u.* 
  FROM public.users u
  LEFT JOIN public.user_schools us ON us.user_id = u.id
  LEFT JOIN public.school_memberships sm ON sm.user_id = u.id
  WHERE 
    u.school_id = target_school_id
    OR u.school_id LIKE '%' || target_school_id || '%'
    OR target_school_id = ANY(u.school_ids)
    OR us.school_id = target_school_id
    OR sm.school_id = target_school_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

