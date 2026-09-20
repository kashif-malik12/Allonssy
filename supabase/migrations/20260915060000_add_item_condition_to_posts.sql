-- Migration: Add item_condition to posts table
ALTER TABLE posts
ADD COLUMN IF NOT EXISTS item_condition text;

-- Index for filtering marketplace posts by condition
CREATE INDEX IF NOT EXISTS idx_posts_post_type_item_condition
ON posts(post_type, item_condition)
WHERE post_type = 'market';
