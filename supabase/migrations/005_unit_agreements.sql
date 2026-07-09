-- ============================================================
-- Bogineni Group — Unit Agreements (AI-extracted lease terms)
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run)
--
-- This table already existed conceptually (backend/agents/document_extractor.py
-- has documented its shape for a while) but was never added as a real
-- migration, so it doesn't exist in the actual database yet. This creates it
-- plus the additional fields needed to show owner/tenant address, profit
-- sharing, amenities, furnishing, and maintenance responsibility on the
-- tenant details screen — and links each agreement to the org + GCS object
-- it was archived to.
-- ============================================================

create table if not exists unit_agreements (
  id                    uuid primary key default gen_random_uuid(),
  unit_id               text not null unique references leasing_units(id) on delete cascade,
  org_id                uuid references organizations(id),
  document_name         text,
  document_type         text,           -- 'pdf' | 'image'
  storage_path          text,           -- GCS object path
  file_url              text,           -- signed GCS URL at time of upload

  -- Parties
  tenant_name           text,
  tenant_address        text,
  tenant_gstin          text,
  owner_name            text,
  owner_address         text,
  owner_gstin           text,

  -- Area
  total_area_sqft       float,
  covered_area_sqft     float,
  open_area_sqft        float,

  -- Financials
  monthly_rent          float,
  monthly_maintenance   float,
  security_deposit      float,
  profit_sharing        text,           -- e.g. "20% of gross revenue to owner"; null if not applicable
  maintenance_paid_by   text,           -- owner | tenant | shared (who bears maintenance charges/expenses)

  -- Space & amenities
  furnishing_status     text,           -- fully_furnished | semi_furnished | unfurnished
  car_parking_count     int,
  amenities             jsonb default '[]', -- other amenities, e.g. ["power backup", "lift access"]

  -- Term
  lease_start_date      date,
  lease_end_date        date,
  notice_period_days    int,
  payment_due_day       int,

  -- GST
  is_gst_applicable     boolean default false,
  cgst_rate             float,
  sgst_rate             float,

  special_clauses       jsonb default '[]',
  document_date         date,
  raw_extraction        jsonb,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create index if not exists idx_unit_agreements_unit on unit_agreements(unit_id);
create index if not exists idx_unit_agreements_org  on unit_agreements(org_id);

drop trigger if exists unit_agreements_updated_at on unit_agreements;
create trigger unit_agreements_updated_at
  before update on unit_agreements
  for each row execute procedure set_updated_at();

alter table unit_agreements enable row level security;

drop policy if exists "unit_agreements_auth_all" on unit_agreements;
create policy "unit_agreements_auth_all" on unit_agreements
  for all to authenticated using (true) with check (true);
