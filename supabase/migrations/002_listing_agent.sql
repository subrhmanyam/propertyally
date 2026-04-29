-- ============================================================
-- Bogineni Group — Listing Agent Migration
-- Run in: Supabase Dashboard → SQL Editor
-- ============================================================

-- ================================================================
-- listing_platform_posts
-- Tracks one row per (listing, platform) — status lifecycle for
-- each platform a listing has been posted or attempted on.
-- ================================================================
create table if not exists listing_platform_posts (
  id                uuid primary key default gen_random_uuid(),
  listing_id        uuid not null references listings(id) on delete cascade,
  platform_key      text not null,
  -- 'housing_com' | '99acres' | 'magicbricks' | 'nobroker'
  status            text not null default 'pending',
  -- pending | posting | posted | failed | manual_required
  external_id       text,           -- ID returned by platform API
  external_url      text,           -- Deep-link to live listing on that platform
  platform_title    text,           -- Claude-generated title for this platform
  platform_desc     text,           -- Claude-generated description for this platform
  error_message     text,           -- Last error if status = 'failed'
  posted_at         timestamptz,
  last_attempted_at timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  unique(listing_id, platform_key)
);

create trigger listing_platform_posts_updated_at
  before update on listing_platform_posts
  for each row execute procedure set_updated_at();

-- RLS (same open authenticated policy as all other tables)
alter table listing_platform_posts enable row level security;

create policy "listing_platform_posts_auth_all" on listing_platform_posts
  for all to authenticated using (true) with check (true);

-- Indexes
create index if not exists idx_platform_posts_listing
  on listing_platform_posts(listing_id);
create index if not exists idx_platform_posts_status
  on listing_platform_posts(status);
create index if not exists idx_platform_posts_platform
  on listing_platform_posts(platform_key);

-- ================================================================
-- listing_agent_queue
-- Secondary trigger-based vacancy queue (belt-and-suspenders).
-- Populated by DB trigger when a unit's status changes to 'vacant'
-- even via direct DB writes outside the API.
-- ================================================================
create table if not exists listing_agent_queue (
  id               uuid primary key default gen_random_uuid(),
  leasing_unit_id  text not null unique references leasing_units(id) on delete cascade,
  triggered_at     timestamptz not null default now(),
  processed        boolean not null default false,
  processed_at     timestamptz
);

create index if not exists idx_agent_queue_unprocessed
  on listing_agent_queue(processed, triggered_at)
  where processed = false;

-- DB trigger: fires when leasing_unit.status changes to 'vacant'
create or replace function notify_unit_vacant()
returns trigger language plpgsql as $$
begin
  if new.status = 'vacant' and (old.status is null or old.status != 'vacant') then
    insert into listing_agent_queue (leasing_unit_id, triggered_at, processed)
    values (new.id, now(), false)
    on conflict (leasing_unit_id)
    do update set triggered_at = now(), processed = false, processed_at = null;
  end if;
  return new;
end;
$$;

create trigger on_unit_becomes_vacant
  after update on leasing_units
  for each row
  when (old.status is distinct from new.status)
  execute procedure notify_unit_vacant();
