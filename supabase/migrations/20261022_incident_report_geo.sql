-- ============================================================================
-- Migration: Optional GPS map pin on incident reports
-- (ADDITIVE, non-destructive)
--
-- Adds `latitude` / `longitude` to `public.incident_reports`: the map pin a
-- reporter may drop on submit. Both are NULL for legacy rows and whenever the
-- reporter skips the map, so reporting is never blocked when GPS is missing.
--
-- Safe on existing data (idempotent): both columns are nullable and added with
-- IF NOT EXISTS, so existing rows keep NULL. Apply via the SQL Editor; never
-- run setup.sql against a live database.
-- ============================================================================

ALTER TABLE public.incident_reports
  ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;

ALTER TABLE public.incident_reports
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
