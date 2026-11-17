-- Email OTP verification. Client roles have NO access; service role only.
CREATE TABLE IF NOT EXISTS public.email_otps (
  email        TEXT PRIMARY KEY,
  code_hash    TEXT NOT NULL,
  expires_at   TIMESTAMPTZ NOT NULL,
  attempts     INT NOT NULL DEFAULT 0,
  send_count   INT NOT NULL DEFAULT 0,
  send_window_start TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.email_otps ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.verified_emails (
  email       TEXT PRIMARY KEY,
  verified_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.verified_emails ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.users_profile
  ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT FALSE;

CREATE OR REPLACE FUNCTION public.set_email_verified()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  NEW.email_verified := EXISTS (
    SELECT 1 FROM public.verified_emails v WHERE v.email = NEW.email
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_email_verified ON public.users_profile;
CREATE TRIGGER trg_set_email_verified
  BEFORE INSERT OR UPDATE OF email, email_verified ON public.users_profile
  FOR EACH ROW EXECUTE FUNCTION public.set_email_verified();
