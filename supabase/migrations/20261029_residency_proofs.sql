-- 20261029_residency_proofs.sql
-- Tracks utility bill or secondary ID uploads for residency verification.
-- Store URLs only; images are deleted after verification period.

CREATE TABLE IF NOT EXISTS public.document_residency_proofs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users_profile(id) ON DELETE CASCADE,
  proof_url TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'confirmed', 'rejected')),
  auditor_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  verified_at TIMESTAMPTZ
);

CREATE INDEX idx_residency_proofs_user ON public.document_residency_proofs(user_id);
CREATE INDEX idx_residency_proofs_status ON public.document_residency_proofs(status);