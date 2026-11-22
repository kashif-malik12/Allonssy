-- Migration: French POS Legal Compliance (Article 286, I-3° bis du Code Général des Impôts)
-- Date: 2026-11-22
-- Implements the 4 mandatory legal pillars:
-- 1. Inaltérabilité (Unalterability / No hard deletes / Sealed tickets)
-- 2. Sécurisation (Cryptographic SHA-256 Chaining)
-- 3. Conservation (Daily Z-Reports & Perpetual Non-Resettable Grand Totals)
-- 4. Archivage (Exportable Audit Trail)

-- 1. Extend restaurant_orders with VAT breakdown and cryptographic chaining
ALTER TABLE public.restaurant_orders
  ADD COLUMN IF NOT EXISTS total_ht numeric(10,2) NOT NULL DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS tva_10 numeric(10,2) NOT NULL DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS tva_5_5 numeric(10,2) NOT NULL DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS tva_20 numeric(10,2) NOT NULL DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS signature_hash text,
  ADD COLUMN IF NOT EXISTS previous_signature_hash text,
  ADD COLUMN IF NOT EXISTS is_refund boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS refund_of_order_id uuid REFERENCES public.restaurant_orders(id),
  ADD COLUMN IF NOT EXISTS is_closed_in_z boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_orders_signature_hash ON public.restaurant_orders(signature_hash);
CREATE INDEX IF NOT EXISTS idx_orders_z_closed ON public.restaurant_orders(store_id, is_closed_in_z);

-- Backfill HT and 10% VAT for existing orders
UPDATE public.restaurant_orders
SET 
  total_ht = ROUND(total_price / 1.10, 2),
  tva_10 = total_price - ROUND(total_price / 1.10, 2)
WHERE total_ht = 0.00 AND total_price > 0;

-- 2. Cryptographic Chaining Trigger
CREATE OR REPLACE FUNCTION public.trg_seal_order_on_completion()
RETURNS TRIGGER AS $$
DECLARE
  v_prev_hash text;
  v_raw text;
BEGIN
  -- Only seal when completed/paid and not yet signed
  IF (NEW.status = 'completed' OR NEW.payment_status = 'paid') AND (NEW.signature_hash IS NULL OR NEW.signature_hash = '') THEN
    -- Ensure HT and VAT are populated (default 10% catering VAT if not provided)
    IF NEW.total_ht = 0.00 AND NEW.total_price > 0 THEN
      NEW.total_ht := ROUND(NEW.total_price / 1.10, 2);
      NEW.tva_10 := NEW.total_price - NEW.total_ht;
    END IF;

    -- Fetch previous signature_hash for this store
    SELECT signature_hash INTO v_prev_hash
    FROM public.restaurant_orders
    WHERE store_id = NEW.store_id 
      AND id <> NEW.id 
      AND signature_hash IS NOT NULL
    ORDER BY created_at DESC, id DESC
    LIMIT 1;

    NEW.previous_signature_hash := COALESCE(v_prev_hash, 'GENESIS_STORE_' || NEW.store_id);

    -- Format raw string for SHA-256 seal
    v_raw := NEW.previous_signature_hash || '|' || 
             NEW.store_id || '|' || 
             NEW.order_number || '|' || 
             NEW.total_price || '|' || 
             NEW.total_ht || '|' || 
             COALESCE(NEW.payment_method, 'unknown') || '|' || 
             TO_CHAR(NEW.created_at, 'YYYY-MM-DD"T"HH24:MI:SS.USOF');

    NEW.signature_hash := encode(digest(v_raw, 'sha256'), 'hex');
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_seal_order_trigger ON public.restaurant_orders;
CREATE TRIGGER trg_seal_order_trigger
  BEFORE INSERT OR UPDATE ON public.restaurant_orders
  FOR EACH ROW EXECUTE FUNCTION public.trg_seal_order_on_completion();

-- Seal any existing completed orders without signature
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT id FROM public.restaurant_orders 
    WHERE (status = 'completed' OR payment_status = 'paid') 
      AND (signature_hash IS NULL OR signature_hash = '') 
    ORDER BY created_at ASC
  ) LOOP
    UPDATE public.restaurant_orders SET status = status WHERE id = r.id;
  END LOOP;
END $$;

