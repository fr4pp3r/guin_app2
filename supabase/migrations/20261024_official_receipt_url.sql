-- 20261024_official_receipt_url.sql
-- Official (barangay-issued) receipt image uploaded by the treasurer inside the
-- Confirm Payment dialog. Additive only — apply via the SQL Editor on live DBs
-- BEFORE shipping the build that writes this column; the confirm flow updates
-- document_requests with it and would fail with "column does not exist".
-- No new bucket: the image lives in the existing public `payment-receipts`
-- bucket under a request-scoped path (<request_id>/official_<ts>.<ext>).
-- Who/when is already captured by payment_verified_by / payment_verified_at.

ALTER TABLE document_requests
  ADD COLUMN IF NOT EXISTS official_receipt_url TEXT;
