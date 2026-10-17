-- ============================================================================
--  guin_app — Consolidated Supabase Setup
-- ============================================================================
--  Replaces the 8 legacy scripts that were previously in this repo:
--    create_admin_user.sql              supabase_schema.sql
--    fix_documents_bucket.sql           supabase_migration.sql
--    setup_storage_buckets.sql          supabase_workflow_migration.sql
--    supabase_drop_and_recreate.sql     supabase_complete_system_migration.sql
--
--  HOW TO RUN
--    Fresh project:  paste the whole file into Supabase > SQL Editor > Run.
--                    It drops and rebuilds everything, so it is DESTRUCTIVE.
--    Existing data:  do NOT run this. Keep your data and run only the
--                    "Incremental repair" section at the bottom of this file.
--
--  DESIGN NOTES (read before changing anything)
--
--  1. request_status is TEXT, not an enum.
--     The three legacy scripts disagreed: drop_and_recreate had 4 values,
--     workflow_migration documented 13, schema.sql had 15 — and none matched
--     the 16 statuses in lib/models/document_request.dart. A DB enum also
--     cannot be extended while values are in use. TEXT + CHECK is used so the
--     app is the single source of truth for the workflow, which is exactly
--     what supabase_workflow_migration.sql asked for in its own comments:
--     "Status Reference (enforced in app, not DB enum)".
--
--  2. audit_logs is the union of BOTH shapes found in lib/, because the app
--     has two conflicting writers:
--       - lib/services/audit_service.dart  -> actor_user_id, entity_type,
--         entity_id, old_value, new_value, remarks
--       - lib/services/document_service.dart::_audit -> request_id, actor_id,
--         from_status, to_status, notes
--     Every column is nullable so both writers succeed. Consolidating the two
--     Dart writers into one is still open work.
--
--  3. Row Level Security is ENABLED but every policy is permissive.
--     This app authenticates in Dart (salted SHA-256 in users_profile.
--     password_hash, session in shared_preferences) and never calls
--     supabase.auth. Therefore auth.uid() is always NULL and any policy based
--     on it silently denies everything. The legacy auth.uid() policies in
--     supabase_migration.sql would break the app if enabled.
--     The current state is: RLS on, access effectively open to anyone holding
--     the anon key. This is NOT production-safe. The real fix is to move auth
--     to Supabase Auth; until then do not expose this project publicly.
--     See DOCUMENTATION.md "Known gaps".
--
--  4. No RPC functions are defined because the app never calls .rpc().
--     The legacy notify_* trigger functions are intentionally NOT included:
--     they assumed a 4-value request_status enum and would fail to compile
--     against the column this file creates.
--
--  5. KYC accepts ANY valid government ID.
--     kyc_id_type / kyc_guarantors.guarantor_id_type share ONE whitelist
--     (see DESIGN NOTE 6). There is no face-match column and no separate
--     guarantor AI result: an indigent registrant with no ID is sponsored by a
--     guarantor who is an existing APPROVED user, recorded on
--     public.kyc_guarantors, and the sponsorship never auto-approves.
--     barcode/template matching against a captain-uploaded sample is gone, so
--     barangay_config.sample_barangay_id_front_url / _back_url are DEPRECATED
--     and unused — kept only so an existing upload is not lost.
--     On an EXISTING database, apply
--     supabase/migrations/20261016_kyc_general_ids_guarantor.sql instead of
--     re-running this file.
--
--  6. The canonical government-ID whitelist, used by users_profile.kyc_id_type
--     and kyc_guarantors.guarantor_id_type (TEXT + CHECK, not an enum, for the
--     same reason as DESIGN NOTE 1). Keep in sync with ID_TYPES in
--     supabase/functions/ai/_kyc.ts:
--     barangay_id, drivers_license, passport, national_id, umid, prc, sss,
--     philhealth, postal_id, voters_id, other
-- ============================================================================


-- ============================================================================
--  SECTION 0 — CLEAN SLATE
--  Order matters: tables -> functions -> types, so the drops cascade safely.
-- ============================================================================

DROP TABLE IF EXISTS public.identity_access_logs   CASCADE;
DROP TABLE IF EXISTS public.incident_attachments    CASCADE;
DROP TABLE IF EXISTS public.incident_updates        CASCADE;
DROP TABLE IF EXISTS public.incident_reports        CASCADE;
DROP TABLE IF EXISTS public.audit_logs              CASCADE;
DROP TABLE IF EXISTS public.document_print_copies   CASCADE;
DROP TABLE IF EXISTS public.document_verifications  CASCADE;
DROP TABLE IF EXISTS public.document_versions       CASCADE;
DROP TABLE IF EXISTS public.payments                CASCADE;
DROP TABLE IF EXISTS public.role_permissions        CASCADE;
DROP TABLE IF EXISTS public.cedula_details          CASCADE;
DROP TABLE IF EXISTS public.indigency_details       CASCADE;
DROP TABLE IF EXISTS public.barangay_id_details     CASCADE;
DROP TABLE IF EXISTS public.notifications           CASCADE;
DROP TABLE IF EXISTS public.document_requests       CASCADE;
DROP TABLE IF EXISTS public.document_fees           CASCADE;
DROP TABLE IF EXISTS public.kyc_guarantors          CASCADE;
DROP TABLE IF EXISTS public.barangay_config         CASCADE;
DROP TABLE IF EXISTS public.users_profile           CASCADE;

