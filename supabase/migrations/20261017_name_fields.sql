-- ============================================================================
-- Migration: Split full_name into given_name, middle_name, last_name
-- (ADDITIVE, non-destructive)
--
-- Safe to re-run (idempotent). Apply via the SQL Editor on a live project;
-- never run setup.sql against a live database.
-- ============================================================================

-- Add the three name parts
ALTER TABLE public.users_profile
  ADD COLUMN IF NOT EXISTS given_name  TEXT,
  ADD COLUMN IF NOT EXISTS middle_name TEXT,
  ADD COLUMN IF NOT EXISTS last_name   TEXT;

-- Backfill from existing full_name for rows that have it but no parts yet.
-- Simple heuristic: split on spaces; first token -> given, last -> last, middle = rest.
-- This is best-effort; admins can correct afterward.
DO $$
DECLARE
  rec RECORD;
  parts TEXT[];
BEGIN
  FOR rec IN
    SELECT id, full_name
      FROM public.users_profile
     WHERE full_name IS NOT NULL
       AND (given_name IS NULL OR middle_name IS NULL OR last_name IS NULL)
  LOOP
    parts := string_to_array(trim(rec.full_name), ' ');
    IF array_length(parts, 1) >= 2 THEN
      UPDATE public.users_profile
         SET given_name  = parts[1],
             middle_name = (SELECT string_agg(p, ' ') FROM unnest(parts[2:array_length(parts,1)-1]) p),
             last_name   = parts[array_length(parts, 1)]
       WHERE id = rec.id;
    ELSIF array_length(parts, 1) = 1 THEN
      UPDATE public.users_profile
         SET given_name = parts[1]
       WHERE id = rec.id;
    END IF;
  END LOOP;
END $$;

-- Keep full_name in sync going forward (generated column would be ideal but
-- Postgres 12+ supports it; we use a trigger for broader compatibility).
-- First, create the sync function.
CREATE OR REPLACE FUNCTION public.sync_full_name()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.full_name := concat_ws(' ',
    NEW.given_name,
    NULLIF(NEW.middle_name, ''),
    NEW.last_name
  );
  RETURN NEW;
END $$;

-- Drop any existing trigger to make this re-runnable.
DROP TRIGGER IF EXISTS trg_users_profile_sync_full_name ON public.users_profile;

CREATE TRIGGER trg_users_profile_sync_full_name
  BEFORE INSERT OR UPDATE ON public.users_profile
  FOR EACH ROW EXECUTE FUNCTION public.sync_full_name();

-- Also keep the updated_at trigger firing (already exists from setup.sql;
-- this just ensures our trigger runs alongside it).