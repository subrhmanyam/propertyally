-- ============================================================
-- Bogineni Group — Service Request Approval Workflow + Documents
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run)
--
-- Tracks who requested a service (Owner via admin, or Tenant via
-- the tenant portal) so the app can require sign-off from whichever
-- party bears the expense before a request moves to Approved, and
-- links supporting documents (invoices/quotes/receipts) to a request.
-- ============================================================

alter table service_requests add column if not exists requested_by text not null default 'Owner';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'service_requests_requested_by_check'
  ) then
    alter table service_requests
      add constraint service_requests_requested_by_check
      check (requested_by in ('Owner', 'Tenant'));
  end if;
end $$;

alter table documents add column if not exists service_request_id uuid references service_requests(id) on delete cascade;
create index if not exists idx_documents_service_request on documents(service_request_id);
