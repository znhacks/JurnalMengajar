-- ====================================================================
-- MIGRASI DATABASE MULTI-TENANT, MULTI-ROLE & INVITATION SYSTEM
-- ====================================================================

-- 1. TABEL SEKOLAH (TENANTS)
CREATE TABLE IF NOT EXISTS public.schools (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT UNIQUE NOT NULL,
    address TEXT,
    subscription_plan TEXT DEFAULT 'free', -- 'free', 'pro', 'enterprise'
    subscription_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Inisialisasi Sekolah bawaan jika belum ada
INSERT INTO public.schools (id, name, code, subscription_plan)
VALUES ('a1111111-1111-1111-1111-111111111111', 'SMKN 11 Malang', 'SCH-SMKN11', 'free')
ON CONFLICT (code) DO NOTHING;

-- 2. TABEL MEMBERSHIP SEKOLAH & ROLE (MULTI-TENANT ROLES)
CREATE TABLE IF NOT EXISTS public.school_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'guru', -- 'admin' | 'guru' | 'superadmin'
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, school_id)
);

-- 3. TABEL KODE UNDANGAN SEKOLAH (INVITATION CODES)
CREATE TABLE IF NOT EXISTS public.school_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    code VARCHAR(30) UNIQUE NOT NULL,
    role TEXT NOT NULL DEFAULT 'guru',
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    max_uses INT DEFAULT 0, -- 0 = unlimited
    used_count INT DEFAULT 0,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Inisialisasi contoh kode undangan untuk SMKN 11 Malang
INSERT INTO public.school_invitations (school_id, code, role)
VALUES ('a1111111-1111-1111-1111-111111111111', 'JOIN-SMKN11-GURU', 'guru'),
       ('a1111111-1111-1111-1111-111111111111', 'JOIN-SMKN11-ADMIN', 'admin')
ON CONFLICT (code) DO NOTHING;

-- 4. TAMBAHKAN KOLOM SCHOOL_ID PADA ENTITAS UTAMA UNTUK ISOLASI DATA
ALTER TABLE public.schedules ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) DEFAULT 'a1111111-1111-1111-1111-111111111111';
ALTER TABLE public.classes ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) DEFAULT 'a1111111-1111-1111-1111-111111111111';
ALTER TABLE public.subjects ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) DEFAULT 'a1111111-1111-1111-1111-111111111111';
ALTER TABLE public.journals ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) DEFAULT 'a1111111-1111-1111-1111-111111111111';
ALTER TABLE public.settings ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) DEFAULT 'a1111111-1111-1111-1111-111111111111';
ALTER TABLE public.periods ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) DEFAULT 'a1111111-1111-1111-1111-111111111111';
ALTER TABLE public.lesson_hours ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) DEFAULT 'a1111111-1111-1111-1111-111111111111';

-- Migrasi existing users ke school_memberships
INSERT INTO public.school_memberships (user_id, school_id, role)
SELECT id, 'a1111111-1111-1111-1111-111111111111', COALESCE(role, 'guru')
FROM public.users
ON CONFLICT (user_id, school_id) DO NOTHING;
