-- ====================================================================
-- MIGRASI DATABASES: PENYESUAIAN ROLE ADMIN SEKOLAH & SMKN 11 MALANG
-- ====================================================================

-- 1. Tambahkan kolom school_name pada tabel users jika belum ada
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS school_name text DEFAULT 'SMKN 11 Malang';

-- 2. Update seluruh Guru & User yang ada agar terafiliasi dengan SMKN 11 Malang
UPDATE public.users
SET school_name = 'SMKN 11 Malang'
WHERE school_name IS NULL OR school_name = '';

-- 3. Ubah email dummy Admin dari admin@jurnal.com menjadi smkn11malang@jurnal.com (di public.users)
UPDATE public.users
SET email = 'smkn11malang@jurnal.com',
    full_name = 'Admin SMKN 11 Malang',
    position = 'Admin Sekolah',
    school_name = 'SMKN 11 Malang'
WHERE email = 'admin@jurnal.com';

-- 4. Ubah email dummy Admin pada auth.users (jika ada di Supabase Auth)
UPDATE auth.users
SET email = 'smkn11malang@jurnal.com'
WHERE email = 'admin@jurnal.com';

-- 5. Update trigger handle_new_user agar menyertakan school_name secara otomatis
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email, full_name, role, phone, position, address, photo_url, school_name)
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    COALESCE(new.raw_user_meta_data->>'role', 'pending_guru'),
    new.raw_user_meta_data->>'phone_number',
    new.raw_user_meta_data->>'position',
    new.raw_user_meta_data->>'address',
    new.raw_user_meta_data->>'photo_url',
    COALESCE(new.raw_user_meta_data->>'school_name', 'SMKN 11 Malang')
  )
  ON CONFLICT (id) DO UPDATE SET
    school_name = EXCLUDED.school_name;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
