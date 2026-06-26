-- ============================================================
-- Run this in the Supabase SQL editor (Dashboard → SQL Editor)
-- Creates the tenants table linked to leasing_units
-- ============================================================

CREATE TABLE IF NOT EXISTS tenants (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name             TEXT NOT NULL,
  last_name              TEXT NOT NULL,
  email                  TEXT,
  phone                  TEXT,
  status                 TEXT NOT NULL DEFAULT 'active'
                           CHECK (status IN ('active', 'inactive', 'pending')),
  leasing_unit_id        TEXT REFERENCES leasing_units(id) ON DELETE SET NULL,
  auth_user_id           UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  move_in_date           DATE,
  emergency_contact_name  TEXT,
  emergency_contact_phone TEXT,
  notes                  TEXT,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast lookups by unit
CREATE INDEX IF NOT EXISTS tenants_leasing_unit_id_idx ON tenants (leasing_unit_id);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tenants_updated_at ON tenants;
CREATE TRIGGER tenants_updated_at
  BEFORE UPDATE ON tenants
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Enable RLS (backend uses service-role key so bypasses it automatically)
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Phase 2: Add tenant-specific lease detail columns
-- Run this block if the table already exists
-- ============================================================

ALTER TABLE tenants ADD COLUMN IF NOT EXISTS business_type TEXT;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS floor         TEXT;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS area_entries  JSONB NOT NULL DEFAULT '[]'::jsonb;

-- ============================================================
-- Phase 3: Add company_name (owner name) to leasing_units
-- Run this if the leasing_units table already exists
-- ============================================================

ALTER TABLE leasing_units ADD COLUMN IF NOT EXISTS company_name TEXT;

-- ============================================================
-- Phase 4: Fix leasing_unit_id column type in tenants
-- Run this if the tenants table already exists with UUID type
-- ============================================================

-- Drop the old FK constraint and column, recreate as TEXT
ALTER TABLE tenants DROP CONSTRAINT IF EXISTS tenants_leasing_unit_id_fkey;
ALTER TABLE tenants ALTER COLUMN leasing_unit_id TYPE TEXT USING leasing_unit_id::TEXT;
ALTER TABLE tenants ADD CONSTRAINT tenants_leasing_unit_id_fkey
  FOREIGN KEY (leasing_unit_id) REFERENCES leasing_units(id) ON DELETE SET NULL;

-- ============================================================
-- Phase 5: Add company_name to tenants table
-- Run this if the tenants table already exists
-- ============================================================

ALTER TABLE tenants ADD COLUMN IF NOT EXISTS company_name TEXT;
