# Calendar

## Purpose
Month-grid calendar of property-management events (lease renewals, rent due dates, inspections, maintenance, meetings), with a one-click sync that auto-generates renewal/rent-due events from active leases and rent schedules.

## Frontend
- **Screens**: `frontend/lib/features/calendar/presentation/screens/calendar_screen.dart` — month grid + day-detail/upcoming sidebar, "New Event" dialog, "Sync Leases" button.
- **Providers**: `frontend/lib/features/calendar/presentation/providers/calendar_provider.dart` (`CalendarProvider`, extends `BaseProvider`) — owns `focusedMonth`, `selectedDay`, `_events` list; loads a 3-month window (prev/current/next month) around `focusedMonth` on `load()`/`nextMonth()`/`prevMonth()`.
- **Repositories**: `frontend/lib/features/calendar/data/repositories/calendar_repository.dart` (`CalendarRepository`) — calls `GET /api/v1/calendar/`, `GET /api/v1/calendar/upcoming`, `POST /api/v1/calendar/`, `DELETE /api/v1/calendar/{id}`, `POST /api/v1/calendar/sync-from-leases`. Uses `ApiClient.instance` (default Dio client).
- **Domain entities**: `frontend/lib/features/calendar/domain/entities/calendar_event.dart` (`CalendarEvent`) — `id, title, eventType (EventType enum: inspection/paymentDue/leaseRenewal/maintenance/meeting), startAt, endAt?, description?, allDay, leasingUnitId?, tenantId?`.

## Backend
- Router: `backend/routers/calendar.py`, mounted at `/api/v1/calendar` (see `backend/main.py:68`).
- Key endpoints:
  - `GET /` — list events, filterable by `start`, `end`, `event_type`, `leasing_unit_id`.
  - `GET /upcoming?days=30` — events between now and now+days.
  - `GET /{event_id}` — single event.
  - `POST /` — create event.
  - `PUT /{event_id}` — update event (no Dart repository method calls this yet — update is backend-only today).
  - `DELETE /{event_id}` — delete event.
  - `POST /sync-from-leases` — generates `lease_renewal` events (30 days before `leases.end_date` for active leases) and `payment_due` events (next 3 months from `rent_schedules`), de-duped via a pre-check query before each insert. Returns `{"events_created": N}`.

## Database
- Tables: `events` (`supabase/migrations/001_initial_schema.sql:273`) — `id uuid pk, title, description, event_type text, start_at timestamptz not null, end_at timestamptz, all_day bool, leasing_unit_id text fk->leasing_units, tenant_id uuid fk->tenants, created_by uuid fk->profiles, created_at, updated_at`. Has an `updated_at` trigger.
- Also reads (does not write, except via sync): `leases` (`id, tenant_id, leasing_unit_id, end_date, monthly_rent, status`) and `rent_schedules` (`id, lease_id, due_day, amount, is_active`).

## Key patterns / architecture notes
- `EventType` enum on the Dart side maps to snake_case strings on the wire (`_typeKey`/`_parseType` in `calendar_event.dart`); unknown/missing `event_type` defaults to `meeting`.
- `sync-from-leases` is idempotent-ish: before inserting a renewal/payment event it queries for an existing event of the same type/unit/date range, but the de-dupe check only looks at `start_at >=`/`<=` bounds, not an exact match — re-running sync repeatedly for the same lease will not obviously duplicate events but the logic is a heuristic, not a hard uniqueness constraint (no DB unique index backs this).
- `CalendarProvider.load()` always fetches a 3-month window centered on `focusedMonth` (prev, current, next), so `eventsForDay` only works reliably for days inside that window.
- The `_CreateEventDialog` in `calendar_screen.dart` only sets `startAt` to 9am on the picked date (`DateTime(_date.year, _date.month, _date.day, 9)`) and does not expose an `endAt` field or a time picker — all events created from the UI are effectively date-only regardless of the `allDay` checkbox value shown.

## Known Issues
- `EventUpdate` model and `PUT /{event_id}` endpoint exist in the backend but there is no corresponding method in `CalendarRepository` or any UI to edit an existing event — update is currently dead code from the frontend's perspective.
- No time picker in the create-event dialog — all-day toggle exists but start time is hardcoded to 9am for timed events too.

## Related features
- `tasks.md` — dashboard's "Tasks" widget links to `/calendar` for both "Add task" and "View all" (see `frontend/lib/features/dashboard/presentation/widgets/tasks_section.dart`), even though it displays hardcoded mock data unrelated to either calendar events or the tasks table — see tasks.md Known Issues.
- `maintenance.md` — calendar events support `event_type = "maintenance"` as a category but there is no code path that auto-creates calendar events from `maintenance_requests`; the two are only linked by the shared enum value, not by any actual data relationship.
