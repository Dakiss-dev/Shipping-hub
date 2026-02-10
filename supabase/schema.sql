-- ============================================================
-- SHIPPING HUB - Supabase Multi-Tenant Schema
-- Run this in your Supabase SQL Editor (Dashboard > SQL Editor)
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==================== OPERATORS (profiles) ====================
-- Extends Supabase Auth users with operator-specific data
CREATE TABLE IF NOT EXISTS operators (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  business_name TEXT NOT NULL DEFAULT 'My Shipping Business',
  phone TEXT,
  currency TEXT NOT NULL DEFAULT 'USD',
  language TEXT NOT NULL DEFAULT 'en',
  -- Air pricing config (JSON)
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
  -- Sea pricing config (JSON)
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
  -- Sync tracking
  local_id TEXT, -- Original Hive local ID for migration
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
  shipment_type TEXT NOT NULL CHECK (shipment_type IN ('air', 'sea')),
  photo_url TEXT,
  description TEXT DEFAULT '',
  weight_kg DOUBLE PRECISION,
  sea_item_type TEXT,
  preset_item_name TEXT,
  price DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  payment_status TEXT NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'paid')),
  notes TEXT,
  -- Receiver info
  receiver_name TEXT,
  receiver_phone TEXT,
  receiver_phone_country_code TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  local_id TEXT,
  synced_at TIMESTAMPTZ
);

-- ==================== INDEXES ====================
CREATE INDEX IF NOT EXISTS idx_customers_operator ON customers(operator_id);
CREATE INDEX IF NOT EXISTS idx_shipments_operator ON shipments(operator_id);
CREATE INDEX IF NOT EXISTS idx_packages_operator ON packages(operator_id);
CREATE INDEX IF NOT EXISTS idx_packages_shipment ON packages(shipment_id);
CREATE INDEX IF NOT EXISTS idx_packages_customer ON packages(customer_id);
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(operator_id, phone);

-- ==================== ROW LEVEL SECURITY ====================

-- Enable RLS on all tables
ALTER TABLE operators ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE packages ENABLE ROW LEVEL SECURITY;

-- OPERATORS: Users can only see/edit their own profile
CREATE POLICY "operators_select_own" ON operators
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "operators_insert_own" ON operators
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "operators_update_own" ON operators
  FOR UPDATE USING (auth.uid() = id);

-- CUSTOMERS: Operators can only see/edit their own customers
CREATE POLICY "customers_select_own" ON customers
  FOR SELECT USING (auth.uid() = operator_id);

CREATE POLICY "customers_insert_own" ON customers
  FOR INSERT WITH CHECK (auth.uid() = operator_id);

CREATE POLICY "customers_update_own" ON customers
  FOR UPDATE USING (auth.uid() = operator_id);

CREATE POLICY "customers_delete_own" ON customers
  FOR DELETE USING (auth.uid() = operator_id);

-- SHIPMENTS: Operators can only see/edit their own shipments
CREATE POLICY "shipments_select_own" ON shipments
  FOR SELECT USING (auth.uid() = operator_id);

CREATE POLICY "shipments_insert_own" ON shipments
  FOR INSERT WITH CHECK (auth.uid() = operator_id);

CREATE POLICY "shipments_update_own" ON shipments
  FOR UPDATE USING (auth.uid() = operator_id);

CREATE POLICY "shipments_delete_own" ON shipments
  FOR DELETE USING (auth.uid() = operator_id);

-- PACKAGES: Operators can only see/edit their own packages
CREATE POLICY "packages_select_own" ON packages
  FOR SELECT USING (auth.uid() = operator_id);

CREATE POLICY "packages_insert_own" ON packages
  FOR INSERT WITH CHECK (auth.uid() = operator_id);

CREATE POLICY "packages_update_own" ON packages
  FOR UPDATE USING (auth.uid() = operator_id);

CREATE POLICY "packages_delete_own" ON packages
  FOR DELETE USING (auth.uid() = operator_id);

-- ==================== TRIGGERS ====================

-- Auto-update updated_at timestamp
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

-- ==================== AUTO-CREATE OPERATOR PROFILE ====================
-- When a new user signs up, auto-create their operator profile
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO operators (id, email, business_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'business_name', 'My Shipping Business')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists, then create
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ==================== PUBLIC TRACKING VIEW ====================
-- Allows customers to look up package status by reference number
-- No auth required - this is the customer-facing tracking
CREATE OR REPLACE VIEW public_package_tracking AS
SELECT
  p.reference_number,
  p.shipment_type,
  p.description,
  p.weight_kg,
  p.payment_status,
  p.receiver_name,
  p.created_at AS package_date,
  s.destination,
  s.status AS shipment_status,
  s.departure_date,
  s.estimated_arrival,
  o.business_name AS operator_name
FROM packages p
JOIN shipments s ON p.shipment_id = s.id
JOIN operators o ON p.operator_id = o.id;

-- Grant public read access to tracking view
GRANT SELECT ON public_package_tracking TO anon;
