-- ============================================================================
-- Migration: Explicit "free document" tag on document fees
-- (ADDITIVE, non-destructive)
--
-- Adds `is_free` to `public.document_fees` so officials tag a document as
-- free instead of relying only on fee_amount == 0. The tag is the source of
-- admin intent: when applied, the same UPDATE also writes fee_amount to 0.00
-- (downstream everything already treats 0 as free). Safe on existing data:
-- the column is NOT NULL DEFAULT FALSE and legacy zero-fee rows are
-- backfilled to is_free = TRUE. Apply via the SQL Editor; never run setup.sql
-- against a live database.
-- ============================================================================

ALTER TABLE public.document_fees
  ADD COLUMN IF NOT EXISTS is_free BOOLEAN NOT NULL DEFAULT FALSE;

-- Backfill: rows already priced at 0.00 are considered free.
UPDATE public.document_fees
   SET is_free = TRUE, fee_amount = 0.00
 WHERE fee_amount = 0;
