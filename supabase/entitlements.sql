-- ============================================================
-- SHIPPING HUB - Freemium entitlements + server-side enforcement
-- Run in the SQL Editor (or apply_migration). Idempotent.
-- ============================================================
-- The client shows friendly upgrade prompts, but the free-plan limits are
-- ENFORCED here so they can't be bypassed by calling PostgREST directly.
--
-- Free plan: at most 3 active (open/closed) shipments. Pro: unlimited.
-- "Pro" = an active, non-expired row in subscriptions (written only by the
-- service-role Stripe webhook — see the subscriptions RLS in schema.sql).

CREATE OR REPLACE FUNCTION public.is_operator_pro(p_operator UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM subscriptions
    WHERE operator_id = p_operator
      AND plan = 'pro'
      AND status = 'active'
      AND (current_period_end IS NULL OR current_period_end > NOW())
  );
$$;

CREATE OR REPLACE FUNCTION public.enforce_free_shipment_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  active_count INT;
BEGIN
  -- Upserts fire this BEFORE INSERT trigger even when they resolve to an
  -- UPDATE of an existing shipment; those aren't new shipments, so skip them.
  IF EXISTS (SELECT 1 FROM shipments WHERE id = NEW.id) THEN
    RETURN NEW;
  END IF;

  IF public.is_operator_pro(NEW.operator_id) THEN
    RETURN NEW;
  END IF;

  SELECT COUNT(*) INTO active_count
  FROM shipments
  WHERE operator_id = NEW.operator_id
    AND status IN ('open', 'closed')
    AND deleted_at IS NULL;

  IF active_count >= 3 THEN
    RAISE EXCEPTION 'FREE_PLAN_SHIPMENT_LIMIT'
      USING errcode = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_free_shipment_limit ON shipments;
CREATE TRIGGER trg_free_shipment_limit
  BEFORE INSERT ON shipments
  FOR EACH ROW EXECUTE FUNCTION public.enforce_free_shipment_limit();
