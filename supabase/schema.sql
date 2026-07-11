-- ============================================================
-- SHIPPING HUB - Supabase Multi-Tenant Schema v2
-- Fresh project: run whole file in SQL Editor (or apply_migration).
-- Upgrading from v1: this file is idempotent-ish via IF NOT EXISTS,
-- and the DROP VIEW below removes v1's insecure tracking view.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- v1 cleanup: this view bypassed RLS and exposed every tenant's data to anon.
DROP VIEW IF EXISTS public_package_tracking;

-- ==================== OPERATORS (profiles) ====================
CREATE TABLE IF NOT EXISTS operators (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  business_name TEXT NOT NULL DEFAULT 'My Shipping Business',
  phone TEXT,
  currency TEXT NOT NULL DEFAULT 'USD',
  language TEXT NOT NULL DEFAULT 'en',
  air_pricing JSONB NOT NULL DEFAULT '{
    "pricePerKg": 8.0,
    "presetItems": {
      "Phone": 25.0,
      "Laptop": 50.0,
      "Tablet": 35.0,
      "Small Electronics": 20.0,
      "Documents/Envelope": 15.0,
      "Shoes (pair)": 15.0,
      "Clothing Bundle": 20.0
    }
  }'::jsonb,
  sea_pricing JSONB NOT NULL DEFAULT '{
    "pricePerKg": 3.0,
    "itemPrices": {
      "smallBarrel": 80.0,
      "largeBarrel": 150.0,
      "car": 1500.0,
      "mattress": 100.0,
      "television": 75.0,
      "furniture": 120.0,
      "electronics": 60.0
    }
  }'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==================== CUSTOMERS ====================
CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  operator_id UUID NOT NULL REFERENCES operators(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  phone_country_code TEXT NOT NULL DEFAULT '+1',
  email TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  local_id TEXT,
  synced_at TIMESTAMPTZ
);

-- ==================== SHIPMENTS ====================
CREATE TABLE IF NOT EXISTS shipments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  operator_id UUID NOT NULL REFERENCES operators(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('air', 'sea')),
  destination TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed', 'inTransit', 'delivered')),
  departure_date TIMESTAMPTZ,
  estimated_arrival TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  local_id TEXT,
  synced_at TIMESTAMPTZ
);

-- ==================== PACKAGES ====================
CREATE TABLE IF NOT EXISTS packages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  operator_id UUID NOT NULL REFERENCES operators(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  shipment_id UUID NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
  reference_number TEXT NOT NULL,
  -- Unguessable capability for the public tracking page. Never exposed
  -- through an anon-readable view; lookups go through the token-gated
  -- SECURITY DEFINER function public.track_package (see supabase/tracking.sql),
  -- which returns only safe status fields. The 122-bit random token makes
  -- guessing infeasible; add endpoint throttling later only if abuse/cost is
  -- a concern.
  tracking_token UUID NOT NULL DEFAULT uuid_generate_v4() UNIQUE,
  shipment_type TEXT NOT NULL CHECK (shipment_type IN ('air', 'sea')),
  photo_url TEXT,
  description TEXT DEFAULT '',
  weight_kg DOUBLE PRECISION,
  sea_item_type TEXT,
  preset_item_name TEXT,
  price DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  payment_status TEXT NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'paid')),
  notes TEXT,
  receiver_name TEXT,
  receiver_phone TEXT,
  receiver_phone_country_code TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  local_id TEXT,
  synced_at TIMESTAMPTZ,
  UNIQUE (operator_id, reference_number)
);

-- ==================== SUBSCRIPTIONS (entitlements) ====================
-- Written ONLY by the service-role Stripe webhook (Plan 3). Clients can
-- read their own row and nothing else — a client-writable plan column
-- would be self-upgradable via raw PostgREST.
CREATE TABLE IF NOT EXISTS subscriptions (
  operator_id UUID PRIMARY KEY REFERENCES operators(id) ON DELETE CASCADE,
  plan TEXT NOT NULL DEFAULT 'free' CHECK (plan IN ('free', 'pro')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'past_due', 'canceled')),
  current_period_end TIMESTAMPTZ,
  stripe_customer_id TEXT,
  stripe_subscription_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==================== DEVICES ====================
-- Free plan: one registered device (transferable). Enforcement trigger
-- ships with Plan 3; the table exists now so the schema is stable.
CREATE TABLE IF NOT EXISTS devices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  operator_id UUID NOT NULL REFERENCES operators(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  label TEXT,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (operator_id, device_id)
);

