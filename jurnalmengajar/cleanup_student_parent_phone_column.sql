-- ============================================================================
-- CLEANUP: REMOVE REDUNDANT parent_phone COLUMN IN STUDENTS TABLE
-- Keep only 1 official column: parent_phone_number
-- ============================================================================

-- 1. Copy data to parent_phone_number if needed
UPDATE public.students
SET parent_phone_number = parent_phone
WHERE parent_phone_number IS NULL AND parent_phone IS NOT NULL;

-- 2. Drop duplicate parent_phone column
ALTER TABLE public.students
DROP COLUMN IF EXISTS parent_phone;

-- 3. Verify final schema
SELECT id, name, parent_phone_number FROM public.students LIMIT 5;
