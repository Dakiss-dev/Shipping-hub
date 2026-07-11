-- ============================================================
-- SHIPPING HUB - v1 -> v2 in-place migration
-- ============================================================
-- Use this ONLY on an EXISTING Shipping Hub database that already has the
-- v1 tables (operators/customers/shipments/packages). For a brand-new empty
-- project, run schema.sql instead — it is simpler and self-contained.
--
-- This script is idempotent and non-destructive: it adds the v2 columns,
-- tables, tombstones, tracking tokens, and hardened RLS WITHOUT dropping any
-- existing data. Safe to re-run. Wrapped in a transaction so a failure rolls
-- back cleanly.
--
-- NOT YET RUN AGAINST A LIVE DB (the second Supabase account isn't reachable
-- from the tooling that generated this). Apply it in that project's SQL
-- Editor and read the NOTICES/WARNINGS it emits.
-- ============================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- v1 cleanup: this view bypassed RLS and exposed every tenant's data to anon.
DROP VIEW IF EXISTS public_package_tracking;

-- ---------- Tombstone columns (soft-delete propagation) ----------
ALTER TABLE customers ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE shipments ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE packages  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- ---------- Tracking token (unguessable capability for public tracking) ----------
ALTER TABLE packages ADD COLUMN IF NOT EXISTS tracking_token UUID DEFAULT uuid_generate_v4();
-- Backfill any pre-existing rows, then lock the column down.
UPDATE packages SET tracking_token = uuid_generate_v4() WHERE tracking_token IS NULL;
ALTER TABLE packages ALTER COLUMN tracking_token SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'packages_tracking_token_unique'
  ) THEN
    ALTER TABLE packages
      ADD CONSTRAINT packages_tracking_token_unique UNIQUE (tracking_token);
  END IF;
END $$;

-- ---------- Per-operator reference uniqueness ----------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'packages_operator_reference_unique'
  ) THEN
    BEGIN
      ALTER TABLE packages
        ADD CONSTRAINT packages_operator_reference_unique
        UNIQUE (operator_id, reference_number);
    EXCEPTION WHEN unique_violation THEN
      RAISE WARNING 'Skipped unique(operator_id, reference_number): duplicate references exist. Resolve duplicates and re-run this block.';
    END;
  END IF;
END $$;

-- ---------- New tables: subscriptions (entitlements) + devices ----------
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

CREATE TABLE IF NOT EXISTS devices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  operator_id UUID NOT NULL REFERENCES operators(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  label TEXT,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (operator_id, device_id)
);

-- ---------- RLS: enable + revoke anon + rebuild policies ----------
ALTER TABLE operators     ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers     ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipments     ENABLE ROW LEVEL SECURITY;
ALTER TABLE packages      ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices       ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON operators, customers, shipments, packages, subscriptions, devices FROM anon;

-- Policies are dropped-then-created so this script is fully re-runnable and
-- the v1 policies (which lacked WITH CHECK / column limits) are replaced.

-- OPERATORS
DROP POLICY IF EXISTS "operators_select_own" ON operators;
CREATE POLICY "operators_select_own" ON operators
  FOR SELECT USING (auth.uid() = id);
DROP POLICY IF EXISTS "operators_insert_own" ON operators;
CREATE POLICY "operators_insert_own" ON operators
  FOR INSERT WITH CHECK (auth.uid() = id);
DROP POLICY IF EXISTS "operators_update_own" ON operators;
CREATE POLICY "operators_update_own" ON operators
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- Column-restrict operator updates: clients may edit profile fields only.
REVOKE UPDATE ON operators FROM authenticated;
GRANT UPDATE (business_name, phone, currency, language, air_pricing, sea_pricing)
  ON operators TO authenticated;

-- CUSTOMERS
DROP POLICY IF EXISTS "customers_select_own" ON customers;
CREATE POLICY "customers_select_own" ON customers
  FOR SELECT USING (auth.uid() = operator_id);
