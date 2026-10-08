-- ============================================================================
-- Migration: release/verification policy columns on parent tables
-- (ADDITIVE, non-destructive)
--
-- `releaseDocument` (document_service.dart) writes expires_at / single_use /
-- max_uses / use_count and the verification/consume paths write use_count /
-- used_at against BOTH document_requests and document_verifications. These
-- columns were added to setup.sql (destructive, fresh-project only) but no
-- additive migration shipped them, so a live DB that was created before that
-- work fails every release with "column ... does not exist".
--
-- Safe to re-run (idempotent). Apply alongside
-- 20261007_document_print_copies.sql via the SQL Editor.
-- ============================================================================

-- document_requests ---------------------------------------------------------
ALTER TABLE public.document_requests
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS single_use BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS max_uses INTEGER,
  ADD COLUMN IF NOT EXISTS use_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS used_at TIMESTAMPTZ;

-- document_verifications ----------------------------------------------------
ALTER TABLE public.document_verifications
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS single_use BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS max_uses INTEGER,
  ADD COLUMN IF NOT EXISTS use_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS used_at TIMESTAMPTZ;

-- scan / consume path looks up by verification token (setup.sql:520)
CREATE INDEX IF NOT EXISTS idx_document_verifications_token
  ON public.document_verifications(verification_token);