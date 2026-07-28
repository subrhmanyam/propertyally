# Calendar

## Purpose
Month-grid calendar of property-management events (lease renewals, rent due dates, inspections, maintenance, meetings), with a one-click sync that auto-generates renewal/rent-due events from active leases and rent schedules.

## Frontend
- **Screens**: `frontend/lib/features/calendar/presentation/screens/calendar_screen.dart` — month grid + day-detail/upcoming sidebar, "New Event" dialog, "Sync Leases" button. Now a `StatefulWidget` (`_CalendarScreenState.initState` calls `context.read<CalendarProvider>().load()`) — see Recent changes below for why.
- **Widgets**: `frontend/lib/features/calendar/presentation/widgets/create_event_dialog.dart` — `CreateEventDialog({required CalendarProvider provider})`, a public/shared widget extracted from what used to be a private `_CreateEventDialog` inside `calendar_screen.dart`. Used by both the calendar screen's "New Event" button and the dashboard's "Add Event" action (`dashboard.md`'s `EventsSection`).
- **Providers**: `frontend/lib/features/calendar/presentation/providers/calendar_provider.dart` (`CalendarProvider`, extends `BaseProvider`) — owns `focusedMonth`, `selectedDay`, `_events` list; loads a 3-month window (prev/current/next month) around `focusedMonth` on `load()`/`nextMonth()`/`prevMonth()`. **Now registered globally** in `main.dart`'s `MultiProvider`, not created locally per-screen — see Recent changes below.
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
- `CreateEventDialog` (`create_event_dialog.dart`) only sets `startAt` to 9am on the picked date (`DateTime(_date.year, _date.month, _date.day, 9)`) and does not expose an `endAt` field or a time picker — all events created from the UI are effectively date-only regardless of the `allDay` checkbox value shown.

## Recent changes (org-admin authorization hardening)
- `POST /`, `PUT /{event_id}`, `DELETE /{event_id}`, and `POST /sync-from-leases` previously had zero auth. Create/update/delete now require a `user_id` query param + `require_org_admin_for_unit`/`require_any_org_admin` (fallback when `leasing_unit_id` is null, e.g. a general meeting); `sync-from-leases` is a cross-org bulk job so it just requires `require_any_org_admin`. See `backend/auth_utils.py`.
- `CalendarRepository.createEvent()`, `deleteEvent()`, `syncFromLeases()` now pass `Supabase.instance.client.auth.currentUser?.id` as `user_id`. `updateEvent`/`PUT` has no frontend caller (see Known Issues below), so only the backend side changed for that one.

## Recent changes (dashboard Events feed + provider globalization)
- **`CalendarProvider` moved from screen-local to app-global.** It used to be created fresh every time `calendar_screen.dart` mounted, via a `ChangeNotifierProvider(create: (_) => CalendarProvider()..load())` wrapper local to that screen. It's now registered once in `main.dart`'s `MultiProvider` (eager `..load()` at app start, same pattern as `InvoiceSettingsProvider`) so the dashboard's new `EventsSection` (see `dashboard.md`) can share the same events state instead of maintaining a disconnected duplicate. `calendar_screen.dart` was converted to a `StatefulWidget` that re-triggers `.load()` in `initState` on every visit, preserving the old "always fresh on screen visit" behavior against the now-shared instance.
- **`_CreateEventDialog` extracted** from a private class in `calendar_screen.dart` into the public, shared `CreateEventDialog` (`create_event_dialog.dart`) — same fields/behavior, now usable from both the calendar screen and the dashboard.
- **Fixed a real backend bug found while wiring this up**: `list_events`/`upcoming_events` (`GET /` and `GET /upcoming`) called `sb.table("events").select("*").order("start_at", ascending=True)` — the installed `postgrest` version's `order()` only accepts a `desc` bool, not `ascending`, so **both endpoints 500'd on every single call**. This had gone unnoticed because nothing exercised them meaningfully before `EventsSection`/the newly-eager `CalendarProvider` load started hitting them at app startup. Fixed to `.order("start_at", desc=False)`.

## Known Issues
- `EventUpdate` model and `PUT /{event_id}` endpoint exist in the backend but there is no corresponding method in `CalendarRepository` or any UI to edit an existing event — update is currently dead code from the frontend's perspective.
- No time picker in the create-event dialog — all-day toggle exists but start time is hardcoded to 9am for timed events too.

## Related features
- `dashboard.md` — the dashboard's `EventsSection` (replacing the old, now-deleted `tasks_section.dart`, which displayed hardcoded mock data unrelated to either calendar events or the tasks table) merges upcoming calendar events with open service requests, and its "Add Event" action opens this feature's `CreateEventDialog` against the shared global `CalendarProvider`.
- `maintenance.md` — calendar events support `event_type = "maintenance"` as a category but there is no code path that auto-creates calendar events from `maintenance_requests`; the two are only linked by the shared enum value, not by any actual data relationship.