DROP POLICY IF EXISTS "customers_insert_own" ON customers;
CREATE POLICY "customers_insert_own" ON customers
  FOR INSERT WITH CHECK (auth.uid() = operator_id);
DROP POLICY IF EXISTS "customers_update_own" ON customers;
CREATE POLICY "customers_update_own" ON customers
  FOR UPDATE USING (auth.uid() = operator_id) WITH CHECK (auth.uid() = operator_id);
DROP POLICY IF EXISTS "customers_delete_own" ON customers;
CREATE POLICY "customers_delete_own" ON customers
  FOR DELETE USING (auth.uid() = operator_id);

-- SHIPMENTS
DROP POLICY IF EXISTS "shipments_select_own" ON shipments;
CREATE POLICY "shipments_select_own" ON shipments
  FOR SELECT USING (auth.uid() = operator_id);
DROP POLICY IF EXISTS "shipments_insert_own" ON shipments;
CREATE POLICY "shipments_insert_own" ON shipments
  FOR INSERT WITH CHECK (auth.uid() = operator_id);
DROP POLICY IF EXISTS "shipments_update_own" ON shipments;
CREATE POLICY "shipments_update_own" ON shipments
  FOR UPDATE USING (auth.uid() = operator_id) WITH CHECK (auth.uid() = operator_id);
DROP POLICY IF EXISTS "shipments_delete_own" ON shipments;
CREATE POLICY "shipments_delete_own" ON shipments
  FOR DELETE USING (auth.uid() = operator_id);

-- PACKAGES
DROP POLICY IF EXISTS "packages_select_own" ON packages;
CREATE POLICY "packages_select_own" ON packages
  FOR SELECT USING (auth.uid() = operator_id);
DROP POLICY IF EXISTS "packages_insert_own" ON packages;
CREATE POLICY "packages_insert_own" ON packages
  FOR INSERT WITH CHECK (auth.uid() = operator_id);
DROP POLICY IF EXISTS "packages_update_own" ON packages;
CREATE POLICY "packages_update_own" ON packages
  FOR UPDATE USING (auth.uid() = operator_id) WITH CHECK (auth.uid() = operator_id);
DROP POLICY IF EXISTS "packages_delete_own" ON packages;
CREATE POLICY "packages_delete_own" ON packages
  FOR DELETE USING (auth.uid() = operator_id);

-- SUBSCRIPTIONS: read-only for the owner; ALL writes via service role.
DROP POLICY IF EXISTS "subscriptions_select_own" ON subscriptions;
CREATE POLICY "subscriptions_select_own" ON subscriptions
  FOR SELECT USING (auth.uid() = operator_id);
REVOKE INSERT, UPDATE, DELETE ON subscriptions FROM authenticated;

-- DEVICES: owner manages their own device registrations.
DROP POLICY IF EXISTS "devices_select_own" ON devices;
CREATE POLICY "devices_select_own" ON devices
  FOR SELECT USING (auth.uid() = operator_id);
DROP POLICY IF EXISTS "devices_insert_own" ON devices;
CREATE POLICY "devices_insert_own" ON devices
  FOR INSERT WITH CHECK (auth.uid() = operator_id);
DROP POLICY IF EXISTS "devices_update_own" ON devices;
CREATE POLICY "devices_update_own" ON devices
  FOR UPDATE USING (auth.uid() = operator_id) WITH CHECK (auth.uid() = operator_id);
DROP POLICY IF EXISTS "devices_delete_own" ON devices;
CREATE POLICY "devices_delete_own" ON devices
  FOR DELETE USING (auth.uid() = operator_id);

-- ---------- Triggers ----------
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Existing v1 tables already have their updated_at triggers; only the new
-- subscriptions table needs one (guarded so re-runs don't error).
DROP TRIGGER IF EXISTS update_subscriptions_updated_at ON subscriptions;
CREATE TRIGGER update_subscriptions_updated_at
  BEFORE UPDATE ON subscriptions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

COMMIT;
