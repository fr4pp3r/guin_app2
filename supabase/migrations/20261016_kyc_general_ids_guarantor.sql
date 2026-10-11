-- ============================================================================
-- Migration: KYC for general government IDs + guarantor sponsorship
-- (CANONICAL, ADDITIVE, non-destructive apart from the explicitly listed
--  cleanup of superseded KYC draft columns)
--
-- This file REPLACES three earlier, mutually contradictory drafts:
--   20261010_kyc_columns.sql        (Barangay-ID template matching)
--   20261010_kyc_general_ids.sql    (general IDs, kyc_guarantors)
--   20261015_kyc_generalization.sql (id_type/id_number/face_verified/guarantor_id)
-- They have been deleted. Apply this file instead; do not run the old ones.
--
-- FINAL DESIGN
--   1. Registration accepts ANY valid government ID. There is NO template
--      match against a captain-uploaded sample and NO face-match step; the
--      `id-verifier` AI task sanity-checks the document against the DECLARED
--      id_type and reports a passive liveness/anti-spoof signal only.
--      `barangay_config.sample_barangay_id_front_url` /
--      `sample_barangay_id_back_url` are therefore DEPRECATED and unused;
--      they are kept so a captain's earlier upload is not lost.
--   2. An indigent registrant who has no ID is registered by a GUARANTOR who
--      is an EXISTING APPROVED user. The guarantor's details live on their own
--      `kyc_guarantors` row (never on the registrant's users_profile) and the
--      guarantee NEVER auto-approves — it always lands in the captain's
--      pending queue.
--
-- Safe to re-run (idempotent): every statement is IF EXISTS / IF NOT EXISTS
-- guarded, or DROP ... IF EXISTS followed by ADD. Apply via the SQL Editor on
-- a live project; never run setup.sql against a live database.
-- ============================================================================


-- ============================================================================
-- SECTION 2 — users_profile: KYC columns
-- ============================================================================
-- kyc_id_type accepts the canonical whitelist used app-wide (and by
-- kyc_guarantors.guarantor_id_type below):
--   barangay_id, drivers_license, passport, national_id, umid, prc, sss,
--   philhealth, postal_id, voters_id, other
-- Kept in sync with ID_TYPES in supabase/functions/ai/_kyc.ts.
--
-- Columns are added WITHOUT inline CHECK constraints so that the named
-- constraints below can be dropped and re-created on every run (that is what
-- makes this file idempotent *and* lets it repair a half-applied draft).

ALTER TABLE public.users_profile
  ADD COLUMN IF NOT EXISTS kyc_id_type       TEXT,
  ADD COLUMN IF NOT EXISTS kyc_id_number     TEXT,
  ADD COLUMN IF NOT EXISTS id_issued_at      DATE,
  ADD COLUMN IF NOT EXISTS id_expiry_at      DATE,
  ADD COLUMN IF NOT EXISTS liveness_verified BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS liveness_verified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS kyc_method        TEXT,
  ADD COLUMN IF NOT EXISTS kyc_ai_result     JSONB,
  ADD COLUMN IF NOT EXISTS is_indigent       BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS indigency_reason  TEXT,
  ADD COLUMN IF NOT EXISTS kyc_verified_at   TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS kyc_reviewed_by   UUID REFERENCES public.users_profile(id),
  ADD COLUMN IF NOT EXISTS kyc_rejection_reason TEXT,
  -- Deprecated: superseded by kyc_id_type/kyc_id_number. Kept so older rows and
  -- the legacy user_profile model keep working; no code writes it any more.
  ADD COLUMN IF NOT EXISTS barangay_id_number TEXT;

-- A draft may have added liveness_verified / is_indigent as nullable. NULL
-- means "not verified / not indigent", so backfill to FALSE, then make sure
-- the canonical DEFAULT is in place.
UPDATE public.users_profile
   SET liveness_verified = FALSE
 WHERE liveness_verified IS NULL;

UPDATE public.users_profile
   SET is_indigent = FALSE
 WHERE is_indigent IS NULL;

ALTER TABLE public.users_profile
  ALTER COLUMN liveness_verified SET DEFAULT FALSE,
  ALTER COLUMN is_indigent       SET DEFAULT FALSE;

-- Backfill the 'postal' -> 'postal_id' rename from the earlier draft so the
-- canonical CHECK below cannot be violated by a legacy row.
UPDATE public.users_profile
   SET kyc_id_type = 'postal_id'
 WHERE kyc_id_type = 'postal';

-- Widen a stale 3-value kyc_method CHECK from the 20261010 draft.
ALTER TABLE public.users_profile
  DROP CONSTRAINT IF EXISTS users_profile_kyc_method_check;

-- Repair/canonicalise the id-type CHECK (the draft used 'postal', not
-- 'postal_id', and omitted 'voters_id').
ALTER TABLE public.users_profile
  DROP CONSTRAINT IF EXISTS users_profile_kyc_id_type_check;

ALTER TABLE public.users_profile
  ADD CONSTRAINT users_profile_kyc_id_type_check
    CHECK (kyc_id_type IS NULL OR kyc_id_type IN (
      'barangay_id', 'drivers_license', 'passport', 'national_id',
      'umid', 'prc', 'sss', 'philhealth', 'postal_id', 'voters_id',
      'other'
    ));

ALTER TABLE public.users_profile
  ADD CONSTRAINT users_profile_kyc_method_check
    CHECK (kyc_method IS NULL OR kyc_method IN (
      'ai_verified', 'manual_verified', 'indigent_bypass',
      'guarantor_verified'
    ));

-- Superseded draft columns. The final design has NO separate guarantor AI
-- result and NO face-match step, so these must not survive. Each DROP is
-- guarded so this file still runs on a database that never had them.
ALTER TABLE public.users_profile
  DROP COLUMN IF EXISTS face_verified,
  DROP COLUMN IF EXISTS id_type,
  DROP COLUMN IF EXISTS id_number,
  DROP COLUMN IF EXISTS guarantor_id,
  DROP COLUMN IF EXISTS id_verified_at;


-- ============================================================================
-- SECTION 3 — kyc_guarantors
-- ============================================================================
-- One row per indigent registrant who was sponsored by a guarantor.
CREATE TABLE IF NOT EXISTS public.kyc_guarantors (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  indigent_user_id     UUID NOT NULL REFERENCES public.users_profile(id) ON DELETE CASCADE,
  guarantor_user_id    UUID NOT NULL REFERENCES public.users_profile(id),
  guarantor_full_name  TEXT NOT NULL,
  guarantor_id_type    TEXT CHECK (guarantor_id_type IN (
                         'barangay_id', 'drivers_license', 'passport',
                         'national_id', 'umid', 'prc', 'sss', 'philhealth',
                         'postal_id', 'voters_id', 'other')),
  guarantor_id_number  TEXT,
  relationship         TEXT NOT NULL,
  status               TEXT NOT NULL DEFAULT 'pending'
                         CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by          UUID REFERENCES public.users_profile(id),
  reviewed_at          TIMESTAMPTZ,
  review_notes         TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- If the table already existed from the 20261010 draft, converge it on the
-- canonical column set (the draft had a nullable guarantor_user_id, a NOT NULL
-- guarantor_id_type, and two extra guarantor_AI columns).
ALTER TABLE public.kyc_guarantors
  ADD COLUMN IF NOT EXISTS guarantor_full_name TEXT,
  ADD COLUMN IF NOT EXISTS guarantor_id_number TEXT,
  ADD COLUMN IF NOT EXISTS relationship        TEXT,
  ADD COLUMN IF NOT EXISTS review_notes        TEXT;

-- 'postal' -> 'postal_id' before the canonical CHECK is re-applied.
UPDATE public.kyc_guarantors
   SET guarantor_id_type = 'postal_id'
 WHERE guarantor_id_type = 'postal';

-- Drop the draft's separate guarantor AI result/verdict columns: the
-- guarantor is an existing approved user, so there is no separate AI verdict.
ALTER TABLE public.kyc_guarantors
  DROP COLUMN IF EXISTS guarantor_kyc_ai_result,
  DROP COLUMN IF EXISTS guarantor_verified_at;

-- guarantor_id_type is nullable in the canonical schema (a sponsor's ID type
-- may simply not have been captured).
ALTER TABLE public.kyc_guarantors
  ALTER COLUMN guarantor_id_type DROP NOT NULL;

-- The draft allowed a guarantor who was not a registered user (NULL
-- guarantor_user_id). That contradicts the final design, and those rows cannot
-- satisfy the NOT NULL below, so they are removed — loudly.
DO $$
DECLARE
  orphan_rows BIGINT;
BEGIN
  SELECT COUNT(*) INTO orphan_rows
    FROM public.kyc_guarantors
   WHERE guarantor_user_id IS NULL;

  IF orphan_rows > 0 THEN
    RAISE WARNING 'kyc_guarantors: removing % row(s) whose guarantor is not a registered user (superseded draft)', orphan_rows;
    DELETE FROM public.kyc_guarantors WHERE guarantor_user_id IS NULL;
  END IF;
END $$;

ALTER TABLE public.kyc_guarantors
  ALTER COLUMN guarantor_user_id SET NOT NULL;

-- Repoint a draft ON DELETE SET NULL FK at the canonical plain reference.
DO $$
DECLARE
  fk RECORD;
BEGIN
  FOR fk IN
    SELECT conname, pg_get_constraintdef(oid) AS def
      FROM pg_constraint
     WHERE conrelid = 'public.kyc_guarantors'::regclass
       AND contype = 'f'
       AND pg_get_constraintdef(oid) ILIKE '%guarantor_user_id%'
  LOOP
    IF fk.def ILIKE '%SET NULL%' THEN
      EXECUTE format('ALTER TABLE public.kyc_guarantors DROP CONSTRAINT %I', fk.conname);
    END IF;
  END LOOP;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conrelid = 'public.kyc_guarantors'::regclass
       AND contype = 'f'
       AND pg_get_constraintdef(oid) ILIKE '%guarantor_user_id%'
  ) THEN
    ALTER TABLE public.kyc_guarantors
      ADD CONSTRAINT kyc_guarantors_guarantor_user_id_fkey
      FOREIGN KEY (guarantor_user_id)
      REFERENCES public.users_profile(id);
  END IF;
END $$;

UPDATE public.kyc_guarantors
   SET guarantor_full_name = ''
 WHERE guarantor_full_name IS NULL;

ALTER TABLE public.kyc_guarantors
  ALTER COLUMN guarantor_full_name SET NOT NULL,
  ALTER COLUMN status              SET DEFAULT 'pending';

-- `relationship` is NOT NULL in the canonical schema and has no sensible
-- default, so it is only tightened when the existing data already satisfies
-- it; otherwise the rows need a human to fix and we say so.
DO $$
DECLARE
  missing_relationship BIGINT;
BEGIN
  SELECT COUNT(*) INTO missing_relationship
    FROM public.kyc_guarantors
   WHERE relationship IS NULL;

  IF missing_relationship > 0 THEN
    RAISE WARNING 'kyc_guarantors: % row(s) have a NULL relationship; NOT NULL not applied — fill them in first', missing_relationship;
  ELSE
    ALTER TABLE public.kyc_guarantors
      ALTER COLUMN relationship SET NOT NULL;
  END IF;
END $$;

-- Canonical CHECKs (named so a re-run can replace them).
ALTER TABLE public.kyc_guarantors
  DROP CONSTRAINT IF EXISTS kyc_guarantors_guarantor_id_type_check,
  DROP CONSTRAINT IF EXISTS kyc_guarantors_status_check;

ALTER TABLE public.kyc_guarantors
  ADD CONSTRAINT kyc_guarantors_guarantor_id_type_check
    CHECK (guarantor_id_type IS NULL OR guarantor_id_type IN (
      'barangay_id', 'drivers_license', 'passport', 'national_id',
      'umid', 'prc', 'sss', 'philhealth', 'postal_id', 'voters_id',
      'other'
    ));

ALTER TABLE public.kyc_guarantors
  ADD CONSTRAINT kyc_guarantors_status_check
    CHECK (status IN ('pending', 'approved', 'rejected'));

-- Indexes on indigent_user_id and status.
CREATE INDEX IF NOT EXISTS idx_kyc_guarantors_indigent
  ON public.kyc_guarantors(indigent_user_id);

CREATE INDEX IF NOT EXISTS idx_kyc_guarantors_status
  ON public.kyc_guarantors(status);


-- ============================================================================
-- SECTION 4 — RLS
-- ============================================================================
-- Same posture as every other table in the app: RLS is enabled but the policy
-- is permissive, because this app authenticates in Dart and never calls
-- supabase.auth, so auth.uid() is always NULL and any policy based on it
-- would silently deny everything (see setup.sql DESIGN NOTE 3).
-- NEVER introduce an auth.uid() policy here.

ALTER TABLE public.kyc_guarantors ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM pg_policies
     WHERE schemaname = 'public'
       AND tablename = 'kyc_guarantors'
       AND policyname = 'app_access_kyc_guarantors'
  ) THEN
    CREATE POLICY "app_access_kyc_guarantors"
      ON public.kyc_guarantors
      FOR ALL
      USING (true)
      WITH CHECK (true);
  END IF;
END $$;


-- ============================================================================
-- SECTION 5 — updated_at trigger (mirrors SECTION 5 of setup.sql)
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM pg_trigger
     WHERE tgname = 'trg_kyc_guarantors_updated_at'
       AND tgrelid = 'public.kyc_guarantors'::regclass
  ) THEN
    CREATE TRIGGER trg_kyc_guarantors_updated_at
      BEFORE UPDATE ON public.kyc_guarantors
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;


-- ============================================================================
-- SECTION 6 — barangay_config sample-ID columns (DEPRECATED)
-- ============================================================================
-- No longer used: any valid government ID is accepted, so there is no sample
-- template to match against. Kept (not dropped) so an existing captain
-- upload is preserved and older app builds keep working.

ALTER TABLE public.barangay_config
  ADD COLUMN IF NOT EXISTS sample_barangay_id_front_url TEXT,
  ADD COLUMN IF NOT EXISTS sample_barangay_id_back_url  TEXT;