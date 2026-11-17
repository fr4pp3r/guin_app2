-- Additive: exact-item deep-link references for notifications.
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS reference_type TEXT,
  ADD COLUMN IF NOT EXISTS reference_id TEXT;
