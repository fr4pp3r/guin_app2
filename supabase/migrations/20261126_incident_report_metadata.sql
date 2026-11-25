-- ============================================================================
-- Migration: submission_metadata column for incident_reports (ADDITIVE, non-destructive)
--
-- Apply this to an EXISTING / live Supabase project via the SQL Editor.
-- `setup.sql` is destructive (it starts with DROP ... CASCADE) and must only
-- ever be run against a fresh project — never on a live database.
--
-- Safe to re-run (idempotent).
-- ============================================================================

-- Add submission_metadata JSON column for fraud detection audit trail
ALTER TABLE public.incident_reports
  ADD COLUMN IF NOT EXISTS submission_metadata JSONB;

-- Comment: Stores metadata for fraud detection and audit purposes.
-- Includes client IP hash, device info, submission patterns, and AI fraud flags.

-- Create index for faster metadata queries
CREATE INDEX IF NOT EXISTS idx_incident_reports_submission_metadata 
  ON public.incident_reports USING GIN (submission_metadata);

-- Create index on report hash for duplicate detection
CREATE INDEX IF NOT EXISTS idx_incident_reports_content_hash 
  ON public.incident_reports (content_hash);