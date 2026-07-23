-- ============================================================================
-- UPDATE ALL STUDENTS PARENT WHATSAPP NUMBER TO TEST NUMBER (082230090067)
-- ============================================================================

-- 1. Ensure parent_phone_number column exists in students table
ALTER TABLE public.students
ADD COLUMN IF NOT EXISTS parent_phone_number TEXT;

ALTER TABLE public.students
ADD COLUMN IF NOT EXISTS parent_phone TEXT;

-- 2. Update all student records to set parent WhatsApp number to 082230090067
UPDATE public.students
SET 
  parent_phone_number = '082230090067',
  parent_phone = '082230090067';

-- 3. Verification query
SELECT id, name, class_id, parent_phone_number FROM public.students LIMIT 10;
