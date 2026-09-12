-- Migration: Add business_subtype to profiles and update categories
-- Date: 2026-09-12

-- 1. Add business_subtype column to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS business_subtype text;

-- 2. Drop the restrictive legacy business_type check constraint
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_business_type_check;

-- 3. Migrate existing profile rows from legacy categories to new 2-tier structure
UPDATE profiles
SET business_type = 'b2b_industry',
    business_subtype = 'it_services'
WHERE business_type = 'it_software';

-- Create an index for fast lookups on business_type + business_subtype
CREATE INDEX IF NOT EXISTS idx_profiles_business_type_subtype
  ON profiles (account_type, is_restaurant, business_type, business_subtype);
