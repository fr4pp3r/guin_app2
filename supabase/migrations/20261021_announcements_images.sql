-- ============================================================================
-- Migration: add image support to announcements
-- (CANONICAL, ADDITIVE, non-destructive)
--
-- Adds optional image_url to public.announcements so posts can include images.
-- Backward compatible: existing rows get NULL, no data changes.
--
-- Safe to re-run (idempotent).
-- ============================================================================

ALTER TABLE public.announcements
  ADD COLUMN IF NOT EXISTS image_url TEXT;