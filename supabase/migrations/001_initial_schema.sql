-- ============================================================
-- Bogineni Group — Property Management Platform
-- Initial Schema Migration
-- Run in: Supabase Dashboard → SQL Editor
-- ============================================================

-- ── Extensions ───────────────────────────────────────────────────────
create extension if not exists "uuid-ossp";

-- ── Helper: updated_at trigger ────────────────────────────────────────
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ================================================================
-- 1. PROFILES  (linked to auth.users)
-- ================================================================
create table if not exists profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text,
  email       text unique,
  phone       text,
  avatar_url  text,
  role        text not null default 'admin', -- admin | manager | viewer
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create trigger profiles_updated_at
  before update on profiles
  for each row execute procedure set_updated_at();

-- Auto-create a profile row when a new user signs up
create or replace function handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();

-- ================================================================
-- 2. PROPERTIES / LEASING UNITS
-- ================================================================
create table if not exists leasing_units (
  id           text primary key default gen_random_uuid()::text,
  name         text not null,
  company_name text,                   -- Owner / portfolio group name
  category     text not null,          -- Restaurant | Office | Shop | etc.
  floor        text not null,          -- Ground Floor | First Floor | etc.
  status       text not null default 'vacant',  -- occupied | vacant | in_house | owner_occupied
  contact      text,
  email        text,
  notes        text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create trigger leasing_units_updated_at
  before update on leasing_units
  for each row execute procedure set_updated_at();

create table if not exists area_entries (
  id              uuid primary key default gen_random_uuid(),
  leasing_unit_id text not null references leasing_units(id) on delete cascade,
  type            text not null,   -- covered | open | common
  sqft            float8 not null default 0,
  rate            float8 not null default 0,  -- ₹ per sqft per month
  created_at      timestamptz not null default now()
);

-- ================================================================
-- 3. TENANTS & LEASES
-- ================================================================
create table if not exists tenants (
  id                      uuid primary key default gen_random_uuid(),
  first_name              text not null,
  last_name               text not null,
  email                   text,
  phone                   text,
  status                  text not null default 'active', -- active | inactive | pending
  leasing_unit_id         text references leasing_units(id) on delete set null,
  move_in_date            date,
  emergency_contact_name  text,
  emergency_contact_phone text,
  notes                   text,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

create trigger tenants_updated_at
  before update on tenants
  for each row execute procedure set_updated_at();

create table if not exists leases (
  id              uuid primary key default gen_random_uuid(),
  tenant_id       uuid not null references tenants(id) on delete cascade,
  leasing_unit_id text references leasing_units(id) on delete set null,
  start_date      date not null,
  end_date        date not null,
  monthly_rent    float8 not null default 0,
  deposit_amount  float8 not null default 0,
  status          text not null default 'active', -- active | expired | terminated | pending
  signed_date     date,
  document_url    text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create trigger leases_updated_at
  before update on leases
  for each row execute procedure set_updated_at();

-- ================================================================
-- 4. ACCOUNTING / TRANSACTIONS
-- ================================================================
create table if not exists transactions (
  id              uuid primary key default gen_random_uuid(),
  type            text not null,     -- income | expense
  category        text not null,     -- Rent | Maintenance | Insurance | Utilities | etc.
  amount          float8 not null default 0,
  currency        text not null default 'INR',
  date            date not null default current_date,
  description     text not null,
  status          text not null default 'paid', -- paid | pending | overdue
  leasing_unit_id text references leasing_units(id) on delete set null,
  tenant_id       uuid references tenants(id) on delete set null,
  lease_id        uuid references leases(id) on delete set null,
  reference_no    text,
  notes           text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create trigger transactions_updated_at
  before update on transactions
  for each row execute procedure set_updated_at();

-- Recurring rent schedule (auto-generates transactions)
create table if not exists rent_schedules (
  id              uuid primary key default gen_random_uuid(),
  lease_id        uuid not null references leases(id) on delete cascade,
  due_day         int not null default 1,  -- day of month rent is due
  amount          float8 not null,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now()
);

-- ================================================================
-- 5. APPLICATIONS (prospective tenants)
-- ================================================================
create table if not exists applications (
  id                uuid primary key default gen_random_uuid(),
  applicant_name    text not null,
  email             text,
  phone             text,
  leasing_unit_id   text references leasing_units(id) on delete set null,
  status            text not null default 'pending', -- pending | reviewing | approved | rejected | withdrawn
  monthly_income    float8,
  desired_move_in   date,
  message           text,
  reviewed_by       uuid references profiles(id) on delete set null,
  reviewed_at       timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create trigger applications_updated_at
  before update on applications
  for each row execute procedure set_updated_at();

-- ================================================================
-- 6. LISTINGS (public-facing adverts)
-- ================================================================
create table if not exists listings (
  id              uuid primary key default gen_random_uuid(),
  leasing_unit_id text references leasing_units(id) on delete cascade,
  title           text not null,
  description     text,
  monthly_rent    float8 not null,
  available_from  date,
  is_published    boolean not null default false,
  contact_email   text,
  contact_phone   text,
  photos          text[] default '{}',   -- array of storage URLs
  features        text[] default '{}',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create trigger listings_updated_at
  before update on listings
  for each row execute procedure set_updated_at();

-- ================================================================
-- 7. MAINTENANCE
-- ================================================================
create table if not exists maintenance_requests (
  id              uuid primary key default gen_random_uuid(),
  title           text not null,
  description     text,
  priority        text not null default 'medium', -- low | medium | high | urgent
  status          text not null default 'open',   -- open | in_progress | on_hold | completed | cancelled
  category        text,   -- Plumbing | Electrical | HVAC | General | etc.
  leasing_unit_id text references leasing_units(id) on delete set null,
  tenant_id       uuid references tenants(id) on delete set null,
  assigned_to     text,   -- contractor / vendor name
  assigned_email  text,
  estimated_cost  float8,
  actual_cost     float8,
  scheduled_date  date,
  completed_date  date,
  photos          text[] default '{}',
  notes           text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create trigger maintenance_requests_updated_at
  before update on maintenance_requests
  for each row execute procedure set_updated_at();

create table if not exists maintenance_comments (
  id          uuid primary key default gen_random_uuid(),
  request_id  uuid not null references maintenance_requests(id) on delete cascade,
  author_id   uuid references profiles(id) on delete set null,
  body        text not null,
  created_at  timestamptz not null default now()
);

-- ================================================================
-- 8. DOCUMENTS
-- ================================================================
create table if not exists documents (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  type            text,        -- lease | invoice | inspection | permit | other
  file_url        text not null,
  file_size       int,
  leasing_unit_id text references leasing_units(id) on delete set null,
  tenant_id       uuid references tenants(id) on delete set null,
  uploaded_by     uuid references profiles(id) on delete set null,
  created_at      timestamptz not null default now()
);

-- ================================================================
-- 9. NOTIFICATIONS
-- ================================================================
create table if not exists notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references profiles(id) on delete cascade,
  title       text not null,
  body        text,
  type        text not null default 'info', -- info | warning | success | error
  is_read     boolean not null default false,
  action_url  text,
  created_at  timestamptz not null default now()
);

-- ================================================================
-- 10. CALENDAR / EVENTS
-- ================================================================
create table if not exists events (
  id              uuid primary key default gen_random_uuid(),
  title           text not null,
  description     text,
  event_type      text,   -- inspection | payment_due | lease_renewal | maintenance | meeting
  start_at        timestamptz not null,
  end_at          timestamptz,
  all_day         boolean not null default false,
  leasing_unit_id text references leasing_units(id) on delete set null,
  tenant_id       uuid references tenants(id) on delete set null,
  created_by      uuid references profiles(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create trigger events_updated_at
  before update on events
  for each row execute procedure set_updated_at();

-- ================================================================
-- 11. REPORTS (saved / scheduled)
-- ================================================================
create table if not exists reports (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  type            text not null,   -- financial | occupancy | maintenance | custom
  filters         jsonb default '{}',
  generated_by    uuid references profiles(id) on delete set null,
  file_url        text,
  generated_at    timestamptz,
  created_at      timestamptz not null default now()
);

-- ================================================================
-- ROW LEVEL SECURITY (RLS)
-- Enable RLS on all tables — authenticated users can read/write all.
-- Scope per-user logic can be added later via policies.
-- ================================================================
alter table profiles              enable row level security;
alter table leasing_units         enable row level security;
alter table area_entries          enable row level security;
alter table tenants               enable row level security;
alter table leases                enable row level security;
alter table transactions          enable row level security;
alter table rent_schedules        enable row level security;
alter table applications          enable row level security;
alter table listings              enable row level security;
alter table maintenance_requests  enable row level security;
alter table maintenance_comments  enable row level security;
alter table documents             enable row level security;
alter table notifications         enable row level security;
alter table events                enable row level security;
alter table reports               enable row level security;

-- Open policies for authenticated users (tighten per role later)
do $$
declare
  tbl text;
begin
  foreach tbl in array array[
    'profiles','leasing_units','area_entries','tenants','leases',
    'transactions','rent_schedules','applications','listings',
    'maintenance_requests','maintenance_comments','documents',
    'notifications','events','reports'
  ] loop
    execute format(
      'create policy "%s_auth_all" on %I
       for all to authenticated using (true) with check (true)',
      tbl, tbl
    );
  end loop;
end;
$$;

-- ================================================================
-- INDEXES (for common query patterns)
-- ================================================================
create index if not exists idx_area_entries_unit      on area_entries(leasing_unit_id);
create index if not exists idx_tenants_unit           on tenants(leasing_unit_id);
create index if not exists idx_leases_tenant          on leases(tenant_id);
create index if not exists idx_leases_unit            on leases(leasing_unit_id);
create index if not exists idx_transactions_date      on transactions(date desc);
create index if not exists idx_transactions_unit      on transactions(leasing_unit_id);
create index if not exists idx_transactions_tenant    on transactions(tenant_id);
create index if not exists idx_maintenance_status     on maintenance_requests(status);
create index if not exists idx_maintenance_unit       on maintenance_requests(leasing_unit_id);
create index if not exists idx_notifications_user     on notifications(user_id, is_read);
create index if not exists idx_events_start           on events(start_at);
