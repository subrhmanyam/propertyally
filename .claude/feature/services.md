# Services (Admin Service Requests)

## Purpose
Lets admins raise and manage maintenance/vendor-style service requests (plumbing, electrical, etc.) against a specific leasing unit, track them through a status workflow, and attach supporting documents (invoices/quotes/receipts). Shares its backend router with the tenant-portal "request a service" flow.

## Frontend
- **Screens**: `frontend/lib/features/services/presentation/screens/admin_services_screen.dart` — KPI strip + status filter chips + requests table; "New Request" dialog; per-row `_ServiceDetailDialog` for status/notes/documents; `_DocumentsDialog` for standalone doc management.
- **Providers**: `frontend/lib/features/services/presentation/providers/services_provider.dart` — owns `requests`, `catalog`, `units`, `isLoading`, `statusFilter`; exposes `load()`, `setFilter()`, `createRequest()`, `updateStatus()`, `updateDetails()`, `uploadDocument()`, `deleteDocument()`, `getCatalog()`.
- **Repositories**: `frontend/lib/features/services/data/repositories/services_repository.dart` — calls `GET /api/v1/service-requests/`, `GET /api/v1/service-catalog/`, `GET /api/v1/leasing/` (for the unit picker), `POST /api/v1/service-requests/admin`, `PATCH /api/v1/service-requests/{id}`, `POST /api/v1/service-requests/{id}/documents`, `DELETE /api/v1/service-requests/{id}/documents/{documentId}`.
- **Key widgets/dialogs**:
  - `_NewRequestDialog` — picks a Property/Unit (drives service-catalog filtering by unit category), a catalog service, description, priority, **Expenses Borne By** (Owner/Tenant dropdown), **Estimated Cost (₹)** text field, **Initiated Date** date picker. All wired straight into `createRequest(...)`.
  - `_ServiceDetailDialog` — read-only detail fields (Category, Property/Unit, Tenant, Priority, Requested By, Expenses Borne By, Estimated Cost, Initiated Date, Description) + editable Status dropdown + Admin Notes + document list/upload. Shows an "Awaiting X approval" banner when `approval_required_from` is set, and excludes `'Approved'` from the selectable statuses in that case.
  - `_DocsButton` / `_DocumentsDialog` / `_DocRow` — per-row doc count badge; upload via `file_picker` (`withData: true`); each doc row is clickable and opens `${ApiConfig.baseUrl}/api/v1/service-requests/documents/{docId}/download` via `url_launcher_string`.
  - `_StatusBadge` — color-codes each status.

## Backend
- Router: `backend/routers/service_requests.py`, mounted at `/api/v1/service-requests` (see `backend/main.py:66`). Companion catalog router `backend/routers/service_catalog.py` mounted at `/api/v1/service-catalog`.
- Key endpoints:
  - `POST /` (tenant, needs `user_id`) — tenant creates own request, `requested_by='Tenant'`, status forced to `'Initiated'`.
  - `GET /my` (tenant) — tenant's own requests with `service_catalog`, `leasing_units`, `documents` joined.
  - `PATCH /{request_id}/tenant-decision` (tenant) — tenant Approves/sends-to-Review/Declines an owner-initiated, tenant-funded request; 403 if not their request, 409 if not awaiting their approval.
  - `POST /admin` — admin creates a request for any unit (`AdminServiceRequestIn`: `leasing_unit_id`, `service_id`/`service_name`, `description`, `priority`, `tenant_id?`, `expenses_borne_by?`, `estimated_cost?`, `initiated_date?`); auto-links `tenant_id` from the unit if not given; `requested_by='Owner'`, status `'Initiated'`.
  - `GET /` (admin) — list all requests, optional `status`/`unit_id` filters, joins `service_catalog(name, category)`, `tenants(first_name, last_name)`, `leasing_units(name)`, `documents(*)`.
  - `GET /{request_id}` — single request, same joins.
  - `PATCH /{request_id}` (admin/owner) — `ServiceRequestUpdate`: `status`, `assigned_to`, `scheduled_at`, `admin_notes`, `tenant_rating`, `expenses_borne_by`, `estimated_cost`, `initiated_date`. Blocks `status='Approved'` with 409 if the approver-of-record is `'Tenant'` (must go through `/tenant-decision` instead). Sets `completed_at=now()` when status becomes `'Completed'`.
  - `POST /{request_id}/documents` — multipart upload (`UploadFile`), 20 MB cap, uploads to GCS via `gcs.upload_bytes(org_id, category="expense", ...)`, inserts a row into `documents` with `service_request_id` set.
  - `GET /documents/{document_id}/download` — **download-proxy**: reads `documents.storage_path`, streams bytes back via `gcs.download_bytes()` in a `Response`, does NOT expose the stored `file_url`/signed GCS URL to the client. Comment in code explains why (avoids leaking bucket/object path / a working credential).
  - `DELETE /{request_id}/documents/{document_id}` — deletes the `documents` row, then best-effort deletes the GCS object.
- Document upload pattern: **direct multipart-through-backend** (not client-side signed URLs) for upload; **backend proxy stream** for download. This differs from the property-photos upload pattern elsewhere in the app — verify against `properties.md` if reusing.

