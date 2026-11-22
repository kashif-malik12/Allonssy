-- Migration: Multi-Tenant Restaurant POS & Digital Menu
-- Date: 2026-11-22
-- Creates multi-tenant tables for restaurants, categories, items, orders, and seeds Royal Food.

-- 1. Create restaurant_stores table
CREATE TABLE IF NOT EXISTS public.restaurant_stores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  name text NOT NULL,
  description text,
  address text,
  city text,
  postal_code text,
  phone text,
  banner_url text,
  logo_url text,
  cashier_pin text NOT NULL DEFAULT '1234',
  currency text NOT NULL DEFAULT 'EUR',
  is_active boolean NOT NULL DEFAULT true,
  accepting_orders boolean NOT NULL DEFAULT true,
  estimated_pickup_minutes int NOT NULL DEFAULT 20,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_restaurant_stores_slug ON public.restaurant_stores(slug);

-- 2. Create restaurant_categories table
CREATE TABLE IF NOT EXISTS public.restaurant_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.restaurant_stores(id) ON DELETE CASCADE,
  name text NOT NULL,
  icon text,
  sort_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_restaurant_categories_store ON public.restaurant_categories(store_id, sort_order);

-- 3. Create restaurant_items table
CREATE TABLE IF NOT EXISTS public.restaurant_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.restaurant_stores(id) ON DELETE CASCADE,
  category_id uuid NOT NULL REFERENCES public.restaurant_categories(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  image_url text,
  price numeric(10,2) NOT NULL DEFAULT 0.00,
  sizes jsonb DEFAULT '[]'::jsonb,
  base_sauces jsonb DEFAULT '[]'::jsonb,
  extras jsonb DEFAULT '[]'::jsonb,
  is_available boolean NOT NULL DEFAULT true,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_restaurant_items_category ON public.restaurant_items(category_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_restaurant_items_store ON public.restaurant_items(store_id);

-- 4. Create sequence and restaurant_orders table
CREATE SEQUENCE IF NOT EXISTS public.restaurant_order_num_seq START 101;

CREATE TABLE IF NOT EXISTS public.restaurant_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.restaurant_stores(id) ON DELETE CASCADE,
  order_number int NOT NULL DEFAULT nextval('public.restaurant_order_num_seq'),
  order_type text NOT NULL DEFAULT 'takeaway' CHECK (order_type IN ('takeaway', 'counter', 'dine_in')),
  customer_name text,
  customer_phone text,
  status text NOT NULL DEFAULT 'received' CHECK (status IN ('received', 'preparing', 'ready', 'completed', 'cancelled')),
  payment_method text NOT NULL DEFAULT 'at_pickup' CHECK (payment_method IN ('cash', 'card', 'at_pickup', 'online')),
  payment_status text NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid')),
  pickup_time text,
  total_price numeric(10,2) NOT NULL DEFAULT 0.00,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_restaurant_orders_store ON public.restaurant_orders(store_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_restaurant_orders_status ON public.restaurant_orders(status);

-- 5. Create restaurant_order_items table
CREATE TABLE IF NOT EXISTS public.restaurant_order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.restaurant_orders(id) ON DELETE CASCADE,
  item_name text NOT NULL,
  selected_size text,
  selected_sauce text,
  selected_extras jsonb DEFAULT '[]'::jsonb,
  quantity int NOT NULL DEFAULT 1,
  unit_price numeric(10,2) NOT NULL DEFAULT 0.00,
  total_price numeric(10,2) NOT NULL DEFAULT 0.00,
  notes text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_restaurant_order_items_order ON public.restaurant_order_items(order_id);

-- 6. Enable Row Level Security (RLS) & Grants
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated;

ALTER TABLE public.restaurant_stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurant_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurant_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurant_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurant_order_items ENABLE ROW LEVEL SECURITY;

-- Public read policies (anyone can view active stores, categories, and items)
DROP POLICY IF EXISTS "Public can view active stores" ON public.restaurant_stores;
CREATE POLICY "Public can view active stores" ON public.restaurant_stores
  FOR SELECT USING (is_active = true);

DROP POLICY IF EXISTS "Public can view active categories" ON public.restaurant_categories;
CREATE POLICY "Public can view active categories" ON public.restaurant_categories
  FOR SELECT USING (is_active = true);

DROP POLICY IF EXISTS "Public can view available items" ON public.restaurant_items;
CREATE POLICY "Public can view available items" ON public.restaurant_items
  FOR SELECT USING (is_available = true);

-- Orders: Public can place orders, stores can read & manage orders
DROP POLICY IF EXISTS "Anyone can create order" ON public.restaurant_orders;
CREATE POLICY "Anyone can create order" ON public.restaurant_orders
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Anyone can create order items" ON public.restaurant_order_items;
CREATE POLICY "Anyone can create order items" ON public.restaurant_order_items
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Public can view orders" ON public.restaurant_orders;
CREATE POLICY "Public can view orders" ON public.restaurant_orders
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public can update orders" ON public.restaurant_orders;
CREATE POLICY "Public can update orders" ON public.restaurant_orders
  FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Public can view order items" ON public.restaurant_order_items;
CREATE POLICY "Public can view order items" ON public.restaurant_order_items
  FOR SELECT USING (true);

-- 7. Add restaurant_orders to Realtime publication
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'restaurant_orders'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.restaurant_orders;
  END IF;
END $$;

-- 8. Seed Royal Food
DO $$
DECLARE
  v_store_id uuid;
  v_cat_pizzas uuid;
  v_cat_burgers uuid;
  v_cat_texmex uuid;
  v_cat_drinks uuid;
  v_cat_desserts uuid;
BEGIN
  -- Insert or get store
  INSERT INTO public.restaurant_stores (
    slug, name, description, address, city, postal_code, phone, cashier_pin, accepting_orders, estimated_pickup_minutes
  ) VALUES (
    'royalfood',
    'Royal Food',
    'Pizzas artisanales au feu de bois, Burgers gourmets, Sandwiches et Tex-Mex à Évry-Courcouronnes.',
    '23 Place de la Commune',
    'Évry-Courcouronnes',
    '91000',
    '01 60 77 00 00',
    '1234',
    true,
    20
  )
  ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    address = EXCLUDED.address,
    city = EXCLUDED.city,
    postal_code = EXCLUDED.postal_code
  RETURNING id INTO v_store_id;

  -- Remove old categories for clean seeding if updating
  DELETE FROM public.restaurant_categories WHERE store_id = v_store_id;

  -- Insert Categories
  INSERT INTO public.restaurant_categories (store_id, name, icon, sort_order)
  VALUES (v_store_id, 'Pizzas', 'pizza', 1) RETURNING id INTO v_cat_pizzas;

  INSERT INTO public.restaurant_categories (store_id, name, icon, sort_order)
  VALUES (v_store_id, 'Burgers & Sandwiches', 'burger', 2) RETURNING id INTO v_cat_burgers;

  INSERT INTO public.restaurant_categories (store_id, name, icon, sort_order)
  VALUES (v_store_id, 'Tex-Mex', 'drumstick', 3) RETURNING id INTO v_cat_texmex;

  INSERT INTO public.restaurant_categories (store_id, name, icon, sort_order)
  VALUES (v_store_id, 'Boissons', 'drink', 4) RETURNING id INTO v_cat_drinks;

  INSERT INTO public.restaurant_categories (store_id, name, icon, sort_order)
  VALUES (v_store_id, 'Desserts', 'cake', 5) RETURNING id INTO v_cat_desserts;

  -- Items: Pizzas (With Sizes & Base options)
  INSERT INTO public.restaurant_items (
    store_id, category_id, name, description, price, sizes, base_sauces, extras, sort_order
  ) VALUES
  (
    v_store_id, v_cat_pizzas, 'Pizza Margherita',
    'Sauce tomate, Mozzarella fior di latte, olives, origan.',
    7.00,
    '[{"name": "Junior", "price": 7.00}, {"name": "Sénior", "price": 10.00}, {"name": "Méga", "price": 15.00}]'::jsonb,
    '["Sauce Tomate", "Crème Fraîche"]'::jsonb,
    '[{"name": "Extra Fromage", "price": 1.50}, {"name": "Olives", "price": 0.50}]'::jsonb,
    1
  ),
  (
    v_store_id, v_cat_pizzas, 'Pizza Reine',
    'Sauce tomate, Mozzarella, jambon de dinde, champignons frais.',
    8.00,
    '[{"name": "Junior", "price": 8.00}, {"name": "Sénior", "price": 11.00}, {"name": "Méga", "price": 16.00}]'::jsonb,
    '["Sauce Tomate", "Crème Fraîche"]'::jsonb,
    '[{"name": "Extra Fromage", "price": 1.50}, {"name": "Oeuf", "price": 1.00}]'::jsonb,
    2
  ),
  (
    v_store_id, v_cat_pizzas, 'Pizza 4 Fromages',
    'Sauce tomate ou crème fraîche, Mozzarella, chèvre, emmental, gorgonzola.',
    8.50,
    '[{"name": "Junior", "price": 8.50}, {"name": "Sénior", "price": 12.00}, {"name": "Méga", "price": 17.00}]'::jsonb,
    '["Sauce Tomate", "Crème Fraîche"]'::jsonb,
    '[{"name": "Extra Fromage", "price": 1.50}, {"name": "Miel", "price": 1.00}]'::jsonb,
    3
  ),
  (
    v_store_id, v_cat_pizzas, 'Pizza Orientale',
    'Sauce tomate, Mozzarella, merguez épicée, poivrons frais, oeuf.',
    8.50,
    '[{"name": "Junior", "price": 8.50}, {"name": "Sénior", "price": 12.00}, {"name": "Méga", "price": 17.00}]'::jsonb,
    '["Sauce Tomate", "Crème Fraîche"]'::jsonb,
    '[{"name": "Extra Fromage", "price": 1.50}, {"name": "Piment", "price": 0.50}]'::jsonb,
    4
  ),
  (
    v_store_id, v_cat_pizzas, 'Pizza Barbecue',
    'Sauce tomate, Mozzarella, émincé de poulet, oignons rouges, sauce barbecue fumée.',
    8.50,
    '[{"name": "Junior", "price": 8.50}, {"name": "Sénior", "price": 12.00}, {"name": "Méga", "price": 17.00}]'::jsonb,
    '["Sauce Tomate", "Crème Fraîche"]'::jsonb,
    '[{"name": "Extra Fromage", "price": 1.50}, {"name": "Bacon de dinde", "price": 1.50}]'::jsonb,
    5
  ),
  (
    v_store_id, v_cat_pizzas, 'Pizza Chèvre Miel',
    'Crème fraîche épaisse, Mozzarella, fromage de chèvre onctueux, miel doux.',
    8.50,
    '[{"name": "Junior", "price": 8.50}, {"name": "Sénior", "price": 12.00}, {"name": "Méga", "price": 17.00}]'::jsonb,
    '["Crème Fraîche", "Sauce Tomate"]'::jsonb,
    '[{"name": "Noix", "price": 1.00}, {"name": "Extra Chèvre", "price": 1.50}]'::jsonb,
    6
  );

  -- Items: Burgers & Sandwiches
  INSERT INTO public.restaurant_items (
    store_id, category_id, name, description, price, sizes, base_sauces, extras, sort_order
  ) VALUES
  (
    v_store_id, v_cat_burgers, 'Royal Cheese Burger',
    'Pain bun sésame, steak haché 100% pur bœuf, cheddar fondant, cornichons, oignons, sauce burger.',
    5.00,
    '[{"name": "Seul", "price": 5.00}, {"name": "Menu (Frites + Boisson 33cl)", "price": 7.50}]'::jsonb,
    '[]'::jsonb,
    '[{"name": "Double Steak", "price": 2.00}, {"name": "Bacon de dinde", "price": 1.00}]'::jsonb,
    1
  ),
  (
    v_store_id, v_cat_burgers, 'Double Bacon Burger',
    '2x steak haché façon bouchère, double cheddar, bacon de dinde grillé, sauce barbecue.',
    6.50,
    '[{"name": "Seul", "price": 6.50}, {"name": "Menu (Frites + Boisson 33cl)", "price": 9.00}]'::jsonb,
    '[]'::jsonb,
    '[{"name": "Extra Fromage", "price": 1.00}]'::jsonb,
    2
  ),
  (
    v_store_id, v_cat_burgers, 'Chicken Crispy Burger',
    'Filet de poulet croustillant mariné, salade iceberg, tomates fraîches, sauce mayonnaise poivrée.',
    5.50,
    '[{"name": "Seul", "price": 5.50}, {"name": "Menu (Frites + Boisson 33cl)", "price": 8.00}]'::jsonb,
    '[]'::jsonb,
    '[{"name": "Tranche de Cheddar", "price": 0.80}]'::jsonb,
    3
  ),
  (
    v_store_id, v_cat_burgers, 'Sandwich Kebab Royal',
    'Pain pita artisanal ou galette, lamelles de kebab grillé, salade, tomate, oignons, sauce au choix.',
    6.50,
    '[{"name": "Seul", "price": 6.50}, {"name": "Menu (Frites + Boisson 33cl)", "price": 8.50}]'::jsonb,
    '["Sauce Blanche", "Sauce Samouraï", "Sauce Algérienne", "Sauce Mayonnaise", "Sauce Ketchup"]'::jsonb,
    '[{"name": "Supplément Fromage", "price": 1.00}]'::jsonb,
    4
  );

  -- Items: Tex-Mex
  INSERT INTO public.restaurant_items (
    store_id, category_id, name, description, price, sizes, base_sauces, extras, sort_order
  ) VALUES
  (
    v_store_id, v_cat_texmex, 'Nuggets Croustillants',
    'Bouchées de poulet croustillantes et dorées avec sauce au choix.',
    5.00,
    '[{"name": "x6 Pièces", "price": 5.00}, {"name": "x9 Pièces", "price": 7.00}]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    1
  ),
  (
    v_store_id, v_cat_texmex, 'Chicken Wings Épicés',
    'Ailerons de poulet marinés aux épices tex-mex et cuits au four.',
    6.00,
    '[{"name": "x6 Pièces", "price": 6.00}, {"name": "x10 Pièces", "price": 9.50}]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    2
  ),
  (
    v_store_id, v_cat_texmex, 'Tenders Maison',
    'Aiguillettes de poulet pannées maison ultra croustillantes.',
    6.50,
    '[{"name": "x4 Pièces", "price": 6.50}, {"name": "x8 Pièces", "price": 11.50}]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    3
  );

  -- Items: Boissons
  INSERT INTO public.restaurant_items (
    store_id, category_id, name, description, price, sizes, base_sauces, extras, sort_order
  ) VALUES
  (v_store_id, v_cat_drinks, 'Coca-Cola 33cl', 'Canette fraîche 33cl.', 1.50, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, 1),
  (v_store_id, v_cat_drinks, 'Coca-Cola Zéro 33cl', 'Sans sucres, canette 33cl.', 1.50, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, 2),
  (v_store_id, v_cat_drinks, 'Oasis Tropical 33cl', 'Boisson rafraîchissante aux fruits.', 1.50, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, 3),
  (v_store_id, v_cat_drinks, '7Up Mojito 33cl', 'Saveur menthe citron vert.', 1.50, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, 4),
  (v_store_id, v_cat_drinks, 'Schweppes Agrumes 33cl', 'Saveurs agrumes pétillantes.', 1.50, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, 5),
  (v_store_id, v_cat_drinks, 'Eau Minérale Cristaline 50cl', 'Bouteille fraîche 50cl.', 1.00, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, 6),
  (v_store_id, v_cat_drinks, 'Coca-Cola 1.5L', 'Grande bouteille à partager.', 3.50, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, 7);

  -- Items: Desserts
  INSERT INTO public.restaurant_items (
    store_id, category_id, name, description, price, sizes, base_sauces, extras, sort_order
  ) VALUES
  (v_store_id, v_cat_desserts, 'Tiramisu Spéculoos', 'Crème mascarpone onctueuse et biscuits spéculoos.', 3.00, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, 1),
  (v_store_id, v_cat_desserts, 'Tarte au Daim', 'Gâteau croquant aux éclats de caramel Daim.', 3.00, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, 2),
  (v_store_id, v_cat_desserts, 'Muffin Cœur Fondant Chocolat', 'Muffin moelleux avec cœur coulant au chocolat.', 2.50, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, 3);

END $$;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
