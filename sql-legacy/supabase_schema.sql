-- ============================================================
-- GUION BARANGAY MANAGEMENT SYSTEM — COMPLETE SUPABASE SCHEMA
-- ============================================================
-- Run this ONCE on a fresh Supabase project via the SQL Editor.
-- It creates every table, enum, index, trigger, storage bucket,
-- and RLS policy the Flutter app needs.
--
-- The app uses CUSTOM AUTH (email + password_hash in users_profile),
-- NOT Supabase Auth. RLS policies are therefore permissive for the
-- anon/authenticated key the app uses.
-- ============================================================

-- ============================================================
-- 0. EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. ENUMS  (aligned with lib/utils/constants.dart & role_access.dart)
-- ============================================================

CREATE TYPE public.registration_status AS ENUM ('pending', 'approved', 'rejected');

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
  'cedula'
);

CREATE TYPE public.request_status AS ENUM (
  'draft',
  'submitted',
  'pending_payment',
  'payment_submitted',
  'payment_verified',
  'pending_review',
  'generated',
  'pending_secretary_review',
  'needs_revision',
  'approved',
  'approved_for_release',
  'released',
  'archived',
  'cancelled',
  'rejected'
);

CREATE TYPE public.payment_status AS ENUM (
  'pending',
  'submitted',
  'verified',
  'rejected',
  'cancelled'
);

CREATE TYPE public.notification_type AS ENUM (
  'registration_approved',
  'registration_rejected',
  'request_submitted',
  'request_approved',
  'request_rejected',
  'request_released',
  'payment_submitted',
  'payment_verified',
  'payment_rejected',
  'incident_submitted',
  'incident_updated',
  'system'
);

CREATE TYPE public.payment_method AS ENUM (
  'gcash',
  'cash_onsite',
  'manual_cashier'
);

CREATE TYPE public.payment_record_status AS ENUM (
  'submitted',
  'verified',
  'rejected',
  'cancelled'
);

CREATE TYPE public.verification_status AS ENUM (
  'valid',
  'revoked',
  'expired'
);

CREATE TYPE public.incident_report_type AS ENUM (
  'complaint',
  'disturbance',
  'threat',
  'emergency',
  'peace_and_order',
  'accident',
  'disaster',
  'domestic_concern',
  'noise_complaint',
  'sanitation',
  'other'
);

CREATE TYPE public.incident_priority AS ENUM (
  'low',
  'normal',
  'high',
  'urgent'
);

CREATE TYPE public.incident_status AS ENUM (
  'submitted',
  'received',
  'under_assessment',
  'in_progress',
  'endorsed',
  'resolved',
  'closed',
  'dismissed'
);

CREATE TYPE public.identity_visibility AS ENUM (
  'visible',
  'restricted',
  'hidden_until_authorized'
);

-- ============================================================
-- 2. TABLES
-- ============================================================

