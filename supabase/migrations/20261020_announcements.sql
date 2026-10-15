-- ============================================================================
-- Migration: barangay announcements board
-- (CANONICAL, ADDITIVE, non-destructive)
--
-- Adds `public.announcements`: barangay-wide notices posted by officials
-- (captain / secretary / admin — see AppRoles.canPostAnnouncements in
-- lib/utils/role_access.dart). EVERY signed-in user reads the same rows, so
-- there is no audience column and no per-user read state.
--
-- `created_by_name` is denormalized: the feed renders the poster's name
-- without joining users_profile, and the name survives the poster's deletion
-- (`created_by` is ON DELETE SET NULL).
--
-- The table is added to the supabase_realtime publication so live feeds update
-- without a manual refresh. A missing publication entry fails silently (the
-- channel connects but never delivers), which is why the membership check is
-- explicit here.
--
-- Safe to re-run (idempotent): every statement is IF NOT EXISTS guarded or
-- wrapped in a catalog check. Apply via the SQL Editor on a live project;
-- never run setup.sql against a live database.
-- ============================================================================


-- ============================================================================
-- SECTION 1 — announcements table
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.announcements (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title           TEXT NOT NULL,
  body            TEXT NOT NULL,
  created_by      UUID REFERENCES public.users_profile(id) ON DELETE SET NULL,
  created_by_name TEXT NOT NULL,
  is_pinned       BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================================
-- SECTION 2 — indexes
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_announcements_created ON public.announcements(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_announcements_pinned  ON public.announcements(is_pinned);


-- ============================================================================
-- SECTION 3 — updated_at trigger
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_announcements_updated_at'
  ) THEN
    CREATE TRIGGER trg_announcements_updated_at
      BEFORE UPDATE ON public.announcements
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;


-- ============================================================================
-- SECTION 4 — RLS
-- Same permissive posture as every other table in this project: Supabase Auth
-- is not used, so auth.uid() is always NULL and any auth.uid()-based policy
-- would lock the app out. Access control is client-side (role_access.dart).
-- ============================================================================

ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies
                 WHERE tablename = 'announcements'
                   AND policyname = 'app_access_announcements') THEN
    CREATE POLICY "app_access_announcements" ON public.announcements
      FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;


-- ============================================================================
-- SECTION 5 — realtime
-- ============================================================================

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['announcements'] LOOP
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