DROP TYPE IF EXISTS public.request_status         CASCADE;
DROP TYPE IF EXISTS public.registration_status   CASCADE;
DROP TYPE IF EXISTS public.notification_type      CASCADE;
DROP TYPE IF EXISTS public.document_type          CASCADE;
DROP TYPE IF EXISTS public.user_role              CASCADE;


-- ============================================================================
--  SECTION 1 — ENUM TYPES
--  Only types the app genuinely relies on. Roles match lib/utils/role_access.dart.
-- ============================================================================

-- Roles: admin, captain, secretary, treasurer, kagawad_representative,
--        barangay_tanod, citizen
CREATE TYPE public.user_role AS ENUM (
  'admin',
  'captain',
  'secretary',
  'treasurer',
  'kagawad_representative',
  'barangay_tanod',
  'citizen'
);

CREATE TYPE public.document_type AS ENUM (
  'barangay_clearance',
  'indigency',
  'barangay_id',
  'cedula',
  'business_clearance',
  'certification',
  'oath_undertaking',
  'good_moral',
  'residency'
);

CREATE TYPE public.registration_status AS ENUM ('pending', 'approved', 'rejected');

CREATE TYPE public.notification_type AS ENUM (
  'registration_approved',
  'registration_rejected',
  'request_approved',
  'request_rejected',
  'request_released',
  'payment_verified',
  'payment_rejected',
  'incident_submitted',
  'incident_updated',
  'system'
);


-- ============================================================================
--  SECTION 2 — SHARED FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ============================================================================
--  SECTION 3 — TABLES
--  Column set = the union of every column referenced in lib/, verified against
--  the Dart models and services.
-- ============================================================================