-- 2a. Users -------------------------------------------------------
CREATE TABLE public.users_profile (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  username        TEXT NOT NULL UNIQUE,
  email           TEXT NOT NULL UNIQUE,
  password_hash   TEXT NOT NULL,
  full_name       TEXT NOT NULL,
  address         TEXT NOT NULL,
  age             INTEGER NOT NULL CHECK (age >= 0 AND age <= 150),
  date_of_birth   DATE NOT NULL,
  place_of_birth  TEXT NOT NULL,
  civil_status    TEXT NOT NULL,
  gender          TEXT NOT NULL,
  phone_number    TEXT NOT NULL,
  profile_photo_url TEXT,
  valid_id_url    TEXT,
  is_approved     BOOLEAN NOT NULL DEFAULT FALSE,
  registration_status public.registration_status NOT NULL DEFAULT 'pending',
  rejection_reason TEXT,
  role            public.user_role NOT NULL DEFAULT 'citizen',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2b. Barangay config ---------------------------------------------
CREATE TABLE public.barangay_config (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  gcash_name      TEXT NOT NULL DEFAULT 'Barangay Guion',
  gcash_number    TEXT NOT NULL DEFAULT '09XXXXXXXXX',
  barangay_name   TEXT NOT NULL DEFAULT 'Barangay Guion',
  barangay_address TEXT NOT NULL DEFAULT 'Guion, Philippines',
  barangay_captain TEXT,
  contact_number  TEXT,
  email           TEXT,
  logo_url        TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2c. Document fees ------------------------------------------------
CREATE TABLE public.document_fees (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  document_type   public.document_type NOT NULL UNIQUE,
  fee_amount      NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (fee_amount >= 0),
  description     TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2d. Document requests --------------------------------------------
CREATE TABLE public.document_requests (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id                 UUID NOT NULL REFERENCES public.users_profile(id) ON DELETE CASCADE,
  document_type           public.document_type NOT NULL,
  purpose                 TEXT NOT NULL,
  document_data           JSONB NOT NULL DEFAULT '{}'::jsonb,

  -- Status
  request_status          public.request_status NOT NULL DEFAULT 'pending_payment',
  rejection_reason        TEXT,

  -- Payment
  payment_amount          NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (payment_amount >= 0),
  payment_required        BOOLEAN NOT NULL DEFAULT TRUE,
  payment_receipt_url     TEXT,
  payment_status          public.payment_status NOT NULL DEFAULT 'pending',
  payment_method          TEXT,          -- kept TEXT so the app can write gcash/cash_onsite/manual_cashier freely
  payment_reference_number TEXT,
  payment_verified_at     TIMESTAMPTZ,
  payment_verified_by     UUID REFERENCES public.users_profile(id) ON DELETE SET NULL,
  payment_rejection_reason TEXT,

  -- Generated / released document
  document_url            TEXT,
  generated_document_url  TEXT,
  final_document_url      TEXT,
  document_id             TEXT UNIQUE,
  verification_token      TEXT,
  qr_url                  TEXT,
  document_hash           TEXT,

  -- Review / approval / release metadata
  reviewed_at             TIMESTAMPTZ,
  reviewed_by             UUID REFERENCES public.users_profile(id) ON DELETE SET NULL,
  approved_by             UUID REFERENCES public.users_profile(id) ON DELETE SET NULL,
  approved_at             TIMESTAMPTZ,
  released_by             UUID REFERENCES public.users_profile(id) ON DELETE SET NULL,
  released_at             TIMESTAMPTZ,
  release_method          TEXT,

  -- Timestamps
  requested_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2e. Barangay ID detail (optional normalised store) ---------------
CREATE TABLE public.barangay_id_details (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id              UUID NOT NULL REFERENCES public.document_requests(id) ON DELETE CASCADE,
  emergency_contact_name  TEXT NOT NULL,
  emergency_contact_number TEXT NOT NULL,
  blood_type              TEXT,
  occupation              TEXT,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2f. Indigency detail ---------------------------------------------
CREATE TABLE public.indigency_details (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id              UUID NOT NULL REFERENCES public.document_requests(id) ON DELETE CASCADE,
  monthly_income          NUMERIC(10,2),
  number_of_dependents    INTEGER,
  employment_status       TEXT,
  specific_purpose        TEXT,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2g. Cedula detail ------------------------------------------------
CREATE TABLE public.cedula_details (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id              UUID NOT NULL REFERENCES public.document_requests(id) ON DELETE CASCADE,
  citizenship             TEXT,
  profession_occupation   TEXT,
  height_cm               NUMERIC(5,2),
  weight_kg               NUMERIC(5,2),
  tin_number              TEXT,
  community_tax_due       NUMERIC(10,2),
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2h. Notifications ------------------------------------------------
CREATE TABLE public.notifications (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES public.users_profile(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  message     TEXT NOT NULL,
  type        TEXT NOT NULL DEFAULT 'system',   -- kept TEXT for flexibility
  is_read     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2i. Payments (normalised ledger) ---------------------------------
CREATE TABLE public.payments (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id        UUID NOT NULL REFERENCES public.document_requests(id) ON DELETE CASCADE,
  user_id           UUID NOT NULL REFERENCES public.users_profile(id) ON DELETE CASCADE,
  payment_method    TEXT NOT NULL,
  amount            NUMERIC(10,2) NOT NULL CHECK (amount >= 0),
  reference_number  TEXT,
  receipt_url       TEXT,
  status            TEXT NOT NULL DEFAULT 'submitted',
  encoded_by        UUID REFERENCES public.users_profile(id) ON DELETE SET NULL,
  verified_by       UUID REFERENCES public.users_profile(id) ON DELETE SET NULL,
  verified_at       TIMESTAMPTZ,
  rejection_reason  TEXT,
  remarks           TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2j. Document versions --------------------------------------------
CREATE TABLE public.document_versions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id      UUID NOT NULL REFERENCES public.document_requests(id) ON DELETE CASCADE,
  version_number  INTEGER NOT NULL DEFAULT 1,
  file_url        TEXT NOT NULL,
  document_hash   TEXT,
  generated_by    UUID REFERENCES public.users_profile(id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (request_id, version_number)
);

-- 2k. Document verifications (QR / public verify) ------------------
CREATE TABLE public.document_verifications (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id          UUID NOT NULL REFERENCES public.document_requests(id) ON DELETE CASCADE,
  document_id         TEXT NOT NULL UNIQUE,
  verification_token  TEXT NOT NULL,
  document_type       TEXT NOT NULL,
  citizen_name        TEXT NOT NULL,
  status              TEXT NOT NULL DEFAULT 'valid',
  issued_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  released_by         UUID REFERENCES public.users_profile(id) ON DELETE SET NULL,
  document_hash       TEXT,
  revoked_at          TIMESTAMPTZ,
  revoked_by          UUID REFERENCES public.users_profile(id) ON DELETE SET NULL,
  revoke_reason       TEXT
);

-- 2l. Audit logs ---------------------------------------------------
CREATE TABLE public.audit_logs (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  actor_id    UUID REFERENCES public.users_profile(id) ON DELETE SET NULL,
  actor_role  TEXT,
  action      TEXT NOT NULL,
  table_name  TEXT,
  record_id   UUID,
  old_values  JSONB,
  new_values  JSONB,
  ip_address  TEXT,
  user_agent  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2m. Incident reports ---------------------------------------------
CREATE TABLE public.incident_reports (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  report_number       TEXT NOT NULL UNIQUE,
  submitted_by        UUID REFERENCES public.users_profile(id) ON DELETE SET NULL,
  report_type         TEXT NOT NULL DEFAULT 'other',
  title               TEXT NOT NULL,
  description         TEXT NOT NULL,
  location            TEXT NOT NULL,
  incident_datetime   TIMESTAMPTZ NOT NULL,
  is_sensitive        BOOLEAN NOT NULL DEFAULT FALSE,
  is_anonymous        BOOLEAN NOT NULL DEFAULT FALSE,
  identity_visibility TEXT NOT NULL DEFAULT 'visible',
  priority            TEXT NOT NULL DEFAULT 'normal',
  status              TEXT NOT NULL DEFAULT 'submitted',
  received_by         UUID REFERENCES public.users_profile(id) ON DELETE SET NULL,
  received_at         TIMESTAMPTZ,
  assigned_to         UUID REFERENCES public.users_profile(id) ON DELETE SET NULL,
  escalated_to        UUID REFERENCES public.users_profile(id) ON DELETE SET NULL,
  resolved_by         UUID REFERENCES public.users_profile(id) ON DELETE SET NULL,
  resolved_at         TIMESTAMPTZ,
  resolution_summary  TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2n. Incident updates ---------------------------------------------
CREATE TABLE public.incident_updates (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  incident_report_id  UUID NOT NULL REFERENCES public.incident_reports(id) ON DELETE CASCADE,
  updated_by          UUID REFERENCES public.users_profile(id) ON DELETE SET NULL,
  old_status          TEXT,
  new_status          TEXT NOT NULL,
  remarks             TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2o. Incident attachments -----------------------------------------
CREATE TABLE public.incident_attachments (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  incident_report_id  UUID NOT NULL REFERENCES public.incident_reports(id) ON DELETE CASCADE,
  uploaded_by         UUID REFERENCES public.users_profile(id) ON DELETE SET NULL,
  file_url            TEXT NOT NULL,
  file_type           TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2p. Identity access logs -----------------------------------------
CREATE TABLE public.identity_access_logs (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  incident_report_id  UUID NOT NULL REFERENCES public.incident_reports(id) ON DELETE CASCADE,
  accessed_by         UUID REFERENCES public.users_profile(id) ON DELETE SET NULL,
  reason              TEXT NOT NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 3. INDEXES
-- ============================================================

CREATE INDEX idx_users_email              ON public.users_profile(email);
CREATE INDEX idx_users_username           ON public.users_profile(username);
CREATE INDEX idx_users_role               ON public.users_profile(role);
CREATE INDEX idx_users_reg_status         ON public.users_profile(registration_status);

CREATE INDEX idx_docreq_user_id           ON public.document_requests(user_id);
CREATE INDEX idx_docreq_type              ON public.document_requests(document_type);
CREATE INDEX idx_docreq_status            ON public.document_requests(request_status);
CREATE INDEX idx_docreq_pay_status        ON public.document_requests(payment_status);
CREATE INDEX idx_docreq_requested_at      ON public.document_requests(requested_at DESC);
CREATE INDEX idx_docreq_document_id       ON public.document_requests(document_id);

CREATE INDEX idx_notif_user_id            ON public.notifications(user_id);
CREATE INDEX idx_notif_is_read            ON public.notifications(is_read);
CREATE INDEX idx_notif_created_at         ON public.notifications(created_at DESC);

CREATE INDEX idx_payments_request_id      ON public.payments(request_id);
CREATE INDEX idx_payments_user_id         ON public.payments(user_id);
CREATE INDEX idx_payments_status          ON public.payments(status);

CREATE INDEX idx_docver_document_id       ON public.document_verifications(document_id);
CREATE INDEX idx_docver_token             ON public.document_verifications(verification_token);

CREATE INDEX idx_incident_submitted_by    ON public.incident_reports(submitted_by);
CREATE INDEX idx_incident_status          ON public.incident_reports(status);
CREATE INDEX idx_incident_created_at      ON public.incident_reports(created_at DESC);
CREATE INDEX idx_incident_upd_report_id   ON public.incident_updates(incident_report_id);
CREATE INDEX idx_identity_log_report_id   ON public.identity_access_logs(incident_report_id);

-- ============================================================
-- 4. FUNCTIONS & TRIGGERS
-- ============================================================

-- 4a. Auto-update updated_at --------------------------------------
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON public.users_profile
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_brgyconfig_updated_at
  BEFORE UPDATE ON public.barangay_config
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_docfees_updated_at
  BEFORE UPDATE ON public.document_fees
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_docreq_updated_at
  BEFORE UPDATE ON public.document_requests
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_incident_updated_at
  BEFORE UPDATE ON public.incident_reports
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 4b. Notify citizen on registration status change -----------------
CREATE OR REPLACE FUNCTION public.notify_registration_status()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.registration_status IS DISTINCT FROM OLD.registration_status THEN
    IF NEW.registration_status = 'approved' THEN
      INSERT INTO public.notifications (user_id, title, message, type)
      VALUES (
        NEW.id,
        'Registration Approved',
        'Congratulations! Your registration has been approved. You can now request documents.',
        'registration_approved'
      );
    ELSIF NEW.registration_status = 'rejected' THEN
      INSERT INTO public.notifications (user_id, title, message, type)
      VALUES (
        NEW.id,
        'Registration Rejected',
        CONCAT('Your registration was rejected. Reason: ', COALESCE(NEW.rejection_reason, 'No reason provided')),
        'registration_rejected'
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_registration_notification
  AFTER UPDATE ON public.users_profile
  FOR EACH ROW
  WHEN (OLD.registration_status IS DISTINCT FROM NEW.registration_status)
  EXECUTE FUNCTION public.notify_registration_status();

-- 4c. Notify citizen on document request / payment changes ---------
CREATE OR REPLACE FUNCTION public.notify_request_status()
RETURNS TRIGGER AS $$
BEGIN
  -- Payment status changes
  IF NEW.payment_status IS DISTINCT FROM OLD.payment_status THEN
    IF NEW.payment_status = 'verified' THEN
      INSERT INTO public.notifications (user_id, title, message, type)
      VALUES (
        NEW.user_id,
        'Payment Verified',
        CONCAT('Your payment for ', REPLACE(NEW.document_type::TEXT, '_', ' '), ' has been verified.'),
        'payment_verified'
      );
    ELSIF NEW.payment_status = 'rejected' THEN
      INSERT INTO public.notifications (user_id, title, message, type)
      VALUES (
        NEW.user_id,
        'Payment Rejected',
        CONCAT('Your payment was rejected. Reason: ', COALESCE(NEW.payment_rejection_reason, 'No reason provided')),
        'payment_rejected'
      );
    END IF;
  END IF;

  -- Request status changes
  IF NEW.request_status IS DISTINCT FROM OLD.request_status THEN
    IF NEW.request_status::TEXT IN ('approved', 'approved_for_release') THEN
      INSERT INTO public.notifications (user_id, title, message, type)
      VALUES (
        NEW.user_id,
        'Document Approved',
        CONCAT('Your ', REPLACE(NEW.document_type::TEXT, '_', ' '), ' has been approved.'),
        'request_approved'
      );
    ELSIF NEW.request_status::TEXT = 'released' THEN
      INSERT INTO public.notifications (user_id, title, message, type)
      VALUES (
        NEW.user_id,
        'Document Released',
        CONCAT('Your ', REPLACE(NEW.document_type::TEXT, '_', ' '), ' has been released! You can now download it.'),
        'request_released'
      );
    ELSIF NEW.request_status::TEXT = 'rejected' THEN
      INSERT INTO public.notifications (user_id, title, message, type)
      VALUES (
        NEW.user_id,
        'Document Request Rejected',
        CONCAT('Your request was rejected. Reason: ', COALESCE(NEW.rejection_reason, 'No reason provided')),
        'request_rejected'
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_request_notification
  AFTER UPDATE ON public.document_requests
  FOR EACH ROW
  WHEN (
    OLD.request_status IS DISTINCT FROM NEW.request_status
    OR OLD.payment_status IS DISTINCT FROM NEW.payment_status
  )
  EXECUTE FUNCTION public.notify_request_status();

-- 4d. Notify all officials on new document request -----------------
CREATE OR REPLACE FUNCTION public.notify_officials_new_request()
RETURNS TRIGGER AS $$
DECLARE
  official_id UUID;
BEGIN
  FOR official_id IN
    SELECT id FROM public.users_profile
    WHERE role IN ('admin', 'captain', 'secretary', 'treasurer', 'kagawad_representative')
      AND registration_status = 'approved'
  LOOP
    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (
      official_id,
      'New Document Request',
      CONCAT('A new ', REPLACE(NEW.document_type::TEXT, '_', ' '), ' request has been submitted.'),
      'request_submitted'
    );
  END LOOP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_officials_new_request
  AFTER INSERT ON public.document_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_officials_new_request();

-- ============================================================
-- 5. STORAGE BUCKETS
-- ============================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('profile-photos',       'profile-photos',       TRUE, 5242880,   ARRAY['image/jpeg','image/jpg','image/png','image/webp']),
  ('valid-ids',            'valid-ids',             TRUE, 10485760,  ARRAY['image/jpeg','image/jpg','image/png','image/webp','application/pdf']),
  ('payment-receipts',     'payment-receipts',      TRUE, 10485760,  ARRAY['image/jpeg','image/jpg','image/png','image/webp','application/pdf']),
  ('documents',            'documents',             TRUE, 20971520,  ARRAY['application/pdf','image/jpeg','image/png','image/webp']),
  ('incident-attachments', 'incident-attachments',  TRUE, 20971520,  ARRAY['image/jpeg','image/jpg','image/png','image/webp','application/pdf','video/mp4'])
ON CONFLICT (id) DO UPDATE SET
  public             = EXCLUDED.public,
  file_size_limit    = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ============================================================
-- 6. STORAGE POLICIES
-- ============================================================

DO $$ BEGIN
  DROP POLICY IF EXISTS "Allow public read on storage"  ON storage.objects;
  DROP POLICY IF EXISTS "Allow public insert on storage" ON storage.objects;
  DROP POLICY IF EXISTS "Allow public update on storage" ON storage.objects;
  DROP POLICY IF EXISTS "Allow public delete on storage" ON storage.objects;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

CREATE POLICY "Allow public read on storage"
  ON storage.objects FOR SELECT
  USING (bucket_id IN ('profile-photos','valid-ids','payment-receipts','documents','incident-attachments'));

CREATE POLICY "Allow public insert on storage"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id IN ('profile-photos','valid-ids','payment-receipts','documents','incident-attachments'));

CREATE POLICY "Allow public update on storage"
  ON storage.objects FOR UPDATE
  USING (bucket_id IN ('profile-photos','valid-ids','payment-receipts','documents','incident-attachments'));

CREATE POLICY "Allow public delete on storage"
  ON storage.objects FOR DELETE
  USING (bucket_id IN ('profile-photos','valid-ids','payment-receipts','documents','incident-attachments'));

-- ============================================================
-- 7. ROW LEVEL SECURITY — PERMISSIVE (custom-auth app)
-- ============================================================
-- The Flutter app authenticates via the anon key and manages
-- access control in Dart.  All tables are therefore open to
-- the anon role so PostgREST calls succeed.

ALTER TABLE public.users_profile        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.barangay_config      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_fees        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_requests    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.barangay_id_details  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.indigency_details    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cedula_details       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_versions    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incident_reports     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incident_updates     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incident_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.identity_access_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "open" ON public.users_profile          FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "open" ON public.barangay_config        FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "open" ON public.document_fees          FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "open" ON public.document_requests      FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "open" ON public.barangay_id_details    FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "open" ON public.indigency_details      FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "open" ON public.cedula_details         FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "open" ON public.notifications          FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "open" ON public.payments               FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "open" ON public.document_versions      FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "open" ON public.document_verifications FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "open" ON public.audit_logs             FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "open" ON public.incident_reports       FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "open" ON public.incident_updates       FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "open" ON public.incident_attachments   FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "open" ON public.identity_access_logs   FOR ALL USING (true) WITH CHECK (true);

-- ============================================================
-- 8. REALTIME — enable for tables the app subscribes to
-- ============================================================

ALTER PUBLICATION supabase_realtime ADD TABLE public.document_requests;
ALTER PUBLICATION supabase_realtime ADD TABLE public.users_profile;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- ============================================================
-- 9. SEED DATA
-- ============================================================

-- 9a. Default barangay config
INSERT INTO public.barangay_config (
  gcash_name, gcash_number, barangay_name, barangay_address,
  barangay_captain, contact_number, email
) VALUES (
  'Barangay Guion', '09XXXXXXXXX', 'Barangay Guion', 'Guion, Philippines',
  'Barangay Captain', NULL, NULL
);

-- 9b. Default document fees
INSERT INTO public.document_fees (document_type, fee_amount, description) VALUES
  ('barangay_clearance', 50.00,  'Barangay Clearance processing fee'),
  ('indigency',          0.00,   'Certificate of Indigency (free)'),
  ('barangay_id',        100.00, 'Barangay ID card processing fee'),
  ('cedula',             50.00,  'Community Tax Certificate / Cedula');

-- 9c. Placeholder official accounts
-- IMPORTANT: Replace 'CHANGE_ME' password_hash values with real hashes
-- generated by the app's PasswordHash utility before logging in.
INSERT INTO public.users_profile (
  username, email, password_hash,
  full_name, address, age, date_of_birth,
  place_of_birth, civil_status, gender, phone_number,
  is_approved, registration_status, role
) VALUES
  ('admin',     'admin@guion.local',     'CHANGE_ME', 'System Administrator',    'Barangay Guion', 40, '1985-01-01', 'Guion', 'Single', 'Other', '09000000000', TRUE, 'approved', 'admin'),
  ('captain',   'captain@guion.local',   'CHANGE_ME', 'Barangay Captain',        'Barangay Guion', 45, '1980-01-01', 'Guion', 'Married','Other', '09000000001', TRUE, 'approved', 'captain'),
  ('secretary', 'secretary@guion.local', 'CHANGE_ME', 'Barangay Secretary',      'Barangay Guion', 35, '1990-01-01', 'Guion', 'Single', 'Other', '09000000002', TRUE, 'approved', 'secretary'),
  ('treasurer', 'treasurer@guion.local', 'CHANGE_ME', 'Barangay Treasurer',      'Barangay Guion', 35, '1990-01-01', 'Guion', 'Single', 'Other', '09000000003', TRUE, 'approved', 'treasurer'),
  ('kagawad',   'kagawad@guion.local',   'CHANGE_ME', 'Kagawad Representative',  'Barangay Guion', 38, '1987-01-01', 'Guion', 'Married','Other', '09000000004', TRUE, 'approved', 'kagawad_representative'),
  ('tanod',     'tanod@guion.local',     'CHANGE_ME', 'Barangay Tanod',          'Barangay Guion', 30, '1995-01-01', 'Guion', 'Single', 'Other', '09000000005', TRUE, 'approved', 'barangay_tanod')
ON CONFLICT (email) DO NOTHING;

-- ============================================================
-- 10. ROLE / UI ALIGNMENT REFERENCE
-- ============================================================
-- captain / admin:
--   Dashboard shows: all stat cards, manage users, settings, fees,
--   formats, incident reports, verify document, all requests.
--   Can: approve/reject users, verify payments, review/approve/release
--   documents, manage reports, reveal sensitive reporter identity.
--
-- secretary:
--   Dashboard shows: pending reviews, approved/rejected stats,
--   view all requests, verify document.
--   Can: review documents, generate PDFs, release documents.
--
-- treasurer:
--   Dashboard shows: pending payments, verify document.
--   Can: verify GCash receipts, encode cash/manual cashier payments.
--
-- kagawad_representative:
--   Dashboard shows: pending reviews, incident reports, verify document.
--   Can: review/release documents, manage incident reports.
--
-- barangay_tanod:
--   Dashboard shows: incident reports, verify document.
--   Can: manage incident reports only.
--
-- citizen:
--   Dashboard shows: request document, my requests, report incident,
--   my reports, verify document, notifications.
--   Can: register, login, request documents, upload payment receipts,
--   submit incident reports, view own reports, verify documents.
-- ============================================================

