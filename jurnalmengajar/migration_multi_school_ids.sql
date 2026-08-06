-- Migration untuk mendukung Multi-School (Array school_ids atau Comma-Separated String)

-- 1. Tambah kolom `school_ids` tipe ARRAY of TEXT / TEXT[] pada tabel `users` (opsional jika disimpan di tabel users)
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS school_ids TEXT[] DEFAULT '{}';

-- 2. Jika kolom `school_id` pada tabel `users` berupa string dipisah koma (misal: '0001, 0002'), 
-- kita bisa mengubah tipe kolom `school_id` atau menggunakan `school_ids` array:
-- Contoh query pencarian user berdasarkan school_id di PostgreSQL/Supabase:
-- A. Jika menggunakan ARRAY `school_ids TEXT[]`:
--    SELECT * FROM users WHERE '0001' = ANY(school_ids);
-- 
-- B. Jika menggunakan STRING dipisah koma `school_id TEXT` (misal '0001, 0002'):
--    SELECT * FROM users WHERE school_id LIKE '%0001%';

-- 3. Membuat fungsi helper / RPC di Supabase untuk query multi-school yang fleksibel:
CREATE OR REPLACE FUNCTION get_users_by_school(target_school_id TEXT)
RETURNS SETOF public.users AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM public.users
  WHERE 
    target_school_id = ANY(school_ids)
    OR school_id LIKE '%' || target_school_id || '%';
END;
$$ LANGUAGE plpgsql;
