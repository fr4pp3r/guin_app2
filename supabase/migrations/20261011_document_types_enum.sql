-- ============================================================================
-- Migration PART 1 of 2: add the 5 new document types to the enum
-- (ADDITIVE, non-destructive)
--
-- Run THIS FILE FIRST, wait for it to complete, THEN run:
--   supabase/migrations/20261011_document_types_fees.sql
--
-- WHY TWO FILES: Postgres rule 55P04 — a value added with
-- ALTER TYPE ... ADD VALUE cannot be USED in the same transaction that adds
-- it. The Supabase SQL Editor executes the whole pasted script inside one
-- transaction, so the enum additions must commit on their own before any
-- statement (like the fee upserts) references the new values.
--
-- Safe to re-run (idempotent). Apply via the SQL Editor on a live project;
-- never run setup.sql against a live database.
-- ============================================================================

ALTER TYPE public.document_type ADD VALUE IF NOT EXISTS 'business_clearance';
ALTER TYPE public.document_type ADD VALUE IF NOT EXISTS 'certification';
ALTER TYPE public.document_type ADD VALUE IF NOT EXISTS 'oath_undertaking';
ALTER TYPE public.document_type ADD VALUE IF NOT EXISTS 'good_moral';
ALTER TYPE public.document_type ADD VALUE IF NOT EXISTS 'residency';