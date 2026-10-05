-- ====================================================================
-- MIGRASI: SISTEM HISTORI AKADEMIK SISWA, KENAIKAN KELAS & MUTASI
-- ====================================================================

-- 1. Tambahkan kolom status pada tabel students jika belum ada
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'aktif';

-- 2. Buat tabel student_academic_histories
CREATE TABLE IF NOT EXISTS public.student_academic_histories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    period_id UUID NOT NULL REFERENCES public.periods(id) ON DELETE CASCADE,
    class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
    academic_year VARCHAR(50) NOT NULL,
    class_name VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'aktif', -- 'aktif', 'naik', 'tidak_naik', 'lulus', 'pindah', 'tetap'
    from_period_id UUID REFERENCES public.periods(id) ON DELETE SET NULL,
    from_class_id UUID REFERENCES public.classes(id) ON DELETE SET NULL,
    from_class_name VARCHAR(100),
    to_period_id UUID REFERENCES public.periods(id) ON DELETE SET NULL,
    to_class_id UUID REFERENCES public.classes(id) ON DELETE SET NULL,
    to_class_name VARCHAR(100),
    transfer_date DATE DEFAULT CURRENT_DATE,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT uq_student_period_class UNIQUE (student_id, period_id, class_id)
);

-- Indeks performa
CREATE INDEX IF NOT EXISTS idx_student_hist_student ON public.student_academic_histories(student_id);
CREATE INDEX IF NOT EXISTS idx_student_hist_class ON public.student_academic_histories(class_id);
CREATE INDEX IF NOT EXISTS idx_student_hist_period ON public.student_academic_histories(period_id);
CREATE INDEX IF NOT EXISTS idx_student_hist_school ON public.student_academic_histories(school_id);

-- 3. Row Level Security (RLS) untuk student_academic_histories
ALTER TABLE public.student_academic_histories ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'student_academic_histories' 
          AND policyname = 'Allow select student_academic_histories for authenticated users'
    ) THEN
        CREATE POLICY "Allow select student_academic_histories for authenticated users" 
        ON public.student_academic_histories FOR SELECT TO authenticated USING (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'student_academic_histories' 
          AND policyname = 'Allow insert student_academic_histories for authenticated users'
    ) THEN
        CREATE POLICY "Allow insert student_academic_histories for authenticated users" 
        ON public.student_academic_histories FOR INSERT TO authenticated WITH CHECK (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'student_academic_histories' 
          AND policyname = 'Allow update student_academic_histories for authenticated users'
    ) THEN
        CREATE POLICY "Allow update student_academic_histories for authenticated users" 
        ON public.student_academic_histories FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'student_academic_histories' 
          AND policyname = 'Allow delete student_academic_histories for authenticated users'
    ) THEN
        CREATE POLICY "Allow delete student_academic_histories for authenticated users" 
        ON public.student_academic_histories FOR DELETE TO authenticated USING (true);
    END IF;
END $$;

-- 4. Inisialisasi histori akademik untuk data siswa yang sudah ada (backward compatibility)
INSERT INTO public.student_academic_histories (
    student_id, school_id, period_id, class_id, academic_year, class_name, status, created_at
)
SELECT 
    s.id,
    s.school_id,
    c.period_id,
    c.id,
    p.name,
    c.name,
    COALESCE(s.status, 'aktif'),
    COALESCE(s.created_at, now())
FROM public.students s
JOIN public.classes c ON s.class_id = c.id
JOIN public.periods p ON c.period_id = p.id
WHERE s.school_id IS NOT NULL AND c.period_id IS NOT NULL
ON CONFLICT (student_id, period_id, class_id) DO NOTHING;

-- 5. Trigger pembaruan jumlah siswa di tabel classes yang aman
CREATE OR REPLACE FUNCTION public.update_class_student_count()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    target_class_id UUID;
BEGIN
    target_class_id := COALESCE(NEW.class_id, OLD.class_id);
    IF (target_class_id IS NOT NULL) THEN
        UPDATE public.classes
        SET student_count = GREATEST(
            (SELECT count(*) FROM public.students WHERE class_id = target_class_id),
            (SELECT count(DISTINCT student_id) FROM public.student_academic_histories WHERE class_id = target_class_id)
        )
        WHERE id = target_class_id;
    END IF;
    
    IF (TG_OP = 'UPDATE' AND OLD.class_id IS NOT NULL AND OLD.class_id <> NEW.class_id) THEN
        UPDATE public.classes
        SET student_count = GREATEST(
            (SELECT count(*) FROM public.students WHERE class_id = OLD.class_id),
            (SELECT count(DISTINCT student_id) FROM public.student_academic_histories WHERE class_id = OLD.class_id)
        )
        WHERE id = OLD.class_id;
    END IF;
    RETURN NULL;
