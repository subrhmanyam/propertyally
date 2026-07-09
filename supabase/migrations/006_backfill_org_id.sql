-- ============================================================
-- Bogineni Group — Backfill org_id + auto-default for future inserts
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run)
--
-- 004_organizations.sql backfilled org_id once, at migration time. Since
-- then, every new leasing_unit created via import/"Add Property" (and any
-- future insert path) has been landing with org_id = null — because
-- nothing ever set it going forward. That's why GCS archival silently
-- skips newly-created properties: there's no org to build a path under.
--
-- This does two things:
--   1. One-time backfill of every leasing_units/documents row that still
--      has org_id = null, onto the org that already owns everything else.
--   2. A trigger so any future insert that omits org_id gets it filled
--      in automatically — instead of relying on every call site (Flutter
--      direct-to-Supabase inserts, backend routes, imports) to remember.
-- ============================================================

do $$
declare
  default_org_id uuid;
begin
  select id into default_org_id from organizations order by created_at limit 1;
  if default_org_id is not null then
    update leasing_units set org_id = default_org_id where org_id is null;
    update documents     set org_id = default_org_id where org_id is null;
  end if;
end;
$$;

create or replace function set_default_org_id()
returns trigger language plpgsql as $$
begin
  if new.org_id is null then
    select id into new.org_id from organizations order by created_at limit 1;
  end if;
  return new;
end;
$$;

drop trigger if exists leasing_units_default_org on leasing_units;
create trigger leasing_units_default_org
  before insert on leasing_units
  for each row execute procedure set_default_org_id();

drop trigger if exists documents_default_org on documents;
create trigger documents_default_org
  before insert on documents
  for each row execute procedure set_default_org_id();
