-- ============================================================================
-- Migration: signature_url column for users_profile (ADDITIVE, non-destructive)
--
-- Apply this to an EXISTING / live Supabase project via the SQL Editor.
-- `setup.sql` is destructive (it starts with DROP ... CASCADE) and must only
-- ever be run against a fresh project — never on a live database.
--
-- Safe to re-run (idempotent).
-- ============================================================================

-- Add signature_url column to users_profile table
ALTER TABLE public.users_profile
ADD COLUMN IF NOT EXISTS signature_url TEXT;

-- Comment: Captains can upload a signature image for e-signature on
-- document PDFs. The URL points to a PNG in the 'profile-photos' bucket.