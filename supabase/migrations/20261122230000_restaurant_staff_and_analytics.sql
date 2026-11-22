-- Migration: Restaurant Staff Sub-Accounts & Sales Analytics
-- Date: 2026-11-22

-- 1. Create restaurant_staff table for cashier sub-accounts
CREATE TABLE IF NOT EXISTS public.restaurant_staff (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.restaurant_stores(id) ON DELETE CASCADE,
  name text NOT NULL,
  role text NOT NULL DEFAULT 'cashier' CHECK (role IN ('owner', 'manager', 'cashier')),
  pin text NOT NULL DEFAULT '1234',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_restaurant_staff_store ON public.restaurant_staff(store_id);

-- 2. Extend restaurant_orders with staff attribution
ALTER TABLE public.restaurant_orders
  ADD COLUMN IF NOT EXISTS staff_id uuid REFERENCES public.restaurant_staff(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS staff_name text DEFAULT 'En ligne (Client)';

CREATE INDEX IF NOT EXISTS idx_restaurant_orders_staff ON public.restaurant_orders(staff_id);

-- 3. RLS and Grants
ALTER TABLE public.restaurant_staff ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view staff" ON public.restaurant_staff;
CREATE POLICY "Public can view staff" ON public.restaurant_staff
  FOR SELECT USING (is_active = true);

DROP POLICY IF EXISTS "Public can manage staff" ON public.restaurant_staff;
CREATE POLICY "Public can manage staff" ON public.restaurant_staff
  FOR ALL USING (true) WITH CHECK (true);

-- 4. Seed default staff for Royal Food
DO $$
DECLARE
  v_store_id uuid;
  v_owner_id uuid;
  v_staff1_id uuid;
  v_staff2_id uuid;
BEGIN
  SELECT id INTO v_store_id FROM public.restaurant_stores WHERE slug = 'royalfood';

  IF v_store_id IS NOT NULL THEN
    -- Check if staff already exists
    IF NOT EXISTS (SELECT 1 FROM public.restaurant_staff WHERE store_id = v_store_id) THEN
      -- Main Owner Account (PIN: 1234)
      INSERT INTO public.restaurant_staff (store_id, name, role, pin)
      VALUES (v_store_id, 'Patron / Gérant', 'owner', '1234')
      RETURNING id INTO v_owner_id;

      -- Cashier 1 (PIN: 1111)
      INSERT INTO public.restaurant_staff (store_id, name, role, pin)
      VALUES (v_store_id, 'Karim', 'cashier', '1111')
      RETURNING id INTO v_staff1_id;

      -- Cashier 2 (PIN: 2222)
      INSERT INTO public.restaurant_staff (store_id, name, role, pin)
      VALUES (v_store_id, 'Sofiane', 'cashier', '2222')
      RETURNING id INTO v_staff2_id;

      -- Update existing orders attribution
      UPDATE public.restaurant_orders
      SET staff_id = v_staff1_id, staff_name = 'Karim'
      WHERE store_id = v_store_id AND order_type = 'counter';

      UPDATE public.restaurant_orders
      SET staff_name = 'En ligne (Client)'
      WHERE store_id = v_store_id AND order_type = 'takeaway';
    END IF;
  END IF;
END $$;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
