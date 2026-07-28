-- ============================================================
-- Bogineni Group — Tasks table
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run)
--
-- backend/routers/tasks.py has always assumed a `tasks` table exists
-- (TaskIn/TaskUpdate models, list/create/update endpoints), but no
-- migration ever actually created it — every call to GET/POST
-- /api/v1/tasks/ (including the "New Task" button on /tasks) has been
-- failing with a Postgrest schema-cache error
-- ("Could not find the table 'public.tasks'") since the feature was
-- built. This adds the missing table.
-- ============================================================

create table if not exists tasks (
  id                          uuid primary key default gen_random_uuid(),
  title                       text not null,
  description                 text,
  property_id                 text,
  leasing_unit_id             text references leasing_units(id) on delete set null,
  assigned_to                 text,
  priority                    text not null default 'medium', -- low | medium | high | urgent
  status                      text not null default 'open',   -- open | in_progress | completed | cancelled
  due_date                    date,
  recurring_rule              text,
  related_service_request_id  uuid references service_requests(id) on delete set null,
  completed_at                timestamptz,
  notes                       text,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now()
);

create index if not exists idx_tasks_leasing_unit on tasks(leasing_unit_id);
create index if not exists idx_tasks_status       on tasks(status);
create index if not exists idx_tasks_due_date      on tasks(due_date);

create trigger tasks_updated_at
  before update on tasks
  for each row execute function set_updated_at();

alter table tasks enable row level security;

create policy "tasks_auth_all" on tasks
  for all to authenticated using (true) with check (true);
