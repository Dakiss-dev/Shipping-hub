-- ============================================================
-- SHIPPING HUB - Public package tracking (safe, token-based)
-- Run in the SQL Editor (or apply_migration). Idempotent.
-- ============================================================
-- Replaces the v1 anon-readable view (dropped in schema v2) with a
-- SECURITY DEFINER function that returns ONLY safe, customer-facing fields for
-- a single package identified by its unguessable tracking_token. No payment
-- status, no receiver PII, no phone numbers, and no way to enumerate — the
-- caller must already hold the exact UUID token (from their receipt link).
--
-- photo_url is intentionally NOT returned: a package photo can capture a
-- shipping label bearing the receiver's name/address, which would leak the
-- very PII this function withholds. Photos stay operator-only.

-- DROP first: the return-column set changed (photo_url removed), which
-- CREATE OR REPLACE cannot do in place.
DROP FUNCTION IF EXISTS public.track_package(UUID);

CREATE OR REPLACE FUNCTION public.track_package(p_token UUID)
RETURNS TABLE (
  reference_number TEXT,
  shipment_type TEXT,
  status TEXT,
  destination TEXT,
  departure_date TIMESTAMPTZ,
  estimated_arrival TIMESTAMPTZ,
  operator_name TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    p.reference_number,
    p.shipment_type,
    s.status,
    s.destination,
    s.departure_date,
    s.estimated_arrival,
    o.business_name AS operator_name,
    p.created_at
  FROM packages p
  JOIN shipments s ON s.id = p.shipment_id
  JOIN operators o ON o.id = p.operator_id
  WHERE p.tracking_token = p_token
    AND p.deleted_at IS NULL
    AND s.deleted_at IS NULL;
$$;

-- Lock down: only allow calling with an explicit token, from anon/authenticated.
REVOKE ALL ON FUNCTION public.track_package(UUID) FROM public;
GRANT EXECUTE ON FUNCTION public.track_package(UUID) TO anon, authenticated;
