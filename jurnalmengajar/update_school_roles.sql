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

-- 5. Update trigger handle_new_user agar menyertakan school_name & school_id secara otomatis
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  meta_school_name text;
  meta_school_id_text text;
  meta_school_id_uuid uuid;
  meta_phone text;
BEGIN
  meta_school_name := COALESCE(
    new.raw_user_meta_data->>'school_name',
    new.raw_user_meta_data->>'school',
    new.raw_user_meta_data->>'schoolName'
  );
  
  meta_school_id_text := COALESCE(
    new.raw_user_meta_data->>'school_id',
    new.raw_user_meta_data->>'schoolId'
  );

  IF meta_school_id_text IS NOT NULL AND meta_school_id_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    meta_school_id_uuid := meta_school_id_text::uuid;
  ELSE
    meta_school_id_uuid := NULL;
  END IF;

  meta_phone := COALESCE(
    new.raw_user_meta_data->>'phone',
    new.raw_user_meta_data->>'phone_number',
    new.raw_user_meta_data->>'phoneNumber'
  );

  BEGIN
    INSERT INTO public.users (
      id, email, full_name, role, phone, position, address, photo_url, school_name, school_id
    )
    VALUES (
      new.id,
      new.email,
      COALESCE(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
      COALESCE(new.raw_user_meta_data->>'role', 'pending_guru'),
      meta_phone,
      new.raw_user_meta_data->>'position',
      new.raw_user_meta_data->>'address',
      new.raw_user_meta_data->>'photo_url',
      meta_school_name,
      meta_school_id_uuid
    )
    ON CONFLICT (id) DO UPDATE SET
      full_name = EXCLUDED.full_name,
      role = EXCLUDED.role,
      phone = EXCLUDED.phone,
      position = EXCLUDED.position,
      address = EXCLUDED.address,
      photo_url = EXCLUDED.photo_url,
      school_name = EXCLUDED.school_name,
      school_id = EXCLUDED.school_id;
  EXCEPTION WHEN OTHERS THEN
    BEGIN
      INSERT INTO public.users (id, email, full_name, role, school_name)
      VALUES (
        new.id,
        new.email,
        COALESCE(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
        COALESCE(new.raw_user_meta_data->>'role', 'pending_guru'),
        meta_school_name
      )
      ON CONFLICT (id) DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END;

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
