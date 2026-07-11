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

-- Fires on INSERT and UPDATE. Guards any operation that RESULTS in a new
-- active shipment for a free operator — a fresh insert OR reopening a
-- delivered/in-transit shipment back to open/closed (the app has a Reopen
-- action, which would otherwise slip past an insert-only trigger).
CREATE OR REPLACE FUNCTION public.enforce_free_shipment_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  active_count INT;
BEGIN
  -- Only guard rows that will be active (open/closed) and not deleted.
  IF NEW.deleted_at IS NOT NULL
     OR NEW.status NOT IN ('open', 'closed') THEN
    RETURN NEW;
  END IF;

  -- A real UPDATE of a row that was ALREADY active isn't adding capacity
  -- (e.g. open<->closed, a rename); allow it. (Upserts arrive as INSERT and
  -- are handled by the count-of-others below.)
  IF TG_OP = 'UPDATE'
     AND OLD.status IN ('open', 'closed')
     AND OLD.deleted_at IS NULL THEN
    RETURN NEW;
  END IF;

  IF public.is_operator_pro(NEW.operator_id) THEN
    RETURN NEW;
  END IF;

  -- Count the operator's OTHER active shipments (exclude this row so an
  -- upsert/edit of an existing active shipment is never miscounted).
  SELECT COUNT(*) INTO active_count
  FROM shipments
  WHERE operator_id = NEW.operator_id
    AND id <> NEW.id
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
  BEFORE INSERT OR UPDATE ON shipments
  FOR EACH ROW EXECUTE FUNCTION public.enforce_free_shipment_limit();