-- 3a. Users -------------------------------------------------------------
-- Custom auth lives here: password_hash is a salted SHA-256 produced by
-- lib/utils/password_hash.dart, NOT a Supabase Auth bcrypt hash.
CREATE TABLE public.users_profile (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username            TEXT NOT NULL UNIQUE,
  password_hash       TEXT NOT NULL,
  full_name           TEXT NOT NULL,
  email               TEXT NOT NULL UNIQUE,
  phone_number        TEXT,
  address             TEXT,
  age                 INTEGER,
  date_of_birth       DATE,
  place_of_birth      TEXT,
  civil_status        TEXT,
  gender              TEXT,
  role                user_role NOT NULL DEFAULT 'citizen',
  registration_status registration_status NOT NULL DEFAULT 'pending',
  is_approved         BOOLEAN NOT NULL DEFAULT FALSE,
  rejection_reason    TEXT,
  profile_photo_url   TEXT,
  valid_id_url        TEXT,

  -- KYC (see DESIGN NOTES 5 and 6). Registration accepts ANY valid government
  -- ID; kyc_id_type is which one this user actually presented. Everything is
  -- nullable/defaulted because a user may be created before any KYC path runs.
  kyc_id_type         TEXT
                        CHECK (kyc_id_type IS NULL OR kyc_id_type IN (
                          'barangay_id','drivers_license','passport','national_id',
                          'umid','prc','sss','philhealth','postal_id','voters_id',
                          'other')),
  kyc_id_number       TEXT,
  id_issued_at        DATE,
  id_expiry_at        DATE,
  liveness_verified   BOOLEAN DEFAULT FALSE,
  liveness_verified_at TIMESTAMPTZ,
  kyc_method          TEXT
                        CHECK (kyc_method IS NULL OR kyc_method IN (
                          'ai_verified','manual_verified','indigent_bypass',
                          'guarantor_verified')),
  kyc_ai_result       JSONB,
  is_indigent         BOOLEAN DEFAULT FALSE,
  indigency_reason    TEXT,
  kyc_verified_at     TIMESTAMPTZ,
  kyc_reviewed_by     UUID REFERENCES public.users_profile(id),
  kyc_rejection_reason TEXT,
  -- DEPRECATED: superseded by kyc_id_type/kyc_id_number. Retained so existing
  -- rows and the legacy user_profile model keep working; nothing writes it.
  barangay_id_number  TEXT,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3b. Barangay config (public read reference data) ----------------------
CREATE TABLE public.barangay_config (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gcash_name       TEXT NOT NULL,
  gcash_number     TEXT NOT NULL,
  barangay_name    TEXT NOT NULL,
  barangay_address TEXT NOT NULL,
  barangay_captain TEXT,
  contact_number   TEXT,
  email            TEXT,
  logo_url         TEXT,
  -- DEPRECATED / UNUSED (DESIGN NOTE 5): these held a sample Barangay ID
  -- template to match uploads against. Any valid government ID is now
  -- accepted, so nothing reads them; kept so an existing captain upload is
  -- not lost.
  sample_barangay_id_front_url TEXT,
  sample_barangay_id_back_url  TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3c. Document fees -----------------------------------------------------
CREATE TABLE public.document_fees (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_type document_type NOT NULL UNIQUE,
  fee_amount    DECIMAL(10,2) NOT NULL CHECK (fee_amount >= 0),
  description   TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3d. Document requests -------------------------------------------------
-- request_status is TEXT on purpose; see DESIGN NOTE 1.
-- The CHECK is a guard rail, not the source of truth. Keep in sync with
-- class DocStatus in lib/models/document_request.dart.
CREATE TABLE public.document_requests (
  id                         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                    UUID NOT NULL REFERENCES public.users_profile(id) ON DELETE CASCADE,
  document_type              document_type NOT NULL,
  purpose                    TEXT NOT NULL,
  document_data              JSONB NOT NULL DEFAULT '{}'::JSONB,
  request_status             TEXT NOT NULL DEFAULT 'submitted'
                             CHECK (request_status IN (
                               'submitted',
                               'draft_generated',
                               'needs_revision',
                               'verified_for_payment',
                               'invoiced',
                               'payment_submitted',
                               'payment_rejected',
                               'payment_confirmed',
                               'for_approval',
                               'approved',
                               'released',
                               'rejected',
                               'cancelled',
                               'pending_review',
                               'pending_payment',
                               'approved_for_release'
                             )),

  -- payment
  payment_amount           DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  payment_required         BOOLEAN NOT NULL DEFAULT TRUE,
  payment_status           TEXT NOT NULL DEFAULT 'pending'
                           CHECK (payment_status IN ('pending','submitted','verified','rejected','cancelled')),
  payment_method           TEXT CHECK (payment_method IN ('gcash','cash_on_site','cash_onsite','manual_cashier')),
  payment_reference_number TEXT,
  payment_receipt_url      TEXT,
  payment_parsed_at        TIMESTAMPTZ,
  payment_parsed_confidence DECIMAL(3,2) CHECK (payment_parsed_confidence >= 0 AND payment_parsed_confidence <= 1),
  payment_parse_error      TEXT,
  receipt_parse            JSONB,
  payment_verified_at      TIMESTAMPTZ,
  payment_verified_by      UUID REFERENCES public.users_profile(id),
  payment_rejection_reason TEXT,

  -- secretary / invoice stage
  secretary_notes         TEXT,
  draft_url               TEXT,
  reviewed_by_secretary   UUID REFERENCES public.users_profile(id),
  secretary_verified_at   TIMESTAMPTZ,
  invoice_description     TEXT,
  invoice_due_date        TIMESTAMPTZ,
  invoice_created_at      TIMESTAMPTZ,

  -- approval / release stage
  approver_id         TEXT,
  approver_role       TEXT,
  captain_approved_at TIMESTAMPTZ,
  captain_unavailable BOOLEAN NOT NULL DEFAULT FALSE,
  approved_by         UUID REFERENCES public.users_profile(id),
  approved_at         TIMESTAMPTZ,
  released_by         UUID REFERENCES public.users_profile(id),
  released_at         TIMESTAMPTZ,
  release_method      TEXT,
  printed_by          UUID REFERENCES public.users_profile(id),
  printed_at          TIMESTAMPTZ,

  -- released document identity
  request_number     TEXT UNIQUE,
  document_id        TEXT UNIQUE,
  verification_token TEXT,
  qr_url             TEXT,
  document_hash      TEXT,
  expires_at         TIMESTAMPTZ,
  single_use         BOOLEAN NOT NULL DEFAULT FALSE,
  max_uses           INTEGER,
  use_count          INTEGER NOT NULL DEFAULT 0,
  used_at            TIMESTAMPTZ,
  document_url       TEXT,
  generated_document_url TEXT,
  final_document_url      TEXT,

  -- generic review
  reviewed_at      TIMESTAMPTZ,
  reviewed_by      UUID REFERENCES public.users_profile(id),
  rejection_reason TEXT,

  -- lifecycle
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  archived_at  TIMESTAMPTZ,
  created_by   UUID REFERENCES public.users_profile(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3e. Per-document-type detail tables -----------------------------------
CREATE TABLE public.barangay_id_details (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id               UUID NOT NULL REFERENCES public.document_requests(id) ON DELETE CASCADE,
  emergency_contact_name   TEXT NOT NULL,
  emergency_contact_number TEXT NOT NULL,
  blood_type               TEXT,
  occupation               TEXT,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.indigency_details (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id         UUID NOT NULL REFERENCES public.document_requests(id) ON DELETE CASCADE,
  monthly_income     DECIMAL(10,2),
  number_of_dependents INTEGER,
  employment_status  TEXT,
  specific_purpose   TEXT NOT NULL,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.cedula_details (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id         UUID NOT NULL REFERENCES public.document_requests(id) ON DELETE CASCADE,
  citizenship        TEXT NOT NULL,
  profession_occupation TEXT NOT NULL,
  height_cm          DECIMAL(5,2),
  weight_kg          DECIMAL(5,2),
  tin_number         TEXT,
  community_tax_due  DECIMAL(10,2),
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3f. Notifications -----------------------------------------------------
CREATE TABLE public.notifications (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES public.users_profile(id) ON DELETE CASCADE,
  title      TEXT NOT NULL,
  message    TEXT NOT NULL,
  type       notification_type NOT NULL DEFAULT 'system',
  is_read    BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3g. Payments ledger ---------------------------------------------------
CREATE TABLE public.payments (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id       UUID NOT NULL REFERENCES public.document_requests(id) ON DELETE CASCADE,
  user_id          UUID NOT NULL REFERENCES public.users_profile(id) ON DELETE CASCADE,
  payment_method   TEXT NOT NULL,
  amount           DECIMAL(10,2) NOT NULL CHECK (amount >= 0),
  reference_number TEXT,
  receipt_url      TEXT,
  status           TEXT NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending','submitted','verified','rejected','cancelled')),
  encoded_by       UUID REFERENCES public.users_profile(id),
  verified_by      UUID REFERENCES public.users_profile(id),
  verified_at      TIMESTAMPTZ,
  rejection_reason TEXT,
  remarks          TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3h. Document versions -------------------------------------------------
CREATE TABLE public.document_versions (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id     UUID NOT NULL REFERENCES public.document_requests(id) ON DELETE CASCADE,
  version_number INTEGER NOT NULL,
  file_url       TEXT NOT NULL,
  file_hash      TEXT,
  status         TEXT NOT NULL DEFAULT 'generated',
  generated_by   UUID REFERENCES public.users_profile(id),
  generated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  remarks        TEXT,
  UNIQUE (request_id, version_number)
);

-- 3i. Public document verification --------------------------------------
CREATE TABLE public.document_verifications (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id         UUID NOT NULL REFERENCES public.document_requests(id) ON DELETE CASCADE,
  document_id        TEXT NOT NULL UNIQUE,
  verification_token TEXT NOT NULL,
  document_type      TEXT NOT NULL,
  citizen_name       TEXT NOT NULL,
  status             TEXT NOT NULL DEFAULT 'valid'
                     CHECK (status IN ('valid','revoked','expired','used')),
  issued_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  released_by        UUID REFERENCES public.users_profile(id),
  revoked_by         UUID REFERENCES public.users_profile(id),
  revoked_at         TIMESTAMPTZ,
  revocation_reason  TEXT,
  document_hash      TEXT,
  expires_at         TIMESTAMPTZ,
  single_use         BOOLEAN NOT NULL DEFAULT FALSE,
  max_uses           INTEGER,
  use_count          INTEGER NOT NULL DEFAULT 0,
  used_at            TIMESTAMPTZ,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3i-bis. Per-print copies of a released document ------------------------
--  Each saved/printed copy gets its own token (traceability + duplicate
--  detection), but expiry/single-use/use-limit policy is enforced against
--  the PARENT row in public.document_verifications so printing N copies can
--  never multiply the use budget.
CREATE TABLE public.document_print_copies (
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

-- 3j. Incident reports --------------------------------------------------
CREATE TABLE public.incident_reports (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_number      TEXT UNIQUE,
  submitted_by       UUID REFERENCES public.users_profile(id),
  report_type        TEXT NOT NULL,
  title              TEXT NOT NULL,
  description        TEXT NOT NULL,
  location           TEXT NOT NULL,
  -- Map pin dropped by the reporter on submit. NULL = no pin captured
  -- (legacy rows, or the reporter skipped the map).
  latitude           DOUBLE PRECISION,
  longitude          DOUBLE PRECISION,
  incident_datetime  TIMESTAMPTZ NOT NULL,
  is_sensitive       BOOLEAN DEFAULT FALSE,
  is_anonymous       BOOLEAN DEFAULT FALSE,
  identity_visibility TEXT DEFAULT 'visible'
                     CHECK (identity_visibility IN ('visible','restricted','hidden_until_authorized')),
  priority           TEXT DEFAULT 'normal'
                     CHECK (priority IN ('low','normal','high','urgent')),
  status             TEXT DEFAULT 'submitted'
                     CHECK (status IN ('submitted','received','under_assessment','endorsed','in_progress','resolved','closed','rejected')),
  received_by        UUID REFERENCES public.users_profile(id),
  received_at        TIMESTAMPTZ,
  assigned_to        UUID REFERENCES public.users_profile(id),
  escalated_to       UUID REFERENCES public.users_profile(id),
  resolved_by        UUID REFERENCES public.users_profile(id),
  resolved_at        TIMESTAMPTZ,
  resolution_summary TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.incident_updates (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_report_id UUID NOT NULL REFERENCES public.incident_reports(id) ON DELETE CASCADE,
  updated_by         UUID REFERENCES public.users_profile(id),
  old_status         TEXT,
  new_status         TEXT,
  remarks            TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.incident_attachments (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_report_id UUID NOT NULL REFERENCES public.incident_reports(id) ON DELETE CASCADE,
  file_url           TEXT NOT NULL,
  file_type          TEXT,
  uploaded_by        UUID REFERENCES public.users_profile(id),
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.identity_access_logs (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_report_id UUID NOT NULL REFERENCES public.incident_reports(id) ON DELETE CASCADE,
  accessed_by        UUID NOT NULL REFERENCES public.users_profile(id),
  reason             TEXT NOT NULL,
  accessed_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3k. Role permissions --------------------------------------------------
CREATE TABLE public.role_permissions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  role_key      TEXT NOT NULL,
  permission_key TEXT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (role_key, permission_key)
);

-- 3l. Audit log ---------------------------------------------------------
-- Superset of both writers found in lib/. See DESIGN NOTE 2.
CREATE TABLE public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- shape used by lib/services/audit_service.dart
  actor_user_id UUID REFERENCES public.users_profile(id),
  entity_type   TEXT,
  entity_id     UUID,
  old_value     JSONB,
  new_value     JSONB,
  remarks       TEXT,

  -- legacy shape used by document_service.dart::_audit
  request_id UUID REFERENCES public.document_requests(id) ON DELETE CASCADE,
  actor_id   TEXT,
  from_status TEXT,
  to_status  TEXT,
  notes      TEXT,

  -- shared
  actor_role TEXT NOT NULL,
  action     TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3m. KYC guarantors -----------------------------------------------------
-- One row per indigent registrant who was sponsored. The guarantor is always
-- an EXISTING APPROVED user, so their identity is already verified by their own
-- users_profile row; this table only records who vouched for whom and the
-- captain's decision. There is no separate guarantor AI result and no
-- guarantor_verified_at: a sponsorship NEVER auto-approves, it always lands in
-- the captain's pending queue.
-- See supabase/migrations/20261016_kyc_general_ids_guarantor.sql for the
-- additive version of this table for existing databases.
CREATE TABLE public.kyc_guarantors (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  indigent_user_id     UUID NOT NULL REFERENCES public.users_profile(id) ON DELETE CASCADE,
  guarantor_user_id    UUID NOT NULL REFERENCES public.users_profile(id),
  guarantor_full_name  TEXT NOT NULL,
  guarantor_id_type    TEXT
                         CHECK (guarantor_id_type IS NULL OR guarantor_id_type IN (
                           'barangay_id','drivers_license','passport','national_id',
                           'umid','prc','sss','philhealth','postal_id','voters_id',
                           'other')),
  guarantor_id_number  TEXT,
  relationship         TEXT NOT NULL,
  status               TEXT NOT NULL DEFAULT 'pending'
                         CHECK (status IN ('pending','approved','rejected')),
  reviewed_by          UUID REFERENCES public.users_profile(id),
  reviewed_at          TIMESTAMPTZ,
  review_notes         TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3n. Announcements ------------------------------------------------------
-- Barangay-wide notices posted by officials (captain / secretary / admin).
-- Every signed-in user can read them; there is no per-user targeting or read
-- state. `created_by_name` is denormalized so the feed renders without a join.
-- See supabase/migrations/20261020_announcements.sql for the additive version
-- of this table for existing databases.
CREATE TABLE public.announcements (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title           TEXT NOT NULL,
  body            TEXT NOT NULL,
  created_by      UUID REFERENCES public.users_profile(id) ON DELETE SET NULL,
  created_by_name TEXT NOT NULL,
  is_pinned       BOOLEAN NOT NULL DEFAULT FALSE,
  image_url       TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3m. Emergency hotlines --------------------------------------------------
-- Emergency contact numbers displayed to every signed-in user. Only
-- captain / secretary / admin may add/edit/remove entries (client-side
-- gate via AppRoles.canManageHotlines).
-- See supabase/migrations/20261017_emergency_hotlines.sql for the additive
-- version of this table for existing databases.
CREATE TABLE public.emergency_hotlines (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL,
  number          TEXT NOT NULL,
  description     TEXT,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_by      UUID REFERENCES public.users_profile(id) ON DELETE SET NULL,
  created_by_name TEXT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================================
--  SECTION 4 — INDEXES
-- ============================================================================

CREATE INDEX idx_users_profile_role            ON public.users_profile(role);
CREATE INDEX idx_users_profile_registration    ON public.users_profile(registration_status);
CREATE INDEX idx_document_requests_user       ON public.document_requests(user_id);
CREATE INDEX idx_document_requests_status     ON public.document_requests(request_status);
CREATE INDEX idx_document_requests_type       ON public.document_requests(document_type);
CREATE INDEX idx_barangay_id_details_request   ON public.barangay_id_details(request_id);
CREATE INDEX idx_indigency_details_request     ON public.indigency_details(request_id);
CREATE INDEX idx_cedula_details_request       ON public.cedula_details(request_id);
CREATE INDEX idx_notifications_user           ON public.notifications(user_id);
CREATE INDEX idx_payments_request             ON public.payments(request_id);
CREATE INDEX idx_payments_status              ON public.payments(status);
CREATE INDEX idx_document_versions_request    ON public.document_versions(request_id);
CREATE INDEX idx_document_verifications_docid ON public.document_verifications(document_id);
CREATE INDEX idx_document_verifications_token  ON public.document_verifications(verification_token);
CREATE INDEX idx_document_print_copies_docid   ON public.document_print_copies(document_id);
CREATE INDEX idx_incident_reports_status      ON public.incident_reports(status);
CREATE INDEX idx_incident_reports_submitted   ON public.incident_reports(submitted_by);
CREATE INDEX idx_incident_updates_report      ON public.incident_updates(incident_report_id);
CREATE INDEX idx_audit_logs_entity            ON public.audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_request           ON public.audit_logs(request_id);
CREATE INDEX idx_kyc_guarantors_indigent      ON public.kyc_guarantors(indigent_user_id);
CREATE INDEX idx_kyc_guarantors_status        ON public.kyc_guarantors(status);
CREATE INDEX idx_announcements_created        ON public.announcements(created_at DESC);
CREATE INDEX idx_announcements_pinned         ON public.announcements(is_pinned);
CREATE INDEX idx_emergency_hotlines_active    ON public.emergency_hotlines(is_active);
CREATE INDEX idx_emergency_hotlines_name      ON public.emergency_hotlines(name);


-- ============================================================================
--  SECTION 5 — updated_at TRIGGERS
-- ============================================================================

CREATE TRIGGER trg_users_profile_updated_at
  BEFORE UPDATE ON public.users_profile
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_barangay_config_updated_at
  BEFORE UPDATE ON public.barangay_config
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_document_fees_updated_at
  BEFORE UPDATE ON public.document_fees
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_document_requests_updated_at
  BEFORE UPDATE ON public.document_requests
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_barangay_id_details_updated_at
  BEFORE UPDATE ON public.barangay_id_details
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_indigency_details_updated_at
  BEFORE UPDATE ON public.indigency_details
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_cedula_details_updated_at
  BEFORE UPDATE ON public.cedula_details
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_payments_updated_at
  BEFORE UPDATE ON public.payments
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_incident_reports_updated_at
  BEFORE UPDATE ON public.incident_reports
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_kyc_guarantors_updated_at
  BEFORE UPDATE ON public.kyc_guarantors
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_announcements_updated_at
  BEFORE UPDATE ON public.announcements
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_emergency_hotlines_updated_at
  BEFORE UPDATE ON public.emergency_hotlines
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ============================================================================
--  SECTION 6 — ROW LEVEL SECURITY
--  Enabled, but permissive on purpose. See DESIGN NOTE 3 — this app does not
--  use Supabase Auth, so auth.uid() is always NULL and real policies would
--  lock the app out. Replace these with real policies ONLY after migrating
--  authentication to Supabase Auth.
-- ============================================================================

ALTER TABLE public.users_profile          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.barangay_config        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_fees          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_requests      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.barangay_id_details    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.indigency_details      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cedula_details         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_versions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_print_copies  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incident_reports       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incident_updates       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incident_attachments   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.identity_access_logs   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kyc_guarantors         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_hotlines      ENABLE ROW LEVEL SECURITY;

CREATE POLICY "app_access_users_profile"          ON public.users_profile          FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "app_access_barangay_config"        ON public.barangay_config        FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "app_access_document_fees"          ON public.document_fees          FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "app_access_document_requests"      ON public.document_requests      FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "app_access_barangay_id_details"    ON public.barangay_id_details    FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "app_access_indigency_details"      ON public.indigency_details      FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "app_access_cedula_details"         ON public.cedula_details         FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "app_access_notifications"          ON public.notifications          FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "app_access_payments"               ON public.payments               FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "app_access_document_versions"      ON public.document_versions      FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "app_access_document_verifications" ON public.document_verifications FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "app_access_document_print_copies"  ON public.document_print_copies  FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "app_access_incident_reports"       ON public.incident_reports       FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "app_access_incident_updates"       ON public.incident_updates       FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "app_access_incident_attachments"   ON public.incident_attachments   FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "app_access_identity_access_logs"   ON public.identity_access_logs   FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "app_access_role_permissions"       ON public.role_permissions       FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "app_access_audit_logs"             ON public.audit_logs             FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "app_access_kyc_guarantors"         ON public.kyc_guarantors         FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "app_access_announcements"          ON public.announcements          FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "app_access_emergency_hotlines"      ON public.emergency_hotlines      FOR ALL USING (true) WITH CHECK (true);


-- ============================================================================
--  SECTION 7 — STORAGE BUCKETS
--  Superset of setup_storage_buckets.sql + fix_documents_bucket.sql.
--  All buckets are public; the app stores signed-in citizen documents here,
--  so "public" means publicly readable URLs. See DOCUMENTATION.md for the
--  privacy implications.
-- ============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('profile-photos',      'profile-photos',      true, 5242880,  ARRAY['image/jpeg','image/jpg','image/png','image/webp']),
  ('valid-ids',           'valid-ids',           true, 5242880,  ARRAY['image/jpeg','image/jpg','image/png','image/webp']),
  ('payment-receipts',    'payment-receipts',    true, 5242880,  ARRAY['image/jpeg','image/jpg','image/png','image/webp']),
  ('announcement-images', 'announcement-images', true, 5242880,  ARRAY['image/jpeg','image/jpg','image/png','image/webp','image/gif']),
  ('documents',           'documents',           true, 10485760, ARRAY['application/pdf'])
ON CONFLICT (id) DO UPDATE
  SET public             = EXCLUDED.public,
      file_size_limit    = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Bucket access. storage.objects is owned by Supabase, so the policies are
-- created idempotently (no IF NOT EXISTS support on CREATE POLICY).
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies
                 WHERE tablename = 'objects' AND policyname = 'app_access_profile_photos') THEN
    CREATE POLICY "app_access_profile_photos" ON storage.objects FOR ALL
      USING (bucket_id = 'profile-photos') WITH CHECK (bucket_id = 'profile-photos');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies
                 WHERE tablename = 'objects' AND policyname = 'app_access_valid_ids') THEN
    CREATE POLICY "app_access_valid_ids" ON storage.objects FOR ALL
      USING (bucket_id = 'valid-ids') WITH CHECK (bucket_id = 'valid-ids');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies
                 WHERE tablename = 'objects' AND policyname = 'app_access_payment_receipts') THEN
    CREATE POLICY "app_access_payment_receipts" ON storage.objects FOR ALL
      USING (bucket_id = 'payment-receipts') WITH CHECK (bucket_id = 'payment-receipts');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies
                 WHERE tablename = 'objects' AND policyname = 'app_access_documents') THEN
    CREATE POLICY "app_access_documents" ON storage.objects FOR ALL
      USING (bucket_id = 'documents') WITH CHECK (bucket_id = 'documents');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies
                 WHERE tablename = 'objects' AND policyname = 'app_access_announcement_images') THEN
    CREATE POLICY "app_access_announcement_images" ON storage.objects FOR ALL
      USING (bucket_id = 'announcement-images') WITH CHECK (bucket_id = 'announcement-images');
  END IF;
END $$;


-- ============================================================================
--  SECTION 8 — REALTIME
--  The app holds live subscriptions on exactly four tables — document_requests,
--  users_profile, notifications and announcements (document/user/notification/
--  announcement providers). If a table is absent from the publication the
--  channel still connects but delivers nothing, so dashboards go stale with no
--  visible error.
--  ALTER PUBLICATION has no IF NOT EXISTS form, hence the membership check.
-- ============================================================================

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['document_requests','users_profile','notifications','announcements','emergency_hotlines'] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;


-- ============================================================================
--  SECTION 9 — SEED DATA
--  Password hashes are salted SHA-256, matching lib/utils/password_hash.dart.
--  Compute your own with that file before using these in production.
-- ============================================================================

-- 9a. Default document fees
INSERT INTO public.document_fees (document_type, fee_amount, description) VALUES
  ('barangay_clearance', 75.00,  'Barangay Clearance Fee'),
  ('business_clearance',  0.00,  'Barangay Business Clearance Fee (Admin Sets)'),
  ('certification',       0.00,  'Barangay Certification Fee (Admin Sets)'),
  ('oath_undertaking',    0.00,  'Oath of Undertaking (Free)'),
  ('indigency',           0.00,  'Certificate of Indigency (Free)'),
  ('good_moral',         75.00,  'Certificate of Good Moral Character Fee'),
  ('residency',           0.00,  'Certificate of Residency Fee (Admin Sets)'),
  ('cedula',             75.00,  'Community Tax Certificate Fee'),
  ('barangay_id',       100.00,  'Barangay ID Fee')
ON CONFLICT (document_type) DO UPDATE
  SET fee_amount  = EXCLUDED.fee_amount,
      description = EXCLUDED.description;

-- 9b. Barangay configuration. EDIT THESE VALUES for your barangay.
INSERT INTO public.barangay_config
  (barangay_name, barangay_address, gcash_name, gcash_number, barangay_captain, contact_number, email)
VALUES
  ('Barangay Name Here',
   'Barangay Address Here',
   'GCash Account Name Here',
   '09123456789',
   'Captain Name Here',
   '09123456789',
   'barangay@email.com');

-- 9c. Role permissions, carried over from supabase_complete_system_migration.sql
INSERT INTO public.role_permissions (role_key, permission_key) VALUES
  ('admin',                  'system.full_access'),
  ('captain',                'documents.release'),
  ('captain',                'payments.verify'),
  ('captain',                'reports.resolve'),
  ('secretary',              'documents.view'),
  ('secretary',              'documents.generate'),
  ('secretary',              'documents.review'),
  ('secretary',              'documents.release'),
  ('treasurer',              'payments.view'),
  ('treasurer',              'payments.verify'),
  ('treasurer',              'payments.reject'),
  ('kagawad_representative', 'documents.delegated_review'),
  ('kagawad_representative', 'reports.escalate'),
  ('barangay_tanod',         'reports.receive'),
  ('barangay_tanod',         'reports.update'),
  ('barangay_tanod',         'reports.escalate'),
  ('citizen',                'documents.request'),
  ('citizen',                'reports.submit')
ON CONFLICT (role_key, permission_key) DO NOTHING;

-- 9d. Bootstrap admin account.
--     Default login: admin / Admin@123456  -- CHANGE OR DELETE BEFORE DEPLOYING.
--     password_hash format is "<16-char salt>:<sha256(salt + password)>",
--     which is what lib/utils/password_hash.dart reads in verifyPassword().
--     This exact value was verified to match the password above.
--     Rotate it by generating a new hash with PasswordHash.hashPassword().
INSERT INTO public.users_profile
  (username, password_hash, full_name, email, address, age, date_of_birth,
   place_of_birth, civil_status, gender, phone_number, role,
   registration_status, is_approved)
VALUES
  ('admin',
   '67fb0d79f41794c9:e456c4f916973fa2dc96ad9f3d6e08a29985ad2e9782be69293bb8fe459ab14a',
   'System Administrator', 'admin@barangay.local', 'Barangay Hall', 30,
   DATE '1995-01-01', 'Metro Manila', 'Single', 'Male', '09123456789',
   'admin', 'approved', TRUE)
ON CONFLICT (username) DO NOTHING;


-- ============================================================================
--  SECTION 10 — VERIFICATION
--  Run this after setup. Every table the app queries should be listed.
-- ============================================================================

SELECT id, name, public, file_size_limit, allowed_mime_types
FROM storage.buckets
WHERE id IN ('profile-photos','valid-ids','payment-receipts','announcement-images','documents')
ORDER BY id;

SELECT username, role, registration_status, is_approved
FROM public.users_profile
ORDER BY created_at;

-- Expected: 20 tables
SELECT COUNT(*) AS table_count
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE';

-- Expected: 5 buckets
SELECT COUNT(*) AS bucket_count
FROM storage.buckets
WHERE id IN ('profile-photos','valid-ids','payment-receipts','announcement-images','documents');


-- ============================================================================
--  INCREMENTAL REPAIR
--  For an EXISTING database that already has data. This section only fixes
--  what the legacy scripts got wrong; it does not drop anything.
--  Run it on its own, not together with Sections 0-9.
--
--  -- Widen request_status from the 4-value legacy enum to TEXT.
--  DO $$
--  BEGIN
--    IF EXISTS (
--      SELECT 1 FROM information_schema.columns
--      WHERE table_name = 'document_requests' AND column_name = 'request_status'
--        AND data_type = 'user-defined'
--    ) THEN
--      ALTER TABLE public.document_requests
--        ALTER COLUMN request_status TYPE TEXT
--        USING request_status::TEXT;
--      DROP TYPE IF EXISTS public.request_status CASCADE;
--    END IF;
--  END $$;
--
--  -- Add workflow columns introduced by supabase_workflow_migration.sql.
--  ALTER TABLE public.document_requests
--    ADD COLUMN IF NOT EXISTS secretary_notes       TEXT,
--    ADD COLUMN IF NOT EXISTS draft_url             TEXT,
--    ADD COLUMN IF NOT EXISTS reviewed_by_secretary UUID REFERENCES public.users_profile(id),
--    ADD COLUMN IF NOT EXISTS secretary_verified_at TIMESTAMPTZ,
--    ADD COLUMN IF NOT EXISTS invoice_description   TEXT,
--    ADD COLUMN IF NOT EXISTS invoice_due_date      TIMESTAMPTZ,
--    ADD COLUMN IF NOT EXISTS invoice_created_at    TIMESTAMPTZ,
--    ADD COLUMN IF NOT EXISTS captain_unavailable   BOOLEAN DEFAULT FALSE,
--    ADD COLUMN IF NOT EXISTS approver_id           TEXT,
--    ADD COLUMN IF NOT EXISTS approver_role         TEXT,
--    ADD COLUMN IF NOT EXISTS captain_approved_at   TIMESTAMPTZ;
--
--  -- Add audit columns from supabase_complete_system_migration.sql.
--  ALTER TABLE public.audit_logs
--    ADD COLUMN IF NOT EXISTS actor_user_id UUID REFERENCES public.users_profile(id),
--    ADD COLUMN IF NOT EXISTS entity_type   TEXT,
--    ADD COLUMN IF NOT EXISTS entity_id     UUID,
--    ADD COLUMN IF NOT EXISTS old_value     JSONB,
--    ADD COLUMN IF NOT EXISTS new_value     JSONB,
--    ADD COLUMN IF NOT EXISTS remarks       TEXT;
--
--  -- KYC (general government IDs + guarantor sponsorship). Do NOT copy the
--  -- definitions out of Section 3 above: run the additive, re-runnable
--  -- migration instead, which also repairs a half-applied state.
--  --   supabase/migrations/20261016_kyc_general_ids_guarantor.sql
-- ============================================================================
