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

## Known Issues
- **Route-ordering bug in `backend/routers/tasks.py`**: `GET /{task_id}` (line 63) is registered *before* `GET /summary` (line 91). FastAPI matches routes in registration order, so a request to `GET /api/v1/tasks/summary` will be captured by `/{task_id}` with `task_id="summary"` and hit `.eq("id", "summary").single()`, returning 404 (or worse, an unexpected row) instead of ever reaching `task_summary()`. The summary endpoint is effectively unreachable as written. Fix: move `/summary` above `/{task_id}`.
- `tasks` table has no corresponding `create table` in any tracked migration — see Database section above.
- The dashboard's "Tasks" widget (`frontend/lib/features/dashboard/presentation/widgets/tasks_section.dart`) does **not** use `TasksProvider` or this feature's data at all — see Related features below. Don't assume editing this feature affects the dashboard.

## Related features
- `frontend/lib/features/dashboard/presentation/widgets/tasks_section.dart` renders a `TasksSection(tasks: List<DashboardTask>)`. `DashboardTask` is a separate, unrelated entity defined in `frontend/lib/features/dashboard/domain/entities/dashboard_data.dart`, and the only three `DashboardTask(...)` construction sites in the whole codebase are **hardcoded sample data inside that same file** (lines ~126-144) — not fetched from `/api/v1/tasks/` or anywhere else. The section's "Add task" and "View all" links both `context.go('/calendar')`, not `/tasks`. In short: the dashboard task widget is currently disconnected from both the `tasks` feature and any live backend — it is mock UI. This contradicts an assumption worth double-checking in any future work: there is no live cross-dependency between dashboard and `TasksProvider` today.
- `calendar.md` — the dashboard's task links point at `/calendar`, reinforcing that "tasks" as displayed on the dashboard are conceptually calendar-ish reminders, not rows from the `tasks` table.
