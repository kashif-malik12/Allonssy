-- ============================================================
-- banned_emails — blocks re-registration with banned addresses
-- ============================================================

CREATE TABLE IF NOT EXISTS public.banned_emails (
  id         uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  email      text        NOT NULL,
  banned_at  timestamptz DEFAULT now() NOT NULL,
  banned_by  uuid        REFERENCES public.profiles(id) ON DELETE SET NULL,
  reason     text
);

-- Case-insensitive unique index
CREATE UNIQUE INDEX IF NOT EXISTS banned_emails_email_lower_idx
  ON public.banned_emails (lower(email));

ALTER TABLE public.banned_emails ENABLE ROW LEVEL SECURITY;

-- Only admins (is_admin = true) can read / write this table
CREATE POLICY "Admins can manage banned_emails"
  ON public.banned_emails
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- ── Trigger: block signup for banned emails ───────────────────────────────────

CREATE OR REPLACE FUNCTION public.check_banned_email_on_signup()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.banned_emails
    WHERE lower(email) = lower(NEW.email)
  ) THEN
    RAISE EXCEPTION 'email_banned: This email address is not allowed to register.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prevent_banned_email_signup ON auth.users;

CREATE TRIGGER prevent_banned_email_signup
  BEFORE INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.check_banned_email_on_signup();
