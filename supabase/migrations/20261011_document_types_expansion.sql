-- ============================================================================
-- Migration: Expand canonical document types from 4 to 9 + fee seed update
-- (ADDITIVE, non-destructive)
--
-- setup.sql now defines the full 9-value public.document_type enum and seeds
-- fees for the new types, but a live DB created before this work still has the
-- 4-value enum and no rows in document_fees for the new types.
--
-- Safe to re-run (idempotent). Apply via the SQL Editor on a live project;
-- never run setup.sql against a live database.
--
-- NOTE (Postgres rule): ALTER TYPE ... ADD VALUE cannot run inside a
-- transaction that also uses the new value. The Supabase SQL Editor
-- autocommits each statement, so the ALTER statements are listed first and
-- each runs on its own before the fee upserts below.
-- ============================================================================

-- Extend the enum with the new canonical types ------------------------------
ALTER TYPE public.document_type ADD VALUE IF NOT EXISTS 'business_clearance';
ALTER TYPE public.document_type ADD VALUE IF NOT EXISTS 'certification';
ALTER TYPE public.document_type ADD VALUE IF NOT EXISTS 'oath_undertaking';
ALTER TYPE public.document_type ADD VALUE IF NOT EXISTS 'good_moral';
ALTER TYPE public.document_type ADD VALUE IF NOT EXISTS 'residency';

-- Seed/refresh default fees (admin-editable via the Document Fees screen) ----
INSERT INTO public.document_fees (document_type, fee_amount, description) VALUES
  ('barangay_clearance', 75.00,  'Barangay Clearance Fee'),
  ('business_clearance',  0.00,  'Barangay Business Clearance Fee (Admin Sets)'),
  ('certification',       0.00,  'Barangay Certification Fee (Admin Sets)'),
  ('oath_undertaking',    0.00,  'Oath of Undertaking (Free)'),
  ('good_moral',         75.00,  'Certificate of Good Moral Character Fee'),
  ('residency',           0.00,  'Certificate of Residency Fee (Admin Sets)')
ON CONFLICT (document_type) DO UPDATE
  SET fee_amount  = EXCLUDED.fee_amount,
      description = EXCLUDED.description;