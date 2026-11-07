-- 20261029_document_ai_review.sql
-- AI review result for document_requests. Additive only — apply via the SQL
-- Editor on live DBs before shipping the build that writes this column.

ALTER TABLE public.document_requests
  ADD COLUMN IF NOT EXISTS ai_review JSONB;
