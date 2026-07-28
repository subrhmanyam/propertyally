# Tasks

## Purpose
Generic operational to-do list for property-management work items (distinct from tenant-facing maintenance/service requests) — title, priority, status, optional due date, optional recurrence, optional link to a property/unit or assignee.

## Frontend
- **Screens**: `frontend/lib/features/tasks/presentation/screens/tasks_screen.dart` — KPI strip (Open/In Progress/Completed/Overdue computed client-side), status filter chips, table view, "New Task" dialog.
- **Providers**: `frontend/lib/features/tasks/presentation/providers/tasks_provider.dart` (`TasksProvider extends ChangeNotifier`, not `BaseProvider`) — owns `tasks: List<Task>`, `units: List<Map>` (fetched from leasing for the unit-assignment dropdown), `isLoading`, `_statusFilter`.
- **Repositories**: `frontend/lib/features/tasks/data/repositories/tasks_repository.dart` (`TasksRepository`) — calls `GET /api/v1/tasks/`, `GET /api/v1/leasing/` (for unit picker), `POST /api/v1/tasks/`, `PATCH /api/v1/tasks/{id}`. Uses `ApiClient.instance`.
- **Domain entities**: `frontend/lib/features/tasks/domain/entities/task.dart` (`Task`) — `id, title, description?, propertyId?, leasingUnitId?, assignedTo?, priority, status, dueDate?, recurringRule?, createdAt?, updatedAt?`.

## Backend
- Router: `backend/routers/tasks.py`, mounted at `/api/v1/tasks` (see `backend/main.py:59`).
- Key endpoints:
  - `GET /` — list tasks, filterable by `property_id`, `unit_id` (maps to `leasing_unit_id` column), `status`, `priority`, `assigned_to`.
  - `GET /{task_id}` — single task.
  - `POST /` — create task. `TaskIn` also accepts `related_service_request_id` (link to a `service_requests` row) though nothing in the frontend sets it.
  - `PATCH /{task_id}` — partial update (`TaskUpdate`: title, description, assigned_to, priority, status, due_date, recurring_rule, completed_at, notes).
  - `GET /summary` — aggregate counts (total/open/in_progress/completed/overdue/recurring). **Not called by any Dart repository.**

## Database
- Table: `tasks` — columns inferred from `TaskIn`/`TaskUpdate`/`Task.fromJson`: `id, title, description, property_id, leasing_unit_id, assigned_to, priority, status, due_date, recurring_rule, completed_at, notes, related_service_request_id, created_at, updated_at`.
- **No migration in this repo creates a `tasks` table.** Grepped every file under `supabase/migrations/*.sql` and `supabase_tenants_migration.sql` for `create table.*tasks` — zero matches. Either the table was created ad hoc directly in the Supabase dashboard (outside version control) or this feature has never been exercised against a real database. Verify the table actually exists in Supabase before relying on this feature.

## Key patterns / architecture notes
- `TasksProvider` swallows all load errors silently (`catch (_) { tasks = []; units = []; }` in `load()`) — a failed `GET /tasks/` (e.g. missing table) renders as an empty list with no error banner, no exception surfaced to the user.
- KPI strip and status filtering are computed entirely client-side from the already-fetched `tasks` list (no server-side aggregation used, despite `GET /summary` existing for exactly this purpose).
- `_TaskRow`/`_TasksTable` in `tasks_screen.dart` use untyped `dynamic` for the `task` parameter rather than `Task`, unlike the rest of the codebase's typed patterns.

## Recent changes (org-admin authorization hardening)
- `POST /` and `PATCH /{task_id}` previously had zero auth and now require a `user_id` query param + `require_org_admin_for_unit`/`require_any_org_admin` (fallback for org-wide tasks with no `leasing_unit_id`) via `backend/auth_utils.py`. `TasksRepository.createTask()`/`updateTask()` now pass `Supabase.instance.client.auth.currentUser?.id` as `user_id`.

## Recent changes (missing `tasks` table + dashboard integration)
- **The `tasks` table did not exist in the live Supabase database at all**, despite `backend/routers/tasks.py` having always assumed it did — every call to `GET`/`POST /api/v1/tasks/` (including the "New Task" button on `/tasks`) 500'd with `postgrest.exceptions.APIError: Could not find the table 'public.tasks' in the schema cache`. Added `supabase/migrations/011_tasks.sql` (columns matching `TaskIn`/`TaskUpdate`: `title, description, property_id, leasing_unit_id, assigned_to, priority, status, due_date, recurring_rule, related_service_request_id, completed_at, notes`, plus the standard `updated_at` trigger and an open `authenticated`-role RLS policy matching every other table in `001_initial_schema.sql`). User ran it and confirmed both listing and creating tasks now work end-to-end.
- `list_tasks`'s `.order("due_date", ascending=True)` was also fixed to `.order("due_date", desc=False)` — the installed `postgrest` version's `order()` doesn't accept an `ascending` kwarg at all (found while wiring up the dashboard's new Events feed, which hit the identical bug in `calendar.py` — see `calendar.md`'s Recent changes). This was necessary but not sufficient on its own; the table had to exist first.
- **The dashboard's Events feed now includes real Tasks.** `dashboard.md`'s `EventsSection` initially merged only Calendar Events + Service Requests (a deliberate, user-confirmed scope decision at the time), but was expanded to also include open Tasks (`status` not `completed`/`cancelled`) after the user created a real task and expected to see it there. See `dashboard.md`'s Recent changes for the full merge/sort/filter logic.

## Known Issues
- **Route-ordering bug in `backend/routers/tasks.py`**: `GET /{task_id}` (line 63) is registered *before* `GET /summary` (line 91). FastAPI matches routes in registration order, so a request to `GET /api/v1/tasks/summary` will be captured by `/{task_id}` with `task_id="summary"` and hit `.eq("id", "summary").single()`, returning 404 (or worse, an unexpected row) instead of ever reaching `task_summary()`. The summary endpoint is effectively unreachable as written. Fix: move `/summary` above `/{task_id}`.

## Related features
- `dashboard.md` — `EventsSection` (the dashboard's merged Events feed) now reads real `TasksProvider` data alongside Calendar Events and Service Requests, replacing the old `tasks_section.dart`/`DashboardTask` mock UI (deleted) that previously showed hardcoded sample tasks disconnected from this feature and its "Add task"/"View all" links that pointed at `/calendar` instead of `/tasks`. See `dashboard.md`'s Recent changes for the merge logic.
- `calendar.md` — shares the same `.order(..., ascending=True)` → `desc=False` `postgrest` bug fix pattern found in this feature's `list_tasks`.
