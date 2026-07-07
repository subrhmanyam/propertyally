-- ============================================================
-- Bogineni Group — Organizations & Multi-Tenancy
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run)
--
-- Introduces the account model needed for GCS file storage paths:
--   organizations        — the tenant/account boundary
--   organization_members — one login (auth.users) can belong to
--                          many orgs; one org can have many members
--   leasing_units.org_id — a property belongs to exactly one org
--   documents.org_id     — a document belongs to exactly one org
-- ============================================================

-- ================================================================
-- 1. ORGANIZATIONS
-- ================================================================
create table if not exists organizations (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

drop trigger if exists organizations_updated_at on organizations;
create trigger organizations_updated_at
  before update on organizations
  for each row execute procedure set_updated_at();

-- ================================================================
-- 2. ORGANIZATION MEMBERS
-- ================================================================
create table if not exists organization_members (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organizations(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  role        text not null default 'admin', -- admin | manager | viewer
  created_at  timestamptz not null default now(),
  unique (org_id, user_id)
);

create index if not exists idx_org_members_user on organization_members(user_id);
create index if not exists idx_org_members_org  on organization_members(org_id);

-- ================================================================
-- 3. Link properties and documents to an org
-- ================================================================
alter table leasing_units add column if not exists org_id uuid references organizations(id);
alter table documents     add column if not exists org_id uuid references organizations(id);
alter table documents     add column if not exists storage_path text; -- GCS object path (for regenerating signed URLs)

create index if not exists idx_leasing_units_org on leasing_units(org_id);
create index if not exists idx_documents_org     on documents(org_id);

-- ================================================================
-- 4. Backfill — put all pre-existing data under one "Bogineni Group"
--    org and make every existing profile a member of it. Only runs
--    once: skipped if an organization already exists.
-- ================================================================
do $$
declare
  default_org_id uuid;
begin
  if not exists (select 1 from organizations) then
    insert into organizations (name) values ('Bogineni Group')
    returning id into default_org_id;

    update leasing_units set org_id = default_org_id where org_id is null;
    update documents     set org_id = default_org_id where org_id is null;

    insert into organization_members (org_id, user_id, role)
    select default_org_id, id, coalesce(role, 'admin') from profiles
    on conflict (org_id, user_id) do nothing;
  end if;
end;
$$;

-- ================================================================
-- 5. RLS — same permissive "authenticated" policy style as 001
-- ================================================================
alter table organizations         enable row level security;
alter table organization_members  enable row level security;

drop policy if exists "organizations_auth_all" on organizations;
create policy "organizations_auth_all" on organizations
  for all to authenticated using (true) with check (true);

drop policy if exists "organization_members_auth_all" on organization_members;
create policy "organization_members_auth_all" on organization_members
  for all to authenticated using (true) with check (true);
