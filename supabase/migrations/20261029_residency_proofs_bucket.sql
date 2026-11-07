-- 20261029_residency_proofs_bucket.sql
-- Creates the `residency-proofs` storage bucket for citizen residency proof uploads.
-- This is a manual step because setup.sql does not create storage buckets.
-- Without the bucket, client uploads fail with a 404 "Record not found"
-- (Supabase Storage returns that when the referenced bucket does not exist).

-- SECTION 1 - storage bucket
-- Public, matching every other bucket in this project (see setup.sql §7):
-- 5MB limit, image-only
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'residency-proofs',
  'residency-proofs',
  true,
  5242880,
  ARRAY['image/jpeg','image/jpg','image/png','image/webp']
)
ON CONFLICT (id) DO UPDATE
  SET public             = EXCLUDED.public,
      file_size_limit    = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- storage.objects is owned by Supabase, so the policy is created idempotently
-- (CREATE POLICY has no IF NOT EXISTS support).
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies
                 WHERE tablename = 'objects'
                   AND policyname = 'app_access_residency_proofs') THEN
    CREATE POLICY "app_access_residency_proofs" ON storage.objects FOR ALL
      USING (bucket_id = 'residency-proofs')
      WITH CHECK (bucket_id = 'residency-proofs');
  END IF;
END $$;