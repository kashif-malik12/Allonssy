-- Migration: Business Seeding & Claiming Support
-- Date: 2026-11-15
-- Adds support for unclaimed businesses, official community bots, SIRET verification, and claim requests.

-- 1. Extend profiles table
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_unclaimed boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_official_bot boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS siret text,
  ADD COLUMN IF NOT EXISTS phone text,
  ADD COLUMN IF NOT EXISTS website text,
  ADD COLUMN IF NOT EXISTS external_source text,
  ADD COLUMN IF NOT EXISTS external_place_id text,
  ADD COLUMN IF NOT EXISTS claim_token uuid DEFAULT gen_random_uuid(),
  ADD COLUMN IF NOT EXISTS claimed_at timestamptz;

-- Create indexes for fast filtering
CREATE INDEX IF NOT EXISTS idx_profiles_is_unclaimed ON public.profiles(is_unclaimed);
CREATE INDEX IF NOT EXISTS idx_profiles_is_official_bot ON public.profiles(is_official_bot);
CREATE INDEX IF NOT EXISTS idx_profiles_siret ON public.profiles(siret);
CREATE INDEX IF NOT EXISTS idx_profiles_external_place_id ON public.profiles(external_place_id);

-- 2. Extend posts table
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS is_unclaimed boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS external_source text,
  ADD COLUMN IF NOT EXISTS external_id text;

CREATE INDEX IF NOT EXISTS idx_posts_is_unclaimed ON public.posts(is_unclaimed);
CREATE INDEX IF NOT EXISTS idx_posts_external_id ON public.posts(external_id);

-- 3. Create business_claims table
CREATE TABLE IF NOT EXISTS public.business_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  requester_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  requester_name text NOT NULL,
  contact_email text NOT NULL,
  contact_phone text,
  proof_notes text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_business_claims_profile_id ON public.business_claims(profile_id);
CREATE INDEX IF NOT EXISTS idx_business_claims_status ON public.business_claims(status);

-- 4. Enable RLS on business_claims
ALTER TABLE public.business_claims ENABLE ROW LEVEL SECURITY;

-- Allow anyone (public guests or authenticated users) to submit a business claim
DROP POLICY IF EXISTS "Anyone can submit a business claim" ON public.business_claims;
CREATE POLICY "Anyone can submit a business claim"
  ON public.business_claims
  FOR INSERT
  WITH CHECK (true);

-- Allow authenticated users to view their own submitted claims
DROP POLICY IF EXISTS "Users can view own claims" ON public.business_claims;
CREATE POLICY "Users can view own claims"
  ON public.business_claims
  FOR SELECT
  TO authenticated
  USING (auth.uid() = requester_id);

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
