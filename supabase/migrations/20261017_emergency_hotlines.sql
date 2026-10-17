-- ============================================================================
-- Migration: emergency hotline directory
-- (CANONICAL, ADDITIVE, non-destructive)
--
-- Adds `public.emergency_hotlines`: emergency contact numbers displayed to
-- every signed-in user. Only officials who pass AppRoles.canManageHotlines
-- (captain / secretary / admin — see lib/utils/role_access.dart) may add,
-- edit, or remove entries; the data layer itself stays permissive like the
-- rest of the app.
--
-- The table is added to the supabase_realtime publication so live feeds
-- update without a manual refresh. A missing publication entry fails
-- silently (the channel connects but never delivers), which is why the
-- membership check is explicit here.
--
-- Safe to re-run (idempotent): every statement is IF NOT EXISTS guarded or
-- wrapped in a catalog check. Apply via the SQL Editor on a live project;
-- never run setup.sql against a live database.
-- ============================================================================


-- ============================================================================
-- SECTION 1 — emergency_hotlines table
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.emergency_hotlines (
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
-- SECTION 2 — indexes
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_emergency_hotlines_active ON public.emergency_hotlines(is_active);
CREATE INDEX IF NOT EXISTS idx_emergency_hotlines_name   ON public.emergency_hotlines(name);


-- ============================================================================
-- SECTION 3 — updated_at trigger
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_emergency_hotlines_updated_at'
  ) THEN
    CREATE TRIGGER trg_emergency_hotlines_updated_at
      BEFORE UPDATE ON public.emergency_hotlines
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;


-- ============================================================================
-- SECTION 4 — RLS
-- Same permissive posture as every other table in this project: Supabase Auth
-- is not used, so auth.uid() is always NULL and any auth.uid()-based policy
-- would lock the app out. Access control is client-side (role_access.dart).
-- ============================================================================

ALTER TABLE public.emergency_hotlines ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies
                 WHERE tablename = 'emergency_hotlines'
                   AND policyname = 'app_access_emergency_hotlines') THEN
    CREATE POLICY "app_access_emergency_hotlines" ON public.emergency_hotlines
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
  FOREACH t IN ARRAY ARRAY['emergency_hotlines'] LOOP
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
