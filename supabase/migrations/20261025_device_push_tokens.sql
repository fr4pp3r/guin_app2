-- ============================================================================
-- Migration: FCM device push tokens
-- (CANONICAL, ADDITIVE, non-destructive)
--
-- Adds `public.device_push_tokens`: one row per (user, Android device) FCM
-- registration token. The app does NOT use Supabase Auth, so rows are keyed by
-- `users_profile.id` — the same identity everything else in this project uses —
-- plus the token itself.
--
-- Written by `PushService` (lib/services/push_service.dart): an idempotent
-- upsert keyed on `token` at login / session restore, and a delete of this
-- device's rows at sign-out, so a second account on the same phone never
-- receives the first account's pushes.
--
-- Read by the `push` Edge Function (supabase/functions/push/), which fans a
-- notification out to every token a user owns. Tokens are messages AND
-- addresses: anyone holding one can post a push to that device, which is why
-- every client-side statement in this project that touches the table is
-- best-effort and the sending half stays server-side.
--
-- No realtime publication entry: nothing subscribes to this table live.
--
-- Safe to re-run (idempotent): every statement is IF NOT EXISTS guarded or
-- wrapped in a catalog check. Apply via the SQL Editor on a live project;
-- never run setup.sql against a live database.
-- ============================================================================


-- ============================================================================
-- SECTION 1 — device_push_tokens table
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.device_push_tokens (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES public.users_profile(id) ON DELETE CASCADE,
  -- FCM registration token. UNIQUE is what makes the client upsert idempotent
  -- and prevents one device accumulating duplicate rows for the same user.
  token        TEXT NOT NULL UNIQUE,
  -- 'android' today (iOS/web push is not wired). Kept as free TEXT so a
  -- platform can be added without a type migration.
  platform     TEXT NOT NULL DEFAULT 'android',
  device_model TEXT,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================================
-- SECTION 2 — indexes
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_device_push_tokens_user
  ON public.device_push_tokens(user_id);


-- ============================================================================
-- SECTION 3 — updated_at trigger
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_device_push_tokens_updated_at'
  ) THEN
    CREATE TRIGGER trg_device_push_tokens_updated_at
      BEFORE UPDATE ON public.device_push_tokens
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;


-- ============================================================================
-- SECTION 4 — RLS
-- Same permissive posture as every other table in this project: Supabase Auth
-- is not used, so auth.uid() is always NULL and any auth.uid()-based policy
-- would lock every device out of registering its token. Access control is
-- client-side (lib/utils/role_access.dart); the push function reads this table
-- with the service role, bypassing RLS entirely.
-- ============================================================================

ALTER TABLE public.device_push_tokens ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies
                 WHERE tablename = 'device_push_tokens'
                   AND policyname = 'app_access_device_push_tokens') THEN
    CREATE POLICY "app_access_device_push_tokens" ON public.device_push_tokens
      FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;
