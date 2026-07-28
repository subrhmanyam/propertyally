# Maintenance

## Purpose
Admin-side repair/maintenance ticket tracker (title, priority, status, category, assigned contractor, cost, photos) for internal ops use — separate from the tenant-facing "Services" request/approval workflow (see Related features).

## Frontend
- **Screens**: `frontend/lib/features/maintenance/presentation/screens/maintenance_screen.dart` — KPI chips (Open/In Progress/Urgent), status filter bar + search, responsive desktop table / mobile card list, per-row status-change popup menu, "New Request" dialog.
- **Providers**: `frontend/lib/features/maintenance/presentation/providers/maintenance_provider.dart` (`MaintenanceProvider extends BaseProvider`) — owns `_requests: List<MaintenanceRequest>`, `_filter` (`MaintFilter`: all/open/inProgress/completed), `_searchQuery` (client-side substring match over title/category/assignedTo/description).
- **Repositories**: `frontend/lib/features/maintenance/data/repositories/maintenance_repository.dart` (`MaintenanceRepository`) — calls `GET /api/v1/maintenance/`, `POST /api/v1/maintenance/`, `PUT /api/v1/maintenance/{id}` (status update). **Uses `ApiClient.maintenance`, a distinct Dio instance** (`frontend/lib/core/network/api_client.dart:47`), not the shared `ApiClient.instance` used by tasks/calendar/services — currently points at the same `maintenanceBaseUrl` config as everything else but is a separately-configured client.
- **Domain entities**: `frontend/lib/features/maintenance/domain/entities/maintenance_request.dart` (`MaintenanceRequest`) — `id, title, priority (MaintPriority: low/medium/high/urgent), status (MaintStatus: open/inProgress/onHold/completed/cancelled), createdAt, description?, category?, leasingUnitId?, tenantId?, assignedTo?, estimatedCost?, actualCost?, scheduledDate?, completedDate?, notes?, photos: List<String>`.

## Backend
- Router: `backend/routers/maintenance.py`, mounted at `/api/v1/maintenance` (see `backend/main.py:56`).
- Key endpoints:
  - `GET /` — list, filterable by `status`, `priority`, `leasing_unit_id`.
  - `GET /{request_id}` — single request, including nested `maintenance_comments(*)`.
  - `POST /` — create (full `MaintenanceRequestIn`).
  - `PUT /{request_id}` — **full replace** update (`payload.model_dump()`, not `exclude_none` — see Known Issues).
  - `DELETE /{request_id}` — delete.
  - `POST /{request_id}/comments` — add a comment (`maintenance_comments` table).
  - `POST /{request_id}/photos` — upload image (JPEG/PNG/WebP/GIF, 10MB cap) to Supabase Storage bucket `MAINTENANCE_PHOTOS_BUCKET` (default `maintenance-photos`), falls back to inline base64 data URI if storage upload throws; appends URL to `photos[]`.
  - `DELETE /{request_id}/photos?photo_url=...` — removes a URL from `photos[]` (does not delete the underlying storage object).

## Database
- Tables (`supabase/migrations/001_initial_schema.sql:208`):
  - `maintenance_requests` — `id uuid pk, title, description, priority text default 'medium', status text default 'open', category, leasing_unit_id text fk->leasing_units, tenant_id uuid fk->tenants, assigned_to text, assigned_email text, estimated_cost float8, actual_cost float8, scheduled_date date, completed_date date, photos text[] default '{}', notes, created_at, updated_at`. Has an `updated_at` trigger.
  - `maintenance_comments` (`001_initial_schema.sql:233`) — `id uuid pk, request_id uuid fk->maintenance_requests on delete cascade, author_id uuid fk->profiles, body text not null, created_at`.

