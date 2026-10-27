-- Kode gabung guru: kode sederhana dari admin agar guru bisa bergabung
-- ke sekolah tanpa memakai kode asli / kode aktivasi.
-- Cara pakai: jalankan file ini sekali di SQL Editor Supabase (dashboard).
ALTER TABLE schools ADD COLUMN IF NOT EXISTS join_code TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_schools_join_code ON schools (join_code);
