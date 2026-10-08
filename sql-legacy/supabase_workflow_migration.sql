-- ============================================================
-- Barangay Workflow Migration
-- Run this in the Supabase SQL editor (Project > SQL Editor)
-- ============================================================

-- 1. Add new columns to document_requests
ALTER TABLE document_requests
  ADD COLUMN IF NOT EXISTS secretary_notes       TEXT,
  ADD COLUMN IF NOT EXISTS draft_url             TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_by_secretary TEXT,
  ADD COLUMN IF NOT EXISTS secretary_verified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS invoice_description   TEXT,
  ADD COLUMN IF NOT EXISTS invoice_due_date      TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS invoice_created_at    TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS captain_unavailable   BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS approver_id           TEXT,
  ADD COLUMN IF NOT EXISTS approver_role         TEXT,
  ADD COLUMN IF NOT EXISTS captain_approved_at   TIMESTAMPTZ;

-- 2. Audit logs table
CREATE TABLE IF NOT EXISTS audit_logs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id    UUID REFERENCES document_requests(id) ON DELETE CASCADE,
  actor_id      TEXT NOT NULL,
  actor_role    TEXT NOT NULL,
  action        TEXT NOT NULL,
  from_status   TEXT,
  to_status     TEXT,
  notes         TEXT,
  created_at    TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_request ON audit_logs(request_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor   ON audit_logs(actor_id);

-- 3. Enable RLS on audit_logs
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "Officials can read audit logs"
  ON audit_logs FOR SELECT
  USING (true);
CREATE POLICY IF NOT EXISTS "Anyone can insert audit logs"
  ON audit_logs FOR INSERT
  WITH CHECK (true);

-- ============================================================
-- Status Reference (enforced in app, not DB enum)
-- submitted           → Citizen submitted request
-- draft_generated     → Secretary generated draft PDF
-- needs_revision      → Secretary requested changes
-- verified_for_payment → Secretary approved, awaiting invoice
-- invoiced            → Invoice created, citizen to pay
-- payment_submitted   → Citizen uploaded payment proof
-- payment_rejected    → Treasurer rejected payment
-- payment_confirmed   → Treasurer verified payment
-- for_approval        → Sent to Captain for final approval
-- approved            → Captain/Kagawad approved (with e-sig)
-- released            → Final doc sent to citizen (QR + doc#)
-- rejected            → Rejected at any stage
-- cancelled           → Citizen cancelled
-- ============================================================
