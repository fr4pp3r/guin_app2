-- ============================================================================
-- Migration PART 2 of 2: seed/refresh default fees for the document types
-- (ADDITIVE, non-destructive)
--
-- Run THIS FILE ONLY AFTER supabase/migrations/20261011_document_types_enum.sql
-- has completed successfully (the 5 new enum values must already be committed;
-- otherwise the SQL editor aborts with 55P04 "unsafe use of new value").
--
-- Safe to re-run (idempotent). Fees remain admin-editable via the
-- Document Fees screen in the app.
-- ============================================================================

INSERT INTO public.document_fees (document_type, fee_amount, is_free, description) VALUES
  ('barangay_clearance', 75.00,  FALSE, 'Barangay Clearance Fee'),
  ('business_clearance',  100.00, FALSE, 'Barangay Business Clearance Fee'),
  ('certification',       0.00,  FALSE, 'Barangay Certification Fee (Admin Sets)'),
  ('oath_undertaking',    0.00,  TRUE,  'Oath of Undertaking (Free)'),
  ('good_moral',         75.00,  FALSE, 'Certificate of Good Moral Character Fee'),
  ('residency',           0.00,  FALSE, 'Certificate of Residency Fee (Admin Sets)')
ON CONFLICT (document_type) DO UPDATE
  SET fee_amount  = EXCLUDED.fee_amount,
      is_free     = EXCLUDED.is_free,
      description = EXCLUDED.description;