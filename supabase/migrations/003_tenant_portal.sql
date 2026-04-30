-- ================================================================
-- 003 TENANT PORTAL
-- service_catalog, service_requests, tenant_queries,
-- stripe_payments, auth_user_id on tenants, JWT hook, RLS
-- ================================================================

-- 1. Link Supabase auth user → tenants row
alter table public.tenants
  add column if not exists auth_user_id uuid references auth.users(id) on delete set null;

create unique index if not exists idx_tenants_auth_user
  on public.tenants(auth_user_id) where auth_user_id is not null;

-- 2. Service catalog
create table if not exists service_catalog (
  id                uuid primary key default gen_random_uuid(),
  name              text not null,
  category          text not null,
  description       text,
  property_types    text[] not null default '{}',
  typical_sla_hours int  not null default 24,
  is_active         boolean not null default true,
  created_at        timestamptz not null default now()
);

-- 3. Service requests
create table if not exists service_requests (
  id              uuid primary key default gen_random_uuid(),
  leasing_unit_id text references leasing_units(id) on delete set null,
  tenant_id       uuid references tenants(id) on delete set null,
  service_id      uuid references service_catalog(id) on delete set null,
  service_name    text,
  description     text,
  priority        text not null default 'normal',  -- normal | urgent
  status          text not null default 'open',
  photos          text[] default '{}',
  assigned_to     text,
  scheduled_at    timestamptz,
  completed_at    timestamptz,
  tenant_rating   int,
  admin_notes     text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create trigger service_requests_updated_at
  before update on service_requests
  for each row execute procedure set_updated_at();

-- 4. Tenant queries (messaging)
create table if not exists tenant_queries (
  id              uuid primary key default gen_random_uuid(),
  tenant_id       uuid references tenants(id) on delete cascade,
  leasing_unit_id text references leasing_units(id) on delete set null,
  subject         text not null,
  body            text not null,
  status          text not null default 'open',  -- open | replied | closed
  is_read_admin   boolean not null default false,
  is_read_tenant  boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create table if not exists tenant_query_replies (
  id          uuid primary key default gen_random_uuid(),
  query_id    uuid not null references tenant_queries(id) on delete cascade,
  author_role text not null default 'tenant',  -- tenant | admin
  body        text not null,
  created_at  timestamptz not null default now()
);

create trigger tenant_queries_updated_at
  before update on tenant_queries
  for each row execute procedure set_updated_at();

-- 5. Stripe payment sessions
create table if not exists stripe_payments (
  id                       uuid primary key default gen_random_uuid(),
  transaction_id           uuid references transactions(id) on delete set null,
  tenant_id                uuid references tenants(id) on delete set null,
  stripe_session_id        text unique,
  stripe_payment_intent_id text,
  amount_paise             bigint not null,
  currency                 text not null default 'inr',
  status                   text not null default 'pending',  -- pending | paid | failed | cancelled
  metadata                 jsonb default '{}',
  created_at               timestamptz not null default now(),
  paid_at                  timestamptz
);

-- 6. Indexes
create index if not exists idx_service_requests_tenant on service_requests(tenant_id);
create index if not exists idx_service_requests_unit   on service_requests(leasing_unit_id);
create index if not exists idx_tenant_queries_tenant   on tenant_queries(tenant_id);
create index if not exists idx_stripe_payments_tenant  on stripe_payments(tenant_id);
create index if not exists idx_stripe_session          on stripe_payments(stripe_session_id);

-- 7. Custom Access Token Hook — injects role into JWT app_metadata
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb language plpgsql security definer as $$
declare
  claims   jsonb;
  user_role text;
begin
  select role into user_role from public.profiles
  where id = (event->>'user_id')::uuid;

  claims := event->'claims';
  if jsonb_typeof(claims->'app_metadata') is null then
    claims := jsonb_set(claims, '{app_metadata}', '{}');
  end if;
  claims := jsonb_set(
    claims, '{app_metadata,role}',
    to_jsonb(coalesce(user_role, 'tenant'))
  );
  return jsonb_set(event, '{claims}', claims);
end;
$$;

grant all   on table public.profiles to supabase_auth_admin;
revoke all  on table public.profiles from authenticated, anon;
grant execute on function public.custom_access_token_hook to supabase_auth_admin;

-- 8. RLS
alter table public.service_catalog       enable row level security;
alter table public.service_requests      enable row level security;
alter table public.tenant_queries        enable row level security;
alter table public.tenant_query_replies  enable row level security;
alter table public.stripe_payments       enable row level security;

-- service_catalog: all authenticated users can read active items
create policy "read_active_catalog" on public.service_catalog
  for select to authenticated using (is_active = true);

-- admin can manage catalog
create policy "admin_manage_catalog" on public.service_catalog
  for all to authenticated using (
    (auth.jwt()->'app_metadata'->>'role') = 'admin'
  );

-- service_requests: tenant owns their rows; admin sees all
create policy "service_requests_access" on public.service_requests
  for all to authenticated using (
    (auth.jwt()->'app_metadata'->>'role') = 'admin'
    or tenant_id = (
      select id from public.tenants
      where auth_user_id = auth.uid() limit 1
    )
  );

-- tenant_queries
create policy "tenant_queries_access" on public.tenant_queries
  for all to authenticated using (
    (auth.jwt()->'app_metadata'->>'role') = 'admin'
    or tenant_id = (
      select id from public.tenants
      where auth_user_id = auth.uid() limit 1
    )
  );

create policy "tenant_query_replies_access" on public.tenant_query_replies
  for all to authenticated using (
    (auth.jwt()->'app_metadata'->>'role') = 'admin'
    or query_id in (
      select id from public.tenant_queries
      where tenant_id = (
        select id from public.tenants
        where auth_user_id = auth.uid() limit 1
      )
    )
  );

-- stripe_payments: tenant sees own; admin sees all
create policy "stripe_payments_access" on public.stripe_payments
  for all to authenticated using (
    (auth.jwt()->'app_metadata'->>'role') = 'admin'
    or tenant_id = (
      select id from public.tenants
      where auth_user_id = auth.uid() limit 1
    )
  );

-- 9. Seed service catalog
insert into public.service_catalog (name, category, description, property_types, typical_sla_hours) values
  ('Pipe Leak / Burst',          'Plumbing',          'Leaking or burst water pipe repair',                    ARRAY['Restaurant','Shop','Office','Residence','CoWorking'], 4),
  ('Drain Blockage',             'Plumbing',          'Blocked or slow drain clearance',                       ARRAY['Restaurant','Shop','Office','Residence','CoWorking'], 8),
  ('Water Supply Issue',         'Plumbing',          'No water or low water pressure',                        ARRAY['Restaurant','Shop','Office','Residence','CoWorking'], 4),
  ('Tap / Faucet Repair',        'Plumbing',          'Leaking tap or faucet replacement',                     ARRAY['Restaurant','Shop','Office','Residence','CoWorking'], 24),
  ('Power Outage / Trip',        'Electrical',        'Electrical trip or complete power failure',             ARRAY['Restaurant','Shop','Office','Residence','CoWorking'], 2),
  ('New Power Point',            'Electrical',        'Installation of new electrical outlet',                 ARRAY['Office','Restaurant','Shop','CoWorking'], 48),
  ('Meter Issue',                'Electrical',        'Meter reading or billing discrepancy',                  ARRAY['Restaurant','Shop','Office','Residence','CoWorking'], 48),
  ('Wiring Fault',               'Electrical',        'Exposed wire or electrical fault',                      ARRAY['Restaurant','Shop','Office','Residence','CoWorking'], 4),
  ('Light Fixture Repair',       'Lighting',          'Repair or replace broken light fitting',                ARRAY['Restaurant','Shop','Office','Residence','CoWorking'], 24),
  ('Signage Lighting',           'Lighting',          'Repair of exterior or interior signage lighting',       ARRAY['Shop','Restaurant'], 48),
  ('Interior Mood Lighting',     'Lighting',          'Decorative lighting installation or repair',            ARRAY['Restaurant','Shop'], 72),
  ('Emergency Exit Lighting',    'Lighting',          'Emergency exit sign or lighting repair',                ARRAY['Restaurant','Shop','Office','CoWorking'], 4),
  ('AC Not Cooling',             'HVAC',              'Air conditioner not cooling or not working',            ARRAY['Restaurant','Shop','Office','Residence','CoWorking'], 4),
  ('AC Gas Refill / Service',    'HVAC',              'AC refrigerant refill or annual service',               ARRAY['Restaurant','Shop','Office','Residence','CoWorking'], 24),
  ('Ventilation / Exhaust Fan',  'HVAC',              'Exhaust fan repair or replacement',                     ARRAY['Restaurant','Office','CoWorking'], 24),
  ('Duct Cleaning',              'HVAC',              'Air duct and vent cleaning',                            ARRAY['Restaurant','Office','CoWorking'], 72),
  ('Door / Window Repair',       'Carpentry',         'Repair or replacement of door or window',              ARRAY['Restaurant','Shop','Office','Residence','CoWorking'], 24),
  ('Furniture / Fixture Repair', 'Carpentry',         'Repair of built-in furniture or fixtures',              ARRAY['Office','CoWorking','Residence'], 48),
  ('Partition / Cabin Work',     'Carpentry',         'Installation or repair of office partitions',           ARRAY['Office','CoWorking'], 72),
  ('False Ceiling Repair',       'Carpentry',         'Repair of false ceiling or ceiling tiles',              ARRAY['Restaurant','Office','Shop'], 48),
  ('Internet / Network Point',   'IT & Network',      'New network point or internet connectivity issue',      ARRAY['Office','CoWorking'], 24),
  ('CCTV / Access Control',      'IT & Network',      'CCTV camera or access card system issue',               ARRAY['Restaurant','Shop','Office','CoWorking'], 24),
  ('Painting / Touch-up',        'Decoration',        'Interior or exterior paint touch-up',                  ARRAY['Restaurant','Shop','Office','Residence','CoWorking'], 72),
  ('Flooring Repair',            'Decoration',        'Tile, vinyl, or flooring repair',                       ARRAY['Restaurant','Shop','Office','Residence','CoWorking'], 48),
  ('Waterproofing / Seepage',    'Decoration',        'Water seepage or damp wall treatment',                  ARRAY['Restaurant','Shop','Office','Residence','CoWorking'], 48),
  ('Gas Line / Burner Repair',   'Kitchen Equipment', 'Commercial gas line or burner repair',                  ARRAY['Restaurant'], 4),
  ('Exhaust Hood / Chimney',     'Kitchen Equipment', 'Kitchen exhaust hood cleaning or repair',               ARRAY['Restaurant'], 24),
  ('Grease Trap Cleaning',       'Kitchen Equipment', 'Commercial grease trap service',                        ARRAY['Restaurant'], 48),
  ('Cockroach / Rodent Control', 'Pest Control',      'Pest treatment for cockroaches or rodents',            ARRAY['Restaurant','Shop','Office','Residence','CoWorking'], 24),
  ('General Fumigation',         'Pest Control',      'Full-premises pest fumigation',                         ARRAY['Restaurant','Shop','Office','Residence','CoWorking'], 48),
  ('Deep Clean',                 'Housekeeping',      'Full premises deep cleaning service',                   ARRAY['Restaurant','Office','CoWorking','Shop'], 48),
  ('Carpet / Upholstery Clean',  'Housekeeping',      'Professional carpet and upholstery cleaning',           ARRAY['Office','CoWorking','Residence'], 48)
on conflict do nothing;
