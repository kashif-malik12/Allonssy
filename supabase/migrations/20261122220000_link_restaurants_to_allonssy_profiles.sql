-- Migration: Link Restaurant Stores to Allonssy Profiles & Claimed Menu Protection
-- Date: 2026-11-22

-- 1. Extend restaurant_stores and profiles with bi-directional references
ALTER TABLE public.restaurant_stores
  ADD COLUMN IF NOT EXISTS profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_restaurant_stores_profile_id ON public.restaurant_stores(profile_id);

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS restaurant_store_id uuid REFERENCES public.restaurant_stores(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_profiles_restaurant_store_id ON public.profiles(restaurant_store_id);

-- 2. Insert or link Royal Food profile in auth.users and public.profiles
DO $$
DECLARE
  v_store_id uuid;
  v_user_id uuid := '33333333-0000-4000-8000-000000000051';
BEGIN
  -- Get Royal Food store id
  SELECT id INTO v_store_id FROM public.restaurant_stores WHERE slug = 'royalfood';

  IF v_store_id IS NOT NULL THEN
    -- Insert auth.users placeholder for unclaimed business
    INSERT INTO auth.users (
      id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
      created_at, updated_at, confirmation_token, raw_app_meta_data, raw_user_meta_data
    ) VALUES (
      v_user_id,
      '00000000-0000-0000-0000-000000000000',
      'authenticated',
      'authenticated',
      'royalfood.evry@allonssy.com',
      crypt('TempPass123!#', gen_salt('bf')),
      now(),
      now(),
      now(),
      '',
      '{"provider":"email","providers":["email"]}',
      '{"full_name": "Royal Food"}'
    )
    ON CONFLICT (id) DO UPDATE SET
      email = EXCLUDED.email;

    -- Create or update business profile in public.profiles
    INSERT INTO public.profiles (
      id,
      email,
      business_name,
      full_name,
      account_type,
      profile_type,
      is_restaurant,
      restaurant_type,
      business_type,
      business_subtype,
      bio,
      city,
      zipcode,
      phone,
      website,
      latitude,
      longitude,
      radius_km,
      is_unclaimed,
      restaurant_store_id,
      created_at
    ) VALUES (
      v_user_id,
      'royalfood.evry@allonssy.com',
      'Royal Food',
      'Royal Food',
      'business',
      'business',
      true,
      'pizza',
      'food_dining',
      'pizzeria',
      'Pizzas artisanales au feu de bois, Burgers gourmets, Sandwiches et Tex-Mex à Évry-Courcouronnes.',
      'Évry-Courcouronnes',
      '91000',
      '01 60 77 00 00',
      'https://royalfood.allonssy.com',
      48.6219206,
      2.4404045,
      20,
      true,
      v_store_id,
      now()
    )
    ON CONFLICT (id) DO UPDATE SET
      restaurant_store_id = v_store_id,
      business_name = EXCLUDED.business_name,
      full_name = EXCLUDED.full_name,
      is_restaurant = true,
      restaurant_type = 'pizza',
      business_type = 'food_dining',
      business_subtype = 'pizzeria',
      website = 'https://royalfood.allonssy.com',
      phone = '01 60 77 00 00',
      city = 'Évry-Courcouronnes',
      zipcode = '91000',
      latitude = 48.6219206,
      longitude = 2.4404045;

    -- Link back in restaurant_stores
    UPDATE public.restaurant_stores
    SET profile_id = v_user_id
    WHERE id = v_store_id;

    -- Seed representative food_ad posts in Allonssy feed
    DELETE FROM public.posts WHERE user_id = v_user_id;

    INSERT INTO public.posts (
      id, user_id, content, post_type, market_category, market_title,
      market_price, visibility, latitude, longitude, location_name, is_unclaimed
    ) VALUES
    (
      gen_random_uuid(),
      v_user_id,
      'Sauce tomate San Marzano, Mozzarella fior di latte, olives, origan. Disponible en formats Junior, Sénior et Méga.',
      'food_ad',
      'pizza',
      'Pizza Margherita Artisanale',
      7.00,
      'public',
      48.6219206,
      2.4404045,
      'Évry-Courcouronnes (91000)',
      true
    ),
    (
      gen_random_uuid(),
      v_user_id,
      'Sauce tomate ou crème fraîche, Mozzarella, jambon de dinde, champignons frais de Paris.',
      'food_ad',
      'pizza',
      'Pizza Reine Gourmande',
      8.00,
      'public',
      48.6219206,
      2.4404045,
      'Évry-Courcouronnes (91000)',
      true
    ),
    (
      gen_random_uuid(),
      v_user_id,
      'Pain bun sésame, steak haché 100% pur bœuf, cheddar fondant, cornichons, oignons, sauce burger. Servi seul ou en menu frites + boisson.',
      'food_ad',
      'burger',
      'Royal Cheese Burger',
      5.00,
      'public',
      48.6219206,
      2.4404045,
      'Évry-Courcouronnes (91000)',
      true
    );

  END IF;
END $$;

-- 3. Menu Protection Trigger for Claimed Businesses
-- If a restaurant profile is claimed (is_unclaimed = false or claimed_at IS NOT NULL),
-- protect the menu items and categories from automated resets, seeders, or unauthorized updates.

CREATE OR REPLACE FUNCTION public.guard_claimed_restaurant_menu()
RETURNS TRIGGER AS $$
DECLARE
  v_store_id uuid;
  v_is_unclaimed boolean;
  v_claimed_at timestamptz;
  v_owner_id uuid;
BEGIN
  IF TG_TABLE_NAME = 'restaurant_stores' THEN
    v_store_id := OLD.id;
  ELSIF TG_TABLE_NAME = 'restaurant_categories' THEN
    v_store_id := OLD.store_id;
  ELSIF TG_TABLE_NAME = 'restaurant_items' THEN
    v_store_id := OLD.store_id;
  END IF;

  -- Lookup linked profile claim status
  SELECT p.is_unclaimed, p.claimed_at, p.id
  INTO v_is_unclaimed, v_claimed_at, v_owner_id
  FROM public.restaurant_stores s
  JOIN public.profiles p ON p.id = s.profile_id
  WHERE s.id = v_store_id;

  -- If restaurant is claimed, enforce strict ownership
  IF (v_is_unclaimed = false OR v_claimed_at IS NOT NULL) THEN
    -- Allow service_role (e.g. backend admin tasks)
    IF auth.role() = 'service_role' THEN
      RETURN COALESCE(NEW, OLD);
    END IF;

    -- Block unauthenticated or non-owner updates
    IF auth.uid() IS NULL OR auth.uid() != v_owner_id THEN
      RAISE EXCEPTION 'Ce restaurant a été revendiqué par son propriétaire officiel. Le menu est verrouillé contre les modifications non autorisées.';
    END IF;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach triggers on items, categories, and stores
DROP TRIGGER IF EXISTS trg_guard_claimed_items ON public.restaurant_items;
CREATE TRIGGER trg_guard_claimed_items
  BEFORE UPDATE OR DELETE ON public.restaurant_items
  FOR EACH ROW EXECUTE FUNCTION public.guard_claimed_restaurant_menu();

DROP TRIGGER IF EXISTS trg_guard_claimed_categories ON public.restaurant_categories;
CREATE TRIGGER trg_guard_claimed_categories
  BEFORE UPDATE OR DELETE ON public.restaurant_categories
  FOR EACH ROW EXECUTE FUNCTION public.guard_claimed_restaurant_menu();

DROP TRIGGER IF EXISTS trg_guard_claimed_stores ON public.restaurant_stores;
CREATE TRIGGER trg_guard_claimed_stores
  BEFORE UPDATE OR DELETE ON public.restaurant_stores
  FOR EACH ROW EXECUTE FUNCTION public.guard_claimed_restaurant_menu();

-- 4. Insert Guard Trigger for Claimed Businesses
CREATE OR REPLACE FUNCTION public.guard_claimed_restaurant_insert()
RETURNS TRIGGER AS $$
DECLARE
  v_store_id uuid;
  v_is_unclaimed boolean;
  v_claimed_at timestamptz;
  v_owner_id uuid;
BEGIN
  IF TG_TABLE_NAME = 'restaurant_categories' THEN
    v_store_id := NEW.store_id;
  ELSIF TG_TABLE_NAME = 'restaurant_items' THEN
    v_store_id := NEW.store_id;
  END IF;

  SELECT p.is_unclaimed, p.claimed_at, p.id
  INTO v_is_unclaimed, v_claimed_at, v_owner_id
  FROM public.restaurant_stores s
  JOIN public.profiles p ON p.id = s.profile_id
  WHERE s.id = v_store_id;

  IF (v_is_unclaimed = false OR v_claimed_at IS NOT NULL) THEN
    IF auth.role() = 'service_role' THEN
      RETURN NEW;
    END IF;

    IF auth.uid() IS NULL OR auth.uid() != v_owner_id THEN
      RAISE EXCEPTION 'Ce restaurant a été revendiqué par son propriétaire officiel. L''ajout d''articles est réservé au propriétaire connecté.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_guard_claimed_items_insert ON public.restaurant_items;
CREATE TRIGGER trg_guard_claimed_items_insert
  BEFORE INSERT ON public.restaurant_items
  FOR EACH ROW EXECUTE FUNCTION public.guard_claimed_restaurant_insert();

DROP TRIGGER IF EXISTS trg_guard_claimed_categories_insert ON public.restaurant_categories;
CREATE TRIGGER trg_guard_claimed_categories_insert
  BEFORE INSERT ON public.restaurant_categories
  FOR EACH ROW EXECUTE FUNCTION public.guard_claimed_restaurant_insert();

-- 5. Auto-claim sync trigger on business_claims
CREATE OR REPLACE FUNCTION public.sync_approved_business_claim()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
    UPDATE public.profiles
    SET 
      is_unclaimed = false,
      claimed_at = now()
    WHERE id = NEW.profile_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_sync_approved_claim ON public.business_claims;
CREATE TRIGGER trg_sync_approved_claim
  AFTER UPDATE OF status ON public.business_claims
  FOR EACH ROW EXECUTE FUNCTION public.sync_approved_business_claim();

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