## Database
- `service_catalog` (003_tenant_portal.sql): `id`, `name`, `category`, `description`, `property_types text[]`, `typical_sla_hours`, `is_active`, `created_at`.
- `service_requests` (003_tenant_portal.sql, extended by 008 and 009):
  - Base (003): `id`, `leasing_unit_id` (FK → `leasing_units.id`, TEXT), `tenant_id` (FK → `tenants.id`, UUID), `service_id`, `service_name`, `description`, `priority` ('normal'|'urgent' originally — UI now also uses 'high'), `status` (originally defaulted `'open'`), `photos text[]`, `assigned_to`, `scheduled_at`, `completed_at`, `tenant_rating`, `admin_notes`, `created_at`, `updated_at` (trigger-maintained).
  - 008_service_request_details.sql adds: `expenses_borne_by text` (check: `Owner`/`Tenant`/null), `estimated_cost numeric`, `initiated_date timestamptz not null default now()`; **overrides `status` default to `'Initiated'`** and adds check constraint `status in ('Initiated','Review','Approved','In progress','Completed','Declined')`.
  - 009_service_request_workflow.sql adds: `requested_by text not null default 'Owner'` (check: `Owner`/`Tenant`) — who initiated the request, used together with `expenses_borne_by` to compute the approval gate.
- `documents` (001_initial_schema.sql, extended by 004 and 009): `id`, `name`, `type`, `file_url`, `file_size`, `leasing_unit_id`, `tenant_id`, `uploaded_by`, `created_at`; 004 adds `org_id`, `storage_path` (GCS object path, for regenerating signed URLs / server-side reads); 009 adds `service_request_id uuid references service_requests(id) on delete cascade` + index. Row-shape for service-request docs: `type='expense'`.
- `service_requests.leasing_unit_id` and `.tenant_id` are both populated — every request is scoped to a unit, and (when resolvable) to the tenant occupying it.

## Key patterns / architecture notes
- **Exact current status vocabulary (verified in code, both frontend and DB constraint agree):** `Initiated`, `Review`, `Approved`, `In progress`, `Completed`, `Declined` — capitalized exactly as shown, "In progress" has a lowercase "p". This is the newer workflow; the original `open/in_progress/on_hold/completed/cancelled`-style lowercase vocabulary from 003_tenant_portal.sql's default (`'open'`) has been superseded by 008's constraint and default (`'Initiated'`). Defined in `admin_services_screen.dart:298-305` (`_RequestsTable._statuses`) and mirrored in the filter-chip list at lines 81-89.
- **Approval workflow exists and is enforced server-side**, not just a frontend hint:
  - Business rule (`backend/routers/service_requests.py:32-43`, `_approver_for`): if `requested_by != expenses_borne_by` (i.e., the person who asked for the work isn't the one paying for it), the paying party must approve. `approval_required_from` = that party (`'Owner'` or `'Tenant'`), else `null`.
  - Every response-shaping function (`_with_approval`) attaches computed `approval_required_from` to each returned row — it is NOT a DB column, it's computed per-request in Python from `requested_by` + `expenses_borne_by`.
  - Server enforcement: `PATCH /{request_id}` (admin/owner path) returns 409 if trying to set `status='Approved'` while `approval_required_from == 'Tenant'`; the tenant must instead call `PATCH /{request_id}/tenant-decision` (own endpoint, checks `tenant_id` ownership + that they are in fact the required approver).
  - Frontend mirrors this: in both `_RequestRow` and `_ServiceDetailDialog`, when `approval_required_from == 'Tenant'`, `'Approved'` is stripped from the selectable status list and an hourglass "Awaiting {party} approval" badge/banner is shown.
- **estimated_cost and initiated_date exist** on both the DB table (008) and the admin "New Request" form (`_NewRequestDialog`: `_costCtrl` free-text ₹ field parsed with `double.tryParse`, `_initiatedDate` via `showDatePicker`) and are also editable/visible in `_ServiceDetailDialog`'s field grid (display-only there; not currently editable inline — only `status` and `admin_notes` are saved by `_ServiceDetailDialogState._save()`).
- Document handling: multipart upload straight through the FastAPI backend to GCS (no client-side signed-URL flow), org resolved via the request's `leasing_unit_id → leasing_units.org_id`. Downloads are proxied through the backend (`/documents/{id}/download`) rather than redirecting to a stored `file_url`, explicitly to avoid leaking the GCS bucket/path as a de-facto public credential.
- Priority values used in the UI: `'normal' | 'high' | 'urgent'` (`_NewRequestDialog` dropdown) — note the DB comment in 003 only documented `normal|urgent`; `'high'` is a UI-only addition not reflected in any DB check constraint (there is no check constraint on `priority` at all, so this is fine, just worth knowing there's no source-of-truth doc for the full priority set beyond the Dart code).

## Known Issues
- `_ServiceDetailDialogState._save()` only persists `status` and `admin_notes` (`admin_services_screen.dart:905-917`) even though the dialog displays Requested By, Expenses Borne By, Estimated Cost, and Initiated Date as if editable-context fields — those four are read-only display in this dialog; there's no UI path to edit them after creation. Confirm this is intended before assuming it's a gap.
- No DB check constraint on `priority` (only `status`, `expenses_borne_by`, `requested_by` have check constraints per migrations 008/009) — `'high'` used by the frontend is not enforced/validated at the DB layer.
- `service_requests.priority` default in schema is `'normal'` with an inline comment listing only `normal | urgent` (003_tenant_portal.sql:34) — stale comment, doesn't mention `'high'`.

## Related features
- tenant-portal.md (tenant-side service request submission — `frontend/lib/features/tenant/presentation/screens/tenant_services_screen.dart` and `frontend/lib/features/tenant/data/repositories/tenant_repository.dart` — calls the same `backend/routers/service_requests.py` endpoints: `POST /api/v1/service-requests/`, `GET /api/v1/service-requests/my`, `PATCH /api/v1/service-requests/{id}/tenant-decision`, and the same documents upload/download/delete endpoints)
- properties.md (service requests are scoped to a `leasing_unit_id`; documents also resolve `org_id` via `leasing_units.org_id`)
