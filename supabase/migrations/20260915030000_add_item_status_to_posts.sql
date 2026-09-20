-- Migration: Add item_status to posts for marketplace listing lifecycle
-- Date: 2026-09-15

-- 1. Add item_status column to posts with default 'available'
ALTER TABLE posts ADD COLUMN IF NOT EXISTS item_status text DEFAULT 'available';

-- 2. Backfill existing market posts if null
UPDATE posts
SET item_status = 'available'
WHERE item_status IS NULL;

-- 3. Add check constraint to ensure valid statuses
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'posts_item_status_check'
  ) THEN
    ALTER TABLE posts ADD CONSTRAINT posts_item_status_check
      CHECK (item_status IN ('available', 'reserved', 'sold'));
  END IF;
END $$;

-- 4. Create index for fast filtering on marketplace post status
CREATE INDEX IF NOT EXISTS idx_posts_market_status
  ON posts (post_type, item_status);
