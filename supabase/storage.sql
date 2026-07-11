-- ============================================================
-- SHIPPING HUB - Storage: package-photos bucket
-- Run in the SQL Editor (or apply_migration). Idempotent.
-- ============================================================
-- Path convention: {operator_id}/{package_id}.jpg
-- Bucket is public-read (photos are referenced by unguessable UUID paths and
-- shown on the customer tracking page); writes are restricted per operator.

INSERT INTO storage.buckets (id, name, public)
VALUES ('package-photos', 'package-photos', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Operators may write only under their own {operator_id}/ folder.
DROP POLICY IF EXISTS "package_photos_insert_own" ON storage.objects;
CREATE POLICY "package_photos_insert_own"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'package-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "package_photos_update_own" ON storage.objects;
CREATE POLICY "package_photos_update_own"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'package-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'package-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "package_photos_delete_own" ON storage.objects;
CREATE POLICY "package_photos_delete_own"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'package-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Public read for the bucket's objects (tracking page + cross-device display).
DROP POLICY IF EXISTS "package_photos_public_read" ON storage.objects;
CREATE POLICY "package_photos_public_read"
  ON storage.objects FOR SELECT TO public
  USING (bucket_id = 'package-photos');
