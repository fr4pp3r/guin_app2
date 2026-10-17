-- ============================================================================
-- Migration: add image support to announcements
-- (CANONICAL, ADDITIVE, non-destructive)
--
-- Adds optional image_url to public.announcements so posts can include images,
-- and creates the `announcement-images` storage bucket that holds them.
--
-- Without the bucket, client uploads fail with a 404 "Record not found"
-- (Supabase Storage returns that when the referenced bucket does not exist),
-- which Helpers.parseSupabaseError then renders as "Record not found".
--
-- Backward compatible: existing rows get NULL, no data changes. Safe to re-run
-- (idempotent). Apply via the SQL Editor on a live project; never run setup.sql
-- against a live database.
-- ============================================================================


-- ============================================================================
-- SECTION 1 — image column
-- ============================================================================

ALTER TABLE public.announcements
  ADD COLUMN IF NOT EXISTS image_url TEXT;


-- ============================================================================
-- SECTION 2 — storage bucket
-- Public, matching every other bucket in this project (see setup.sql §7):
-- "public" means publicly readable URLs. Posting is gated client-side by
-- AppRoles.canPostAnnouncements (captain / secretary / admin).
-- ============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'announcement-images',
  'announcement-images',
  true,
  5242880, -- 5 MB
  ARRAY['image/jpeg','image/jpg','image/png','image/webp','image/gif']
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
                   AND policyname = 'app_access_announcement_images') THEN
    CREATE POLICY "app_access_announcement_images" ON storage.objects FOR ALL
      USING (bucket_id = 'announcement-images')
      WITH CHECK (bucket_id = 'announcement-images');
  END IF;
END $$;