END;
$function$;

-- 6. Trigger pada student_academic_histories agar jumlah siswa otomatis tersinkron
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.triggers 
        WHERE trigger_name = 'trigger_sync_class_student_count_history'
    ) THEN
        CREATE TRIGGER trigger_sync_class_student_count_history
        AFTER INSERT OR UPDATE OR DELETE ON public.student_academic_histories
        FOR EACH ROW EXECUTE FUNCTION public.update_class_student_count();
    END IF;
END $$;

-- 7. Stored Procedure Atomik: process_student_promotions
CREATE OR REPLACE FUNCTION public.process_student_promotions(
    p_school_id UUID,
    p_source_period_id UUID,
    p_source_class_id UUID,
    p_target_period_id UUID,
    p_target_class_id UUID,
    p_items JSONB,
    p_transfer_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_source_period_name VARCHAR(100);
    v_source_class_name VARCHAR(100);
    v_target_period_name VARCHAR(100);
    v_target_class_name VARCHAR(100);
    v_item JSONB;
    v_student_id UUID;
    v_status VARCHAR(50);
    v_target_cid UUID;
    v_note TEXT;
    v_processed_count INT := 0;
    v_student_school_id UUID;
    v_actual_target_class_name VARCHAR(100);
    v_actual_target_period_name VARCHAR(100);
    v_actual_target_period_id UUID;
BEGIN
    -- Validasi sumber
    SELECT name INTO v_source_period_name
    FROM public.periods
    WHERE id = p_source_period_id AND (school_id = p_school_id OR school_id IS NULL);
    
    IF v_source_period_name IS NULL THEN
        RAISE EXCEPTION 'Tahun ajaran asal tidak ditemukan atau tidak sesuai sekolah aktif.';
    END IF;

    SELECT name INTO v_source_class_name
    FROM public.classes
    WHERE id = p_source_class_id AND (school_id = p_school_id OR school_id IS NULL);

    IF v_source_class_name IS NULL THEN
        RAISE EXCEPTION 'Kelas asal tidak ditemukan atau tidak sesuai sekolah aktif.';
    END IF;

    -- Validasi target jika ada
    IF p_target_period_id IS NOT NULL THEN
        SELECT name INTO v_target_period_name
        FROM public.periods
        WHERE id = p_target_period_id AND (school_id = p_school_id OR school_id IS NULL);
    END IF;

    IF p_target_class_id IS NOT NULL THEN
        SELECT name INTO v_target_class_name
        FROM public.classes
        WHERE id = p_target_class_id AND (school_id = p_school_id OR school_id IS NULL);
    END IF;

    -- Proses setiap siswa secara atomik
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_student_id := (v_item->>'student_id')::UUID;
        v_status := LOWER(TRIM(v_item->>'status'));
        v_note := v_item->>'note';
        
        IF (v_item ? 'target_class_id' AND v_item->>'target_class_id' IS NOT NULL AND (v_item->>'target_class_id') <> '') THEN
            v_target_cid := (v_item->>'target_class_id')::UUID;
        ELSE
            v_target_cid := p_target_class_id;
        END IF;

        -- Validasi tenant siswa
        SELECT school_id INTO v_student_school_id
        FROM public.students
        WHERE id = v_student_id;

        IF v_student_school_id IS NULL OR (v_student_school_id <> p_school_id AND v_student_school_id IS NOT NULL) THEN
            RAISE EXCEPTION 'Siswa dengan ID % tidak terdaftar di sekolah yang sedang aktif.', v_student_id;
        END IF;

        -- Resolusi info kelas tujuan
        IF v_target_cid IS NOT NULL THEN
            SELECT c.name, p.name, c.period_id 
            INTO v_actual_target_class_name, v_actual_target_period_name, v_actual_target_period_id
            FROM public.classes c
            JOIN public.periods p ON c.period_id = p.id
            WHERE c.id = v_target_cid AND (c.school_id = p_school_id OR c.school_id IS NULL);
        ELSE
            v_actual_target_class_name := NULL;
            v_actual_target_period_name := v_target_period_name;
            v_actual_target_period_id := p_target_period_id;
        END IF;

        -- 1. NAIK KELAS
        IF v_status = 'naik' THEN
            IF v_target_cid IS NULL THEN
                RAISE EXCEPTION 'Kelas tujuan harus dipilih untuk siswa yang naik kelas.';
            END IF;

            -- Update histori kelas asal
            INSERT INTO public.student_academic_histories (
                student_id, school_id, period_id, class_id,
                academic_year, class_name, status,
                to_period_id, to_class_id, to_class_name,
                transfer_date, note, created_at, updated_at
            ) VALUES (
                v_student_id, p_school_id, p_source_period_id, p_source_class_id,
                v_source_period_name, v_source_class_name, 'naik',
                v_actual_target_period_id, v_target_cid, v_actual_target_class_name,
                COALESCE(p_transfer_date, CURRENT_DATE), COALESCE(v_note, 'Naik ke kelas ' || v_actual_target_class_name),
                now(), now()
            )
            ON CONFLICT (student_id, period_id, class_id) DO UPDATE
            SET status = 'naik',
                to_period_id = EXCLUDED.to_period_id,
                to_class_id = EXCLUDED.to_class_id,
                to_class_name = EXCLUDED.to_class_name,
                transfer_date = EXCLUDED.transfer_date,
                note = COALESCE(v_note, 'Naik ke kelas ' || v_actual_target_class_name),
                updated_at = now();

            -- Tambahkan histori aktif di kelas baru
            INSERT INTO public.student_academic_histories (
                student_id, school_id, period_id, class_id,
                academic_year, class_name, status,
                from_period_id, from_class_id, from_class_name,
                transfer_date, note, created_at, updated_at
            ) VALUES (
                v_student_id, p_school_id, v_actual_target_period_id, v_target_cid,
                v_actual_target_period_name, v_actual_target_class_name, 'aktif',
                p_source_period_id, p_source_class_id, v_source_class_name,
                COALESCE(p_transfer_date, CURRENT_DATE), v_note, now(), now()
            )
            ON CONFLICT (student_id, period_id, class_id) DO UPDATE
            SET status = 'aktif',
                from_period_id = EXCLUDED.from_period_id,
                from_class_id = EXCLUDED.from_class_id,
                from_class_name = EXCLUDED.from_class_name,
                updated_at = now();

            -- Update referensi kelas siswa ke kelas baru
            UPDATE public.students
            SET class_id = v_target_cid,
                status = 'aktif'
            WHERE id = v_student_id;

            v_processed_count := v_processed_count + 1;

        -- 2. TIDAK NAIK KELAS
        ELSIF v_status = 'tidak_naik' THEN
            INSERT INTO public.student_academic_histories (
                student_id, school_id, period_id, class_id,
                academic_year, class_name, status,
                to_period_id, to_class_id, to_class_name,
                transfer_date, note, created_at, updated_at
            ) VALUES (
                v_student_id, p_school_id, p_source_period_id, p_source_class_id,
                v_source_period_name, v_source_class_name, 'tidak_naik',
                v_actual_target_period_id, v_target_cid, v_actual_target_class_name,
                COALESCE(p_transfer_date, CURRENT_DATE), COALESCE(v_note, 'Tidak naik kelas'),
                now(), now()
            )
            ON CONFLICT (student_id, period_id, class_id) DO UPDATE
            SET status = 'tidak_naik',
                to_period_id = EXCLUDED.to_period_id,
                to_class_id = EXCLUDED.to_class_id,
                to_class_name = EXCLUDED.to_class_name,
                transfer_date = EXCLUDED.transfer_date,
                note = COALESCE(v_note, 'Tidak naik kelas'),
                updated_at = now();

            IF v_target_cid IS NOT NULL AND v_actual_target_period_id IS NOT NULL THEN
                INSERT INTO public.student_academic_histories (
                    student_id, school_id, period_id, class_id,
                    academic_year, class_name, status,
                    from_period_id, from_class_id, from_class_name,
                    transfer_date, note, created_at, updated_at
                ) VALUES (
                    v_student_id, p_school_id, v_actual_target_period_id, v_target_cid,
                    v_actual_target_period_name, v_actual_target_class_name, 'tidak_naik',
                    p_source_period_id, p_source_class_id, v_source_class_name,
                    COALESCE(p_transfer_date, CURRENT_DATE), COALESCE(v_note, 'Mengulang kelas'),
                    now(), now()
                )
                ON CONFLICT (student_id, period_id, class_id) DO UPDATE
                SET status = 'tidak_naik',
                    note = EXCLUDED.note,
                    updated_at = now();

                UPDATE public.students
                SET class_id = v_target_cid,
                    status = 'aktif'
                WHERE id = v_student_id;
            ELSE
                UPDATE public.students
                SET status = 'aktif'
                WHERE id = v_student_id;
            END IF;

            v_processed_count := v_processed_count + 1;

        -- 3. LULUS
        ELSIF v_status = 'lulus' THEN
            INSERT INTO public.student_academic_histories (
                student_id, school_id, period_id, class_id,
                academic_year, class_name, status,
                transfer_date, note, created_at, updated_at
            ) VALUES (
                v_student_id, p_school_id, p_source_period_id, p_source_class_id,
                v_source_period_name, v_source_class_name, 'lulus',
                COALESCE(p_transfer_date, CURRENT_DATE), COALESCE(v_note, 'Lulus pada tahun ajaran ' || v_source_period_name),
                now(), now()
            )
            ON CONFLICT (student_id, period_id, class_id) DO UPDATE
            SET status = 'lulus',
                transfer_date = EXCLUDED.transfer_date,
                note = COALESCE(v_note, 'Lulus pada tahun ajaran ' || v_source_period_name),
                updated_at = now();

            UPDATE public.students
            SET status = 'lulus'
            WHERE id = v_student_id;

            v_processed_count := v_processed_count + 1;

        -- 4. PINDAH KELAS
        ELSIF v_status = 'pindah' THEN
            IF v_target_cid IS NULL THEN
                RAISE EXCEPTION 'Kelas tujuan harus dipilih untuk siswa yang pindah kelas.';
            END IF;

            INSERT INTO public.student_academic_histories (
                student_id, school_id, period_id, class_id,
                academic_year, class_name, status,
                to_period_id, to_class_id, to_class_name,
                transfer_date, note, created_at, updated_at
            ) VALUES (
                v_student_id, p_school_id, p_source_period_id, p_source_class_id,
                v_source_period_name, v_source_class_name, 'pindah',
                v_actual_target_period_id, v_target_cid, v_actual_target_class_name,
                COALESCE(p_transfer_date, CURRENT_DATE), COALESCE(v_note, 'Pindah ke kelas ' || v_actual_target_class_name),
                now(), now()
            )
            ON CONFLICT (student_id, period_id, class_id) DO UPDATE
            SET status = 'pindah',
                to_period_id = EXCLUDED.to_period_id,
                to_class_id = EXCLUDED.to_class_id,
                to_class_name = EXCLUDED.to_class_name,
                transfer_date = EXCLUDED.transfer_date,
                note = COALESCE(v_note, 'Pindah ke kelas ' || v_actual_target_class_name),
                updated_at = now();

            INSERT INTO public.student_academic_histories (
                student_id, school_id, period_id, class_id,
                academic_year, class_name, status,
                from_period_id, from_class_id, from_class_name,
                transfer_date, note, created_at, updated_at
            ) VALUES (
                v_student_id, p_school_id, v_actual_target_period_id, v_target_cid,
                v_actual_target_period_name, v_actual_target_class_name, 'aktif',
                p_source_period_id, p_source_class_id, v_source_class_name,
                COALESCE(p_transfer_date, CURRENT_DATE), COALESCE(v_note, 'Pindahan dari ' || v_source_class_name),
                now(), now()
            )
            ON CONFLICT (student_id, period_id, class_id) DO UPDATE
            SET status = 'aktif',
                from_period_id = EXCLUDED.from_period_id,
                from_class_id = EXCLUDED.from_class_id,
                from_class_name = EXCLUDED.from_class_name,
                updated_at = now();

            UPDATE public.students
            SET class_id = v_target_cid,
                status = 'aktif'
            WHERE id = v_student_id;

            v_processed_count := v_processed_count + 1;

        -- 5. TETAP
        ELSIF v_status = 'tetap' THEN
            v_processed_count := v_processed_count + 1;
        END IF;

    END LOOP;

    -- Update rekap jumlah siswa
    UPDATE public.classes
    SET student_count = GREATEST(
        (SELECT count(*) FROM public.students WHERE class_id = p_source_class_id),
        (SELECT count(DISTINCT student_id) FROM public.student_academic_histories WHERE class_id = p_source_class_id)
    )
    WHERE id = p_source_class_id;

    IF p_target_class_id IS NOT NULL THEN
        UPDATE public.classes
        SET student_count = GREATEST(
            (SELECT count(*) FROM public.students WHERE class_id = p_target_class_id),
            (SELECT count(DISTINCT student_id) FROM public.student_academic_histories WHERE class_id = p_target_class_id)
        )
        WHERE id = p_target_class_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'processed_count', v_processed_count,
        'message', 'Berhasil memproses status ' || v_processed_count || ' siswa.'
    );
END;
$$;