-- ==================== INDEXES ====================
CREATE INDEX IF NOT EXISTS idx_customers_operator ON customers(operator_id);
CREATE INDEX IF NOT EXISTS idx_shipments_operator ON shipments(operator_id);
CREATE INDEX IF NOT EXISTS idx_packages_operator ON packages(operator_id);
CREATE INDEX IF NOT EXISTS idx_packages_shipment ON packages(shipment_id);
CREATE INDEX IF NOT EXISTS idx_packages_customer ON packages(customer_id);
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(operator_id, phone);

-- ==================== ROW LEVEL SECURITY ====================

ALTER TABLE operators ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;

-- Anon gets nothing, ever. RLS already denies (no anon policies), but
-- revoking the default table grants removes the entire surface.
REVOKE ALL ON operators, customers, shipments, packages, subscriptions, devices FROM anon;

-- OPERATORS
CREATE POLICY "operators_select_own" ON operators
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "operators_insert_own" ON operators
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "operators_update_own" ON operators
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- Column-restrict operator updates: clients may edit profile fields only.
-- (id/email stay immutable from the client; entitlements never live here.)
REVOKE UPDATE ON operators FROM authenticated;
GRANT UPDATE (business_name, phone, currency, language, air_pricing, sea_pricing)
  ON operators TO authenticated;

-- CUSTOMERS
CREATE POLICY "customers_select_own" ON customers
  FOR SELECT USING (auth.uid() = operator_id);

CREATE POLICY "customers_insert_own" ON customers
  FOR INSERT WITH CHECK (auth.uid() = operator_id);

CREATE POLICY "customers_update_own" ON customers
  FOR UPDATE USING (auth.uid() = operator_id) WITH CHECK (auth.uid() = operator_id);

CREATE POLICY "customers_delete_own" ON customers
  FOR DELETE USING (auth.uid() = operator_id);

-- SHIPMENTS
CREATE POLICY "shipments_select_own" ON shipments
  FOR SELECT USING (auth.uid() = operator_id);

CREATE POLICY "shipments_insert_own" ON shipments
  FOR INSERT WITH CHECK (auth.uid() = operator_id);

CREATE POLICY "shipments_update_own" ON shipments
  FOR UPDATE USING (auth.uid() = operator_id) WITH CHECK (auth.uid() = operator_id);

CREATE POLICY "shipments_delete_own" ON shipments
  FOR DELETE USING (auth.uid() = operator_id);

-- PACKAGES
CREATE POLICY "packages_select_own" ON packages
  FOR SELECT USING (auth.uid() = operator_id);

CREATE POLICY "packages_insert_own" ON packages
  FOR INSERT WITH CHECK (auth.uid() = operator_id);

CREATE POLICY "packages_update_own" ON packages
  FOR UPDATE USING (auth.uid() = operator_id) WITH CHECK (auth.uid() = operator_id);

CREATE POLICY "packages_delete_own" ON packages
  FOR DELETE USING (auth.uid() = operator_id);

-- SUBSCRIPTIONS: read-only for the owner; ALL writes via service role.
CREATE POLICY "subscriptions_select_own" ON subscriptions
  FOR SELECT USING (auth.uid() = operator_id);

REVOKE INSERT, UPDATE, DELETE ON subscriptions FROM authenticated;

-- DEVICES: owner manages their own device registrations.
CREATE POLICY "devices_select_own" ON devices
  FOR SELECT USING (auth.uid() = operator_id);

CREATE POLICY "devices_insert_own" ON devices
  FOR INSERT WITH CHECK (auth.uid() = operator_id);

CREATE POLICY "devices_update_own" ON devices
  FOR UPDATE USING (auth.uid() = operator_id) WITH CHECK (auth.uid() = operator_id);

CREATE POLICY "devices_delete_own" ON devices
  FOR DELETE USING (auth.uid() = operator_id);

-- ==================== TRIGGERS ====================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_operators_updated_at
  BEFORE UPDATE ON operators
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_customers_updated_at
  BEFORE UPDATE ON customers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_shipments_updated_at
  BEFORE UPDATE ON shipments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_packages_updated_at
  BEFORE UPDATE ON packages
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_subscriptions_updated_at
  BEFORE UPDATE ON subscriptions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- NOTE: no trigger on auth.users — Supabase hosted projects block them.
-- Operator profiles are created app-side (_ensureOperatorProfile), and a
-- default subscriptions row is created by the Plan 3 entitlement flow.
