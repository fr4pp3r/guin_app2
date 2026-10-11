-- ============================================================================
-- Migration: Add valid_id_back_url to users_profile
-- (ADDITIVE, non-destructive)
-- ============================================================================

ALTER TABLE public.users_profile
  ADD COLUMN IF NOT EXISTS valid_id_back_url TEXT;