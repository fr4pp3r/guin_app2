-- ============================================================================
-- Migration: per-print document copies (ADDITIVE, non-destructive)
--
-- Apply this to an EXISTING / live Supabase project via the SQL Editor.
-- `setup.sql` is destructive (it starts with DROP ... CASCADE) and must only
-- ever be run against a fresh project — never on a live database.
--
-- Safe to re-run (idempotent).
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.document_print_copies (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id         UUID NOT NULL REFERENCES public.document_requests(id) ON DELETE CASCADE,
  document_id        TEXT NOT NULL,
  verification_token TEXT NOT NULL UNIQUE,
  serial             TEXT NOT NULL,
  copy_number        INTEGER NOT NULL,
  issued_by          UUID REFERENCES public.users_profile(id),
  issued_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_used_at       TIMESTAMPTZ,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (document_id, copy_number)
);

CREATE INDEX IF NOT EXISTS idx_document_print_copies_docid
  ON public.document_print_copies(document_id);

ALTER TABLE public.document_print_copies ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'document_print_copies'
      AND policyname = 'app_access_document_print_copies'
  ) THEN
    CREATE POLICY "app_access_document_print_copies"
      ON public.document_print_copies
      FOR ALL
      USING (true)
      WITH CHECK (true);
  END IF;
END $$;
