DO $seed$
DECLARE
  v_store_id uuid;
  v_staff_karim uuid;
  v_staff_sofiane uuid;
  v_staff_patron uuid;
  v_order_id uuid;
BEGIN
  SELECT id INTO v_store_id FROM public.restaurant_stores WHERE slug = 'royalfood';
  SELECT id INTO v_staff_patron FROM public.restaurant_staff WHERE store_id = v_store_id AND name = 'Patron / Gérant';
  SELECT id INTO v_staff_karim FROM public.restaurant_staff WHERE store_id = v_store_id AND name = 'Karim';
  SELECT id INTO v_staff_sofiane FROM public.restaurant_staff WHERE store_id = v_store_id AND name = 'Sofiane';

  -- Today order 1 by Karim (Cash 26.50€)
  INSERT INTO public.restaurant_orders (store_id, customer_name, order_type, pickup_time, status, payment_method, payment_status, total_price, staff_id, staff_name, created_at)
  VALUES (v_store_id, 'Comptoir', 'counter', 'Immédiat', 'completed', 'cash', 'paid', 26.50, v_staff_karim, 'Karim', now() - interval '2 hours')
  RETURNING id INTO v_order_id;
  INSERT INTO public.restaurant_order_items (order_id, item_name, selected_size, quantity, unit_price, total_price)
  VALUES (v_order_id, 'Pizza 4 Fromages', 'Méga', 1, 17.00, 17.00), (v_order_id, 'Coca-Cola 1.5L', 'Standard', 1, 3.50, 3.50), (v_order_id, 'Tiramisu Spéculoos', 'Standard', 2, 3.00, 6.00);

  -- Today order 2 by Sofiane (Card 34.00€)
  INSERT INTO public.restaurant_orders (store_id, customer_name, order_type, pickup_time, status, payment_method, payment_status, total_price, staff_id, staff_name, created_at)
  VALUES (v_store_id, 'Comptoir', 'counter', 'Immédiat', 'completed', 'card', 'paid', 34.00, v_staff_sofiane, 'Sofiane', now() - interval '1 hour')
  RETURNING id INTO v_order_id;
  INSERT INTO public.restaurant_order_items (order_id, item_name, selected_size, quantity, unit_price, total_price)
  VALUES (v_order_id, 'Pizza Reine', 'Sénior', 2, 11.00, 22.00), (v_order_id, 'Chicken Wings Épicés', 'x6 Pièces', 2, 6.00, 12.00);

  -- Today order 3 by Karim (Card 19.50€)
  INSERT INTO public.restaurant_orders (store_id, customer_name, order_type, pickup_time, status, payment_method, payment_status, total_price, staff_id, staff_name, created_at)
  VALUES (v_store_id, 'Comptoir', 'counter', 'Immédiat', 'completed', 'card', 'paid', 19.50, v_staff_karim, 'Karim', now() - interval '30 minutes')
  RETURNING id INTO v_order_id;
  INSERT INTO public.restaurant_order_items (order_id, item_name, selected_size, quantity, unit_price, total_price)
  VALUES (v_order_id, 'Pizza Orientale', 'Sénior', 1, 12.00, 12.00), (v_order_id, 'Double Bacon Burger', 'Menu', 1, 7.50, 7.50);

  -- Yesterday orders
  INSERT INTO public.restaurant_orders (store_id, customer_name, order_type, pickup_time, status, payment_method, payment_status, total_price, staff_id, staff_name, created_at)
  VALUES 
    (v_store_id, 'Comptoir', 'counter', 'Immédiat', 'completed', 'cash', 'paid', 48.00, v_staff_karim, 'Karim', now() - interval '1 day'),
    (v_store_id, 'Comptoir', 'counter', 'Immédiat', 'completed', 'card', 'paid', 52.00, v_staff_sofiane, 'Sofiane', now() - interval '1 day 2 hours'),
    (v_store_id, 'Mehdi B.', 'takeaway', '20h00', 'completed', 'card', 'paid', 20.00, NULL, 'En ligne (Client)', now() - interval '1 day 3 hours');

  -- 2 days ago orders
  INSERT INTO public.restaurant_orders (store_id, customer_name, order_type, pickup_time, status, payment_method, payment_status, total_price, staff_id, staff_name, created_at)
  VALUES 
    (v_store_id, 'Comptoir', 'counter', 'Immédiat', 'completed', 'card', 'paid', 55.00, v_staff_karim, 'Karim', now() - interval '2 days'),
    (v_store_id, 'Comptoir', 'counter', 'Immédiat', 'completed', 'cash', 'paid', 40.00, v_staff_sofiane, 'Sofiane', now() - interval '2 days 1 hour');

  -- 3 days ago orders
  INSERT INTO public.restaurant_orders (store_id, customer_name, order_type, pickup_time, status, payment_method, payment_status, total_price, staff_id, staff_name, created_at)
  VALUES 
    (v_store_id, 'Comptoir', 'counter', 'Immédiat', 'completed', 'cash', 'paid', 65.00, v_staff_patron, 'Patron / Gérant', now() - interval '3 days'),
    (v_store_id, 'Comptoir', 'counter', 'Immédiat', 'completed', 'card', 'paid', 45.00, v_staff_karim, 'Karim', now() - interval '3 days 4 hours');

END $seed$;
