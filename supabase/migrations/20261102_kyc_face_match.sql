-- ============================================================================
-- Migration: KYC face-match score on user profiles
-- (ADDITIVE, non-destructive)
--
-- Adds `kyc_face_match_score` / `kyc_face_match_at` to `public.users_profile`:
-- the on-device 1:1 face match (registration selfie vs. ID portrait) recorded
-- at sign-up. NULL means "not evaluated" — unsupported platform, no usable
-- face, or any detector error. The score (cosine similarity in [-1, 1]) is
-- ADVISORY: it is shown to the reviewer and never gates approval.
--
-- Safe on existing data (idempotent): both columns are nullable and added with
-- IF NOT EXISTS, so existing rows keep NULL. Apply via the SQL Editor; never
-- run setup.sql against a live database.
-- ============================================================================

ALTER TABLE public.users_profile
  ADD COLUMN IF NOT EXISTS kyc_face_match_score DOUBLE PRECISION;

ALTER TABLE public.users_profile
  ADD COLUMN IF NOT EXISTS kyc_face_match_at TIMESTAMPTZ;
