-- ============================================================
-- Bogineni Group — Service Request Details
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run)
--
-- Adds expenses-borne-by, estimated cost, and initiated date to
-- service_requests, and constrains status to the fixed workflow
-- used by the admin Services screen:
--   Initiated → Review → Approved → In progress → Completed / Declined
-- ============================================================

alter table service_requests add column if not exists expenses_borne_by text;
alter table service_requests add column if not exists estimated_cost numeric;
alter table service_requests add column if not exists initiated_date timestamptz not null default now();

alter table service_requests alter column status set default 'Initiated';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'service_requests_status_check'
  ) then
    alter table service_requests
      add constraint service_requests_status_check
      check (status in ('Initiated', 'Review', 'Approved', 'In progress', 'Completed', 'Declined'));
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'service_requests_expenses_borne_by_check'
  ) then
    alter table service_requests
      add constraint service_requests_expenses_borne_by_check
      check (expenses_borne_by is null or expenses_borne_by in ('Owner', 'Tenant'));
  end if;
end $$;
