-- Migration: Add original_price column to posts for price drop / discount indicator
ALTER TABLE public.posts
ADD COLUMN IF NOT EXISTS original_price numeric;

COMMENT ON COLUMN public.posts.original_price IS 'Previous or original price for marketplace discount / price drop indicator.';
