-- Storage RLS policies for avatars, school-assets, and journal-attachments
-- Ensures authenticated users can manage their own avatars, school admins can manage
-- their school logos, and teachers/admins can manage journal attachments cleanly.

DROP POLICY IF EXISTS "Public buckets select" ON storage.buckets;
CREATE POLICY "Public buckets select"
  ON storage.buckets
  FOR SELECT
  TO anon, authenticated
  USING (public = true);

-- 1. Public read for public media buckets
DROP POLICY IF EXISTS "Public read public storage buckets" ON storage.objects;
CREATE POLICY "Public read public storage buckets"
  ON storage.objects
  FOR SELECT
  TO anon, authenticated
  USING (bucket_id IN ('avatars', 'school-assets', 'journal-attachments'));

-- 2. Avatars: registration upload (INSERT only for anon with upsert=false)
DROP POLICY IF EXISTS "Anon insert avatars on registration" ON storage.objects;
CREATE POLICY "Anon insert avatars on registration"
  ON storage.objects
  FOR INSERT
  TO anon
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = 'avatars'
  );

-- 3. Avatars: owner & admins can INSERT/UPDATE/DELETE own or managed avatar paths
DROP POLICY IF EXISTS "Authenticated insert avatars" ON storage.objects;
CREATE POLICY "Authenticated insert avatars"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (
      public.is_superadmin()
      OR public.is_admin()
      OR (
        (storage.foldername(name))[1] IN ('avatars', 'users')
        AND (storage.foldername(name))[2] = (select auth.uid())::text
      )
    )
  );

DROP POLICY IF EXISTS "Authenticated update avatars" ON storage.objects;
CREATE POLICY "Authenticated update avatars"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (
      public.is_superadmin()
      OR public.is_admin()
      OR owner = (select auth.uid())
      OR (
        (storage.foldername(name))[1] IN ('avatars', 'users')
        AND (storage.foldername(name))[2] = (select auth.uid())::text
      )
    )
  )
  WITH CHECK (
    bucket_id = 'avatars'
    AND (
      public.is_superadmin()
      OR public.is_admin()
      OR (
        (storage.foldername(name))[1] IN ('avatars', 'users')
        AND (storage.foldername(name))[2] = (select auth.uid())::text
      )
    )
  );

DROP POLICY IF EXISTS "Authenticated delete avatars" ON storage.objects;
CREATE POLICY "Authenticated delete avatars"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (
      public.is_superadmin()
      OR public.is_admin()
      OR owner = (select auth.uid())
      OR (
        (storage.foldername(name))[1] IN ('avatars', 'users')
        AND (storage.foldername(name))[2] = (select auth.uid())::text
      )
    )
  );

-- 4. School Assets: school admins (for their own school) & superadmins can INSERT/UPDATE/DELETE school logos
DROP POLICY IF EXISTS "School admins insert school-assets" ON storage.objects;
CREATE POLICY "School admins insert school-assets"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'school-assets'
    AND (
      public.is_superadmin()
      OR (
        (storage.foldername(name))[1] = 'schools'
        AND public.is_admin_in_school((storage.foldername(name))[2])
      )
    )
  );

DROP POLICY IF EXISTS "School admins update school-assets" ON storage.objects;
CREATE POLICY "School admins update school-assets"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'school-assets'
    AND (
      public.is_superadmin()
      OR (
        (storage.foldername(name))[1] = 'schools'
        AND public.is_admin_in_school((storage.foldername(name))[2])
      )
    )
  )
  WITH CHECK (
    bucket_id = 'school-assets'
    AND (
      public.is_superadmin()
      OR (
        (storage.foldername(name))[1] = 'schools'
        AND public.is_admin_in_school((storage.foldername(name))[2])
      )
    )
  );

DROP POLICY IF EXISTS "School admins delete school-assets" ON storage.objects;
CREATE POLICY "School admins delete school-assets"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'school-assets'
    AND (
      public.is_superadmin()
      OR (
        (storage.foldername(name))[1] = 'schools'
        AND public.is_admin_in_school((storage.foldername(name))[2])
      )
    )
  );

-- 5. Journal Attachments: journal owner teacher & school admin can INSERT/UPDATE/DELETE
DROP POLICY IF EXISTS "Journal writers insert attachments" ON storage.objects;
CREATE POLICY "Journal writers insert attachments"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'journal-attachments'
    AND (
      public.is_superadmin()
      OR EXISTS (
        SELECT 1 FROM public.journals j
        WHERE j.id::text = (storage.foldername(name))[1]
          AND (
            j.teacher_id = (select auth.uid())
            OR public.is_admin_in_school(j.school_id)
          )
      )
    )
  );

DROP POLICY IF EXISTS "Journal writers update attachments" ON storage.objects;
CREATE POLICY "Journal writers update attachments"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'journal-attachments'
    AND (
      public.is_superadmin()
      OR owner = (select auth.uid())
      OR EXISTS (
        SELECT 1 FROM public.journals j
        WHERE j.id::text = (storage.foldername(name))[1]
          AND (
            j.teacher_id = (select auth.uid())
            OR public.is_admin_in_school(j.school_id)
          )
      )
    )
  )
  WITH CHECK (
    bucket_id = 'journal-attachments'
    AND (
      public.is_superadmin()
      OR EXISTS (
        SELECT 1 FROM public.journals j
        WHERE j.id::text = (storage.foldername(name))[1]
          AND (
            j.teacher_id = (select auth.uid())
            OR public.is_admin_in_school(j.school_id)
          )
      )
    )
  );

DROP POLICY IF EXISTS "Journal writers delete attachments" ON storage.objects;
CREATE POLICY "Journal writers delete attachments"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'journal-attachments'
    AND (
      public.is_superadmin()
      OR owner = (select auth.uid())
      OR EXISTS (
        SELECT 1 FROM public.journals j
        WHERE j.id::text = (storage.foldername(name))[1]
          AND (
            j.teacher_id = (select auth.uid())
            OR public.is_admin_in_school(j.school_id)
          )
      )
    )
  );

