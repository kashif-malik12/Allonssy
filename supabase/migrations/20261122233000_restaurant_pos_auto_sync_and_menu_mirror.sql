-- Migration: Restaurant POS Auto-Sync Disabler & Menu Mirroring
-- Date: 2026-11-22
-- Disables automated background script sync for any active subdomain store,
-- keeps profile unclaimed on site while allowing full POS usage,
-- and mirrors all POS menu items into Allonssy social feed/directory posts in real time.

-- 1. Add auto_sync_disabled and pos_enabled flags
ALTER TABLE public.restaurant_stores
  ADD COLUMN IF NOT EXISTS auto_sync_disabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS pos_enabled boolean NOT NULL DEFAULT true;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS auto_sync_disabled boolean NOT NULL DEFAULT false;

ALTER TABLE public.restaurant_items
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_profiles_auto_sync ON public.profiles(auto_sync_disabled);

-- 2. Trigger: Automatically disable auto-sync on profile when a restaurant store is created/linked
CREATE OR REPLACE FUNCTION public.trg_disable_auto_sync_on_store_link()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.profile_id IS NOT NULL THEN
    UPDATE public.profiles
    SET 
      auto_sync_disabled = true,
      restaurant_store_id = NEW.id
    WHERE id = NEW.profile_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_store_auto_sync_flag ON public.restaurant_stores;
CREATE TRIGGER trg_store_auto_sync_flag
  AFTER INSERT OR UPDATE OF profile_id ON public.restaurant_stores
  FOR EACH ROW EXECUTE FUNCTION public.trg_disable_auto_sync_on_store_link();

-- 3. Set flags for Royal Food immediately
UPDATE public.restaurant_stores
SET auto_sync_disabled = true, pos_enabled = true
WHERE slug = 'royalfood';

UPDATE public.profiles
SET auto_sync_disabled = true
WHERE id = (SELECT profile_id FROM public.restaurant_stores WHERE slug = 'royalfood');

-- 4. Bidirectional Sync: Mirror POS menu items to Allonssy public.posts
CREATE OR REPLACE FUNCTION public.sync_restaurant_item_to_allonssy_post()
RETURNS TRIGGER AS $$
DECLARE
  v_profile_id uuid;
  v_city text;
  v_lat double precision;
  v_lng double precision;
  v_is_unclaimed boolean;
  v_cat_name text;
  v_market_cat text;
BEGIN
  -- On DELETE: Remove corresponding post from Allonssy feed
  IF TG_OP = 'DELETE' THEN
    DELETE FROM public.posts 
    WHERE external_source = 'restaurant_pos' AND external_id = OLD.id::text;
    RETURN OLD;
  END IF;

  -- On INSERT or UPDATE: Lookup store and profile metadata
  SELECT 
    s.profile_id,
    COALESCE(p.city, s.city, 'Évry-Courcouronnes'),
    COALESCE(p.latitude, 48.6219206),
    COALESCE(p.longitude, 2.4404045),
    COALESCE(p.is_unclaimed, true)
  INTO v_profile_id, v_city, v_lat, v_lng, v_is_unclaimed
  FROM public.restaurant_stores s
  LEFT JOIN public.profiles p ON p.id = s.profile_id
  WHERE s.id = NEW.store_id;

  -- Lookup category name
  SELECT name INTO v_cat_name 
  FROM public.restaurant_categories 
  WHERE id = NEW.category_id;

  v_market_cat := CASE 
    WHEN v_cat_name ILIKE '%pizza%' THEN 'pizza'
    WHEN v_cat_name ILIKE '%burger%' THEN 'burger'
    WHEN v_cat_name ILIKE '%tex-mex%' OR v_cat_name ILIKE '%poulet%' THEN 'snack_street_food'
    WHEN v_cat_name ILIKE '%boisson%' THEN 'drink'
    WHEN v_cat_name ILIKE '%dessert%' THEN 'dessert'
    ELSE 'other_food'
  END;

  IF v_profile_id IS NOT NULL THEN
    -- Upsert post for this item
    IF EXISTS (SELECT 1 FROM public.posts WHERE external_source = 'restaurant_pos' AND external_id = NEW.id::text) THEN
      UPDATE public.posts
      SET
        market_title = NEW.name,
        market_price = NEW.price,
        content = COALESCE(NEW.description, NEW.name),
        market_category = v_market_cat,
        item_status = CASE WHEN NEW.is_available THEN 'available' ELSE 'reserved' END,
        location_name = v_city,
        latitude = v_lat,
        longitude = v_lng,
        is_unclaimed = v_is_unclaimed
      WHERE external_source = 'restaurant_pos' AND external_id = NEW.id::text;
    ELSE
      INSERT INTO public.posts (
        id,
        user_id,
        post_type,
        market_category,
        market_title,
        market_price,
        content,
        visibility,
        location_name,
        latitude,
        longitude,
        is_unclaimed,
        item_status,
        external_source,
        external_id,
        created_at
      ) VALUES (
        gen_random_uuid(),
        v_profile_id,
        'food_ad',
        v_market_cat,
        NEW.name,
        NEW.price,
        COALESCE(NEW.description, NEW.name),
        'public',
        v_city,
        v_lat,
        v_lng,
        v_is_unclaimed,
        CASE WHEN NEW.is_available THEN 'available' ELSE 'reserved' END,
        'restaurant_pos',
        NEW.id::text,
        now()
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_sync_item_to_post ON public.restaurant_items;
CREATE TRIGGER trg_sync_item_to_post
  AFTER INSERT OR UPDATE OR DELETE ON public.restaurant_items
  FOR EACH ROW EXECUTE FUNCTION public.sync_restaurant_item_to_allonssy_post();

-- 5. Helper function for Admin / Manual Sync
CREATE OR REPLACE FUNCTION public.sync_all_restaurant_items_to_posts(p_store_id uuid)
RETURNS int AS $$
DECLARE
  r RECORD;
  v_count int := 0;
BEGIN
  FOR r IN (SELECT * FROM public.restaurant_items WHERE store_id = p_store_id) LOOP
    -- Trigger sync by updating touched row
    UPDATE public.restaurant_items SET updated_at = now() WHERE id = r.id;
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Trigger sync for all current Royal Food items
DO $$
DECLARE
  v_store_id uuid;
BEGIN
  SELECT id INTO v_store_id FROM public.restaurant_stores WHERE slug = 'royalfood';
  IF v_store_id IS NOT NULL THEN
    -- Clear previous manual dummy posts
    DELETE FROM public.posts 
    WHERE user_id = (SELECT profile_id FROM public.restaurant_stores WHERE id = v_store_id)
      AND external_source IS NULL;

    -- Mirror each existing item via helper
    PERFORM public.sync_all_restaurant_items_to_posts(v_store_id);
  END IF;
END $$;

-- Reload schema
NOTIFY pgrst, 'reload schema';
