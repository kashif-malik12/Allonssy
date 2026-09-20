-- Migration: Create favorite_businesses table
CREATE TABLE IF NOT EXISTS favorite_businesses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  business_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  CONSTRAINT unique_user_business UNIQUE(user_id, business_id)
);

-- Indexes for quick lookups
CREATE INDEX IF NOT EXISTS idx_favorite_businesses_user_id ON favorite_businesses(user_id);
CREATE INDEX IF NOT EXISTS idx_favorite_businesses_business_id ON favorite_businesses(business_id);

-- Enable RLS
ALTER TABLE favorite_businesses ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can read own favorite businesses"
ON favorite_businesses FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can add own favorite businesses"
ON favorite_businesses FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own favorite businesses"
ON favorite_businesses FOR DELETE
USING (auth.uid() = user_id);
