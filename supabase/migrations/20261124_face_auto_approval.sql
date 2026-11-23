-- ============================================================================
-- Migration: Face auto-approval schema
-- (ADDITIVE, non-destructive, idempotent)
--
-- 1. `kyc_enrolled_face_score` / `kyc_enrolled_face_at` on
--    `public.users_profile`: the 1:N match (signup selfie vs. an official's
--    enrolled face sample) recorded when the AI path runs. Unlike the
--    advisory `kyc_face_match_score` (selfie vs. ID portrait), a high
--    enrolled-match score gates `ai_verified` auto-approval. NULL = not
--    evaluated; existing rows keep NULL.
-- 2. `public.face_enrollments`: official-enrolled face samples (one row per
--    resident, embedding as double precision[]).
-- 3. Private `face-samples` storage bucket for the enrolled selfie photos.
--
-- Safe on existing data: every statement is IF NOT EXISTS / DO NOTHING.
-- Apply via the SQL Editor; never run setup.sql against a live database.
-- ============================================================================

ALTER TABLE public.users_profile
  ADD COLUMN IF NOT EXISTS kyc_enrolled_face_score DOUBLE PRECISION;

ALTER TABLE public.users_profile
  ADD COLUMN IF NOT EXISTS kyc_enrolled_face_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS public.face_enrollments (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name            TEXT NOT NULL,
  full_name_normalized TEXT NOT NULL,
  dob                  DATE NOT NULL,
  embedding            DOUBLE PRECISION[] NOT NULL,
  photo_path           TEXT NOT NULL,
  enrolled_by          UUID REFERENCES public.users_profile(id),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS face_enrollments_name_idx
  ON public.face_enrollments(full_name_normalized);

-- RLS enabled with ZERO policies: a deliberate deviation from the house
-- USING (true) pattern. The rows hold face embeddings (biometric data), so
-- no client role may read or write this table; the face-match edge function
-- reaches it via the service-role key, which bypasses RLS.
ALTER TABLE public.face_enrollments ENABLE ROW LEVEL SECURITY;

-- Private bucket: no public URLs and no storage policy — uploads and reads
-- happen only through the service-role face-match function.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'face-samples',
  'face-samples',
  false,
  5242880,
  ARRAY['image/jpeg','image/jpg','image/png']
)
ON CONFLICT (id) DO NOTHING;
