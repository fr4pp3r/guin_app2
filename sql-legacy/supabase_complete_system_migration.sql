CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'captain';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'secretary';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'treasurer';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'kagawad_representative';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'barangay_tanod';

ALTER TABLE document_requests
  ADD COLUMN IF NOT EXISTS request_number TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS payment_required BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS payment_method TEXT,
  ADD COLUMN IF NOT EXISTS payment_reference_number TEXT,
  ADD COLUMN IF NOT EXISTS generated_document_url TEXT,
  ADD COLUMN IF NOT EXISTS final_document_url TEXT,
  ADD COLUMN IF NOT EXISTS document_id TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS verification_token TEXT,
  ADD COLUMN IF NOT EXISTS qr_url TEXT,
  ADD COLUMN IF NOT EXISTS document_hash TEXT,
  ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES users_profile(id),
  ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS released_by UUID REFERENCES users_profile(id),
  ADD COLUMN IF NOT EXISTS released_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS release_method TEXT DEFAULT 'ecopy',
  ADD COLUMN IF NOT EXISTS printed_by UUID REFERENCES users_profile(id),
  ADD COLUMN IF NOT EXISTS printed_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES users_profile(id),
  ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

CREATE TABLE IF NOT EXISTS role_permissions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  role_key TEXT NOT NULL,
  permission_key TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(role_key, permission_key)
);

CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id UUID NOT NULL REFERENCES document_requests(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users_profile(id) ON DELETE CASCADE,
  payment_method TEXT NOT NULL CHECK (payment_method IN ('gcash', 'cash_on_site', 'manual_cashier')),
  amount DECIMAL(10,2) NOT NULL CHECK (amount >= 0),
  reference_number TEXT,
  receipt_url TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'submitted', 'verified', 'rejected')),
  encoded_by UUID REFERENCES users_profile(id),
  verified_by UUID REFERENCES users_profile(id),
  verified_at TIMESTAMP WITH TIME ZONE,
  rejection_reason TEXT,
  remarks TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS document_versions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id UUID NOT NULL REFERENCES document_requests(id) ON DELETE CASCADE,
  version_number INTEGER NOT NULL,
  file_url TEXT NOT NULL,
  file_hash TEXT,
  status TEXT NOT NULL DEFAULT 'generated',
  generated_by UUID REFERENCES users_profile(id),
  generated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  remarks TEXT,
  UNIQUE(request_id, version_number)
);

CREATE TABLE IF NOT EXISTS document_verifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id UUID NOT NULL REFERENCES document_requests(id) ON DELETE CASCADE,
  document_id TEXT NOT NULL UNIQUE,
  verification_token TEXT NOT NULL,
  document_type TEXT NOT NULL,
  citizen_name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'valid' CHECK (status IN ('valid', 'revoked', 'expired')),
  issued_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  released_by UUID REFERENCES users_profile(id),
  revoked_by UUID REFERENCES users_profile(id),
  revoked_at TIMESTAMP WITH TIME ZONE,
  revocation_reason TEXT,
  document_hash TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS incident_reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  report_number TEXT UNIQUE,
  submitted_by UUID REFERENCES users_profile(id),
  report_type TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  location TEXT NOT NULL,
  incident_datetime TIMESTAMP WITH TIME ZONE NOT NULL,
  is_sensitive BOOLEAN DEFAULT FALSE,
  is_anonymous BOOLEAN DEFAULT FALSE,
  identity_visibility TEXT DEFAULT 'visible' CHECK (identity_visibility IN ('visible', 'restricted', 'hidden_until_authorized')),
  priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  status TEXT DEFAULT 'submitted' CHECK (status IN ('submitted', 'received', 'under_assessment', 'endorsed', 'in_progress', 'resolved', 'closed', 'rejected')),
  received_by UUID REFERENCES users_profile(id),
  received_at TIMESTAMP WITH TIME ZONE,
  assigned_to UUID REFERENCES users_profile(id),
  escalated_to UUID REFERENCES users_profile(id),
  resolved_by UUID REFERENCES users_profile(id),
  resolved_at TIMESTAMP WITH TIME ZONE,
  resolution_summary TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS incident_updates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  incident_report_id UUID NOT NULL REFERENCES incident_reports(id) ON DELETE CASCADE,
  updated_by UUID REFERENCES users_profile(id),
  old_status TEXT,
  new_status TEXT,
  remarks TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS incident_attachments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  incident_report_id UUID NOT NULL REFERENCES incident_reports(id) ON DELETE CASCADE,
  file_url TEXT NOT NULL,
  file_type TEXT,
  uploaded_by UUID REFERENCES users_profile(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS identity_access_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  incident_report_id UUID NOT NULL REFERENCES incident_reports(id) ON DELETE CASCADE,
  accessed_by UUID NOT NULL REFERENCES users_profile(id),
  reason TEXT NOT NULL,
  accessed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  actor_user_id UUID REFERENCES users_profile(id),
  actor_role TEXT,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID,
  old_value JSONB,
  new_value JSONB,
  remarks TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payments_request_id ON payments(request_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
CREATE INDEX IF NOT EXISTS idx_document_verifications_document_id ON document_verifications(document_id);
CREATE INDEX IF NOT EXISTS idx_incident_reports_status ON incident_reports(status);
CREATE INDEX IF NOT EXISTS idx_incident_reports_submitted_by ON incident_reports(submitted_by);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id);

INSERT INTO role_permissions (role_key, permission_key) VALUES
('captain', 'system.full_access'),
('captain', 'documents.release'),
('captain', 'payments.verify'),
('captain', 'reports.resolve'),
('secretary', 'documents.view'),
('secretary', 'documents.generate'),
('secretary', 'documents.review'),
('secretary', 'documents.release'),
('treasurer', 'payments.view'),
('treasurer', 'payments.verify'),
('treasurer', 'payments.reject'),
('kagawad_representative', 'documents.delegated_review'),
('kagawad_representative', 'reports.escalate'),
('barangay_tanod', 'reports.receive'),
('barangay_tanod', 'reports.update'),
('barangay_tanod', 'reports.escalate'),
('citizen', 'documents.request'),
('citizen', 'reports.submit')
ON CONFLICT (role_key, permission_key) DO NOTHING;

UPDATE document_fees SET fee_amount = 0 WHERE document_type = 'indigency';