## Key patterns / architecture notes
- `MaintenanceRepository.updateStatus()` builds its PUT body from `req.toJson()` (the *current in-memory* request) with only the `status` field overwritten, then PUTs the whole object — this is a read-modify-write pattern done entirely client-side rather than a targeted PATCH.
- Filtering/search in `MaintenanceProvider.filtered` is entirely client-side over the already-loaded `_requests` list; the `status`/`priority`/`leasing_unit_id` query params on `GET /` exist server-side but the Dart repo's `getAll()` never passes them (called with no args from `MaintenanceProvider.load()`).
- Photo upload has a graceful-degradation path: if the Supabase Storage `.upload()` call throws (e.g. bucket missing/misconfigured), the backend silently falls back to embedding the image as a base64 `data:` URI directly in the `photos` array instead of failing the request.

## Recent changes (org-admin authorization hardening)
- All mutating `maintenance.py` endpoints — `POST/PUT/DELETE /`, `POST /{id}/comments`, `POST/DELETE /{id}/photos` — previously had zero auth and now require a `user_id` query param + `require_org_admin_for_unit`/`require_any_org_admin` (fallback when `leasing_unit_id` is null) via `backend/auth_utils.py`.
- `maintenance_repository.dart`'s `create()` and `updateStatus()` (the two live callers) now pass `Supabase.instance.client.auth.currentUser?.id` as `user_id`. Comments/photo endpoints have no frontend caller currently, so only the backend side changed for those.

## Known Issues
- **Data-loss bug via `MaintenanceRequest.toJson()` + full-replace `PUT`**: `toJson()` (`maintenance_request.dart:83-93`) only serializes `title, priority, status, description?, category?, leasing_unit_id?, assigned_to?, estimated_cost?, notes?` — it omits `tenant_id`, `actual_cost`, `scheduled_date`, `completed_date`. The backend's `PUT /{request_id}` does `payload.model_dump()` **without `exclude_none`** (`maintenance.py:88-99`), so any field missing from the Dart payload is written back as `NULL`. Net effect: every status change made from the UI (`updateStatus` in `maintenance_provider.dart:61`) silently wipes `tenant_id`, `actual_cost`, `scheduled_date`, and `completed_date` on that row if they were previously set. This is a real, currently-live bug — confirm before touching either side of this contract.
- No frontend UI exists for `scheduled_date`, `completed_date`, `actual_cost`, or `tenant_id` on maintenance requests, nor for comments (`maintenance_comments`/`POST /{request_id}/comments`) or photo upload/delete, despite full backend support for all of these. The screen only exposes title/description/category/assigned_to/priority on create, and status-only on update.
- `DELETE /{request_id}/photos` removes the URL from the DB array but never deletes the object from Supabase Storage — an orphaned-file leak (contrast with `service_requests.py`'s document delete, which does call `gcs.delete_object`).

## Related features
- **This is a genuinely separate system from "Services"** (`frontend/lib/features/services/`, `backend/routers/service_requests.py`, table `service_requests`), not a legacy/duplicate. Verified via router + nav:
  - `frontend/lib/core/router/app_router.dart` wires both `/maintenance` (line 108) and `/services` (line 118) as live, independently-reachable routes, alongside tenant-portal equivalents `/tenant/maintenance` and `/tenant/services`.
  - `frontend/lib/shared/widgets/sidebar_nav.dart` lists both `NavItem.maintenance` and `NavItem.services` as separate sidebar entries (services uses `Icons.home_repair_service_outlined`).
  - **Distinction**: `maintenance_requests` is a simple internal admin ticket log (no tenant workflow, no approval chain, no catalog) — admin creates, assigns, tracks status/cost, done. `service_requests` (see `backend/routers/service_requests.py`) is a considerably richer tenant-portal workflow: tenants (or admins on their behalf) request from a `service_catalog`, there's a two-party approval/decision flow (`expenses_borne_by` Owner vs Tenant determines who must sign off via `/tenant-decision` vs the admin `PATCH`), supporting documents stored in GCS, and status strings are capitalized (`Initiated`/`Approved`/`Review`/`Declined`/`Completed`) unlike maintenance's lowercase `open`/`in_progress`/etc.
  - Both are actively built out and neither appears to be dead/unused code — they serve different purposes (internal ops ticket vs. tenant-initiated billable service with sign-off).
- `calendar.md` — calendar events support an `event_type = "maintenance"` value, but no code path links a `maintenance_requests` row to an `events` row; the connection is naming-only.
