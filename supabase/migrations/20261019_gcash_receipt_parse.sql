-- ============================================================================
-- Migration: Add GCash receipt parsing fields to document_requests
-- (ADDITIVE, non-destructive)
-- ============================================================================
BEGIN;

ALTER TABLE public.document_requests
  ADD COLUMN IF NOT EXISTS payment_parsed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS payment_parsed_confidence DECIMAL(3,2)
    CHECK (payment_parsed_confidence >= 0 AND payment_parsed_confidence <= 1),
  ADD COLUMN IF NOT EXISTS payment_parse_error TEXT,
  ADD COLUMN IF NOT EXISTS receipt_parse JSONB;

COMMIT;
