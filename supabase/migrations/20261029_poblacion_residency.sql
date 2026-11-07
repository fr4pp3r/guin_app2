-- 20261029_poblacion_residency.sql
-- Poblacion residency flag for users_profile.
-- Migrate existing false values to null (unverified) so current citizens
-- aren't permanently blocked from documents, then make the column nullable
-- so AI can return "unverifiable" instead of defaulting to "not a resident".

-- Add the column first (idempotent: IF NOT EXISTS), without NOT NULL
ALTER TABLE public.users_profile
  ADD COLUMN IF NOT EXISTS is_poblacion_resident BOOLEAN DEFAULT FALSE;

-- Migrate existing false OR null values to null (unverified)
-- Covers cases where DEFAULT didn't backfill existing rows
UPDATE public.users_profile SET is_poblacion_resident = NULL
  WHERE is_poblacion_resident = false
     OR is_poblacion_resident IS NULL;

-- Drop default (column is already nullable from ADD COLUMN without NOT NULL)
ALTER TABLE public.users_profile
  ALTER COLUMN is_poblacion_resident DROP DEFAULT;