-- 3. Inalterability Guard Trigger (Strict French Law Enforcement)
CREATE OR REPLACE FUNCTION public.guard_paid_order_inalterability()
RETURNS TRIGGER AS $$
BEGIN
  -- Strict prohibition of DELETE on paid orders
  IF TG_OP = 'DELETE' THEN
    IF OLD.payment_status = 'paid' OR OLD.status = 'completed' OR OLD.signature_hash IS NOT NULL THEN
      RAISE EXCEPTION 'Loi anti-fraude (Art. 286 I-3° bis CGI): Suppression d''un ticket encaissé strictement interdite. Veuillez émettre un avoir ou remboursement.';
    END IF;
    RETURN OLD;
  END IF;

  -- Strict prohibition of altering paid tickets
  IF TG_OP = 'UPDATE' THEN
    IF OLD.signature_hash IS NOT NULL THEN
      -- If attempting to tamper with financial or identification fields
      IF OLD.total_price <> NEW.total_price OR
         OLD.total_ht <> NEW.total_ht OR
         OLD.tva_10 <> NEW.tva_10 OR
         OLD.tva_5_5 <> NEW.tva_5_5 OR
         OLD.payment_status <> NEW.payment_status OR
         OLD.payment_method <> NEW.payment_method OR
         OLD.signature_hash <> NEW.signature_hash OR
         OLD.order_number <> NEW.order_number OR
         OLD.store_id <> NEW.store_id THEN
        RAISE EXCEPTION 'Loi anti-fraude (Art. 286 I-3° bis CGI): Altération directe d''un ticket scellé strictement interdite.';
      END IF;
    END IF;
    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_guard_order_inalterability ON public.restaurant_orders;
CREATE TRIGGER trg_guard_order_inalterability
  BEFORE UPDATE OR DELETE ON public.restaurant_orders
  FOR EACH ROW EXECUTE FUNCTION public.guard_paid_order_inalterability();

-- 4. Create restaurant_pos_z_reports table (Daily Z-Reports)
CREATE TABLE IF NOT EXISTS public.restaurant_pos_z_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.restaurant_stores(id) ON DELETE CASCADE,
  z_number int NOT NULL,
  period_start timestamptz NOT NULL,
  period_end timestamptz NOT NULL,
  order_count int NOT NULL DEFAULT 0,
  total_ttc numeric(10,2) NOT NULL DEFAULT 0.00,
  total_ht numeric(10,2) NOT NULL DEFAULT 0.00,
  total_tva_10 numeric(10,2) NOT NULL DEFAULT 0.00,
  total_tva_5_5 numeric(10,2) NOT NULL DEFAULT 0.00,
  total_tva_20 numeric(10,2) NOT NULL DEFAULT 0.00,
  total_cash numeric(10,2) NOT NULL DEFAULT 0.00,
  total_card numeric(10,2) NOT NULL DEFAULT 0.00,
  grand_total_perpetuel numeric(12,2) NOT NULL DEFAULT 0.00,
  previous_z_hash text,
  signature_hash text NOT NULL,
  closed_by_staff_id uuid REFERENCES public.restaurant_staff(id),
  closed_by_staff_name text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pos_z_reports_store ON public.restaurant_pos_z_reports(store_id, z_number DESC);

-- Guard Z-reports against deletion or alteration
CREATE OR REPLACE FUNCTION public.guard_z_report_inalterability()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Loi anti-fraude (Art. 286 I-3° bis CGI): Suppression d''un rapport Z de caisse strictement interdite.';
  END IF;
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'Loi anti-fraude (Art. 286 I-3° bis CGI): Modification d''un rapport Z scellé strictement interdite.';
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_guard_z_report_inalterability ON public.restaurant_pos_z_reports;
CREATE TRIGGER trg_guard_z_report_inalterability
  BEFORE UPDATE OR DELETE ON public.restaurant_pos_z_reports
  FOR EACH ROW EXECUTE FUNCTION public.guard_z_report_inalterability();

-- 5. Stored Procedure: Close Daily Z-Report
CREATE OR REPLACE FUNCTION public.close_daily_z_report(
  p_store_id uuid,
  p_staff_id uuid DEFAULT NULL,
  p_staff_name text DEFAULT 'Gérant'
)
RETURNS jsonb AS $$
DECLARE
  v_next_z_num int;
  v_prev_z_hash text;
  v_prev_grand_total numeric(12,2);
  v_cur_grand_total numeric(12,2);
  v_order_count int;
  v_total_ttc numeric(10,2);
  v_total_ht numeric(10,2);
  v_tva_10 numeric(10,2);
  v_tva_5_5 numeric(10,2);
  v_total_cash numeric(10,2);
  v_total_card numeric(10,2);
  v_period_start timestamptz;
  v_period_end timestamptz := now();
  v_raw_sig text;
  v_z_sig text;
  v_new_z_id uuid;
  v_res jsonb;
BEGIN
  -- Get previous Z report metadata
  SELECT 
    COALESCE(MAX(z_number), 0) + 1,
    COALESCE((SELECT signature_hash FROM public.restaurant_pos_z_reports WHERE store_id = p_store_id ORDER BY z_number DESC LIMIT 1), 'GENESIS_Z_' || p_store_id),
    COALESCE((SELECT grand_total_perpetuel FROM public.restaurant_pos_z_reports WHERE store_id = p_store_id ORDER BY z_number DESC LIMIT 1), 0.00),
    COALESCE((SELECT period_end FROM public.restaurant_pos_z_reports WHERE store_id = p_store_id ORDER BY z_number DESC LIMIT 1), now() - interval '24 hours')
  INTO v_next_z_num, v_prev_z_hash, v_prev_grand_total, v_period_start
  FROM public.restaurant_pos_z_reports
  WHERE store_id = p_store_id;

  -- Aggregate unclosed paid orders
  SELECT 
    COUNT(*),
    COALESCE(SUM(total_price), 0.00),
    COALESCE(SUM(total_ht), 0.00),
    COALESCE(SUM(tva_10), 0.00),
    COALESCE(SUM(tva_5_5), 0.00),
    COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN total_price ELSE 0 END), 0.00),
    COALESCE(SUM(CASE WHEN payment_method = 'card' THEN total_price ELSE 0 END), 0.00)
  INTO 
    v_order_count,
    v_total_ttc,
    v_total_ht,
    v_tva_10,
    v_tva_5_5,
    v_total_cash,
    v_total_card
  FROM public.restaurant_orders
  WHERE store_id = p_store_id 
    AND (status = 'completed' OR payment_status = 'paid')
    AND is_closed_in_z = false;

  v_cur_grand_total := v_prev_grand_total + v_total_ttc;

  -- Compute SHA-256 seal for Z report
  v_raw_sig := v_prev_z_hash || '|' || 
               p_store_id || '|' || 
               v_next_z_num || '|' || 
               v_total_ttc || '|' || 
               v_cur_grand_total || '|' || 
               v_order_count || '|' || 
               TO_CHAR(v_period_end, 'YYYY-MM-DD"T"HH24:MI:SS.USOF');

  v_z_sig := encode(digest(v_raw_sig, 'sha256'), 'hex');

  -- Insert the sealed Z-report
  INSERT INTO public.restaurant_pos_z_reports (
    id,
    store_id,
    z_number,
    period_start,
    period_end,
    order_count,
    total_ttc,
    total_ht,
    total_tva_10,
    total_tva_5_5,
    total_cash,
    total_card,
    grand_total_perpetuel,
    previous_z_hash,
    signature_hash,
    closed_by_staff_id,
    closed_by_staff_name,
    created_at
  ) VALUES (
    gen_random_uuid(),
    p_store_id,
    v_next_z_num,
    v_period_start,
    v_period_end,
    v_order_count,
    v_total_ttc,
    v_total_ht,
    v_tva_10,
    v_tva_5_5,
    v_total_cash,
    v_total_card,
    v_cur_grand_total,
    v_prev_z_hash,
    v_z_sig,
    p_staff_id,
    p_staff_name,
    v_period_end
  ) RETURNING id INTO v_new_z_id;

  -- Mark orders as closed in Z
  UPDATE public.restaurant_orders
  SET is_closed_in_z = true
  WHERE store_id = p_store_id 
    AND (status = 'completed' OR payment_status = 'paid')
    AND is_closed_in_z = false;

  SELECT row_to_json(z)::jsonb INTO v_res
  FROM public.restaurant_pos_z_reports z
  WHERE id = v_new_z_id;

  RETURN v_res;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Helper for Fiscal Audit Export (Format DGFiP)
CREATE OR REPLACE FUNCTION public.get_fiscal_audit_data(p_store_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_store jsonb;
  v_z_reports jsonb;
  v_orders jsonb;
BEGIN
  SELECT row_to_json(s)::jsonb INTO v_store 
  FROM public.restaurant_stores s WHERE id = p_store_id;

  SELECT json_agg(row_to_json(z))::jsonb INTO v_z_reports 
  FROM (
    SELECT * FROM public.restaurant_pos_z_reports 
    WHERE store_id = p_store_id 
    ORDER BY z_number ASC
  ) z;

  SELECT json_agg(row_to_json(o))::jsonb INTO v_orders 
  FROM (
    SELECT id, order_number, created_at, status, payment_method, payment_status,
           total_price, total_ht, tva_10, tva_5_5, staff_name, signature_hash, previous_signature_hash
    FROM public.restaurant_orders 
    WHERE store_id = p_store_id AND (status = 'completed' OR payment_status = 'paid')
    ORDER BY created_at ASC
  ) o;

  RETURN json_build_object(
    'system', 'Allonssy POS v1.0',
    'legal_reference', 'Article 286, I-3 bis du Code General des Impots (CGI)',
    'export_date', now(),
    'store', v_store,
    'z_reports', COALESCE(v_z_reports, '[]'::jsonb),
    'orders_ledger', COALESCE(v_orders, '[]'::jsonb)
  )::jsonb;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Notify schema reload
NOTIFY pgrst, 'reload schema';
