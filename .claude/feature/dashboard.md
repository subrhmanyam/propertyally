# Dashboard

## Purpose
The admin landing page (route `/`), rendered inside `AppShell`. Intended as an
aggregation/overview screen (today's reminders, tasks, recently viewed
properties, accounting summary) composed from other features' data.

## Frontend
- **Screens/Widgets**:
  - `frontend/lib/features/dashboard/presentation/screens/dashboard_screen.dart` — top-level screen; lays out a 2-column desktop / stacked mobile layout (`Responsive.isMobile`) using `TodayCard`, `EventsSection`, `RecentlyViewedSection`, `AccountingSection`. Rendered as the child of `AppShell`'s `ShellRoute` — does not wrap itself in `AppShell`.
  - `frontend/lib/features/dashboard/presentation/widgets/today_card.dart` — header banner ("Today, reminders") + an onboarding-progress card (circular progress ring, "Market your property" CTA linking to `/properties`). Purely presentational, takes `DashboardData data` as a constructor param.
  - `frontend/lib/features/dashboard/presentation/widgets/events_section.dart` — **real, live data** (see Recent changes below): a merged feed of upcoming Calendar Events, open Service Requests, and open Tasks, with an "Add Event" action. Replaces the old `tasks_section.dart` (deleted), which rendered fake `DashboardTask` rows with a client-only checkbox.
  - `frontend/lib/features/dashboard/presentation/widgets/recently_viewed_section.dart` — 2-column grid of `RecentProperty` tiles; tapping any tile navigates to `/properties` (not to the specific property). Shows an empty-state ("No recently viewed properties") when the list is empty. **Still disconnected** — hardcoded to `properties: []`, not part of this round of changes.
  - `frontend/lib/features/dashboard/presentation/widgets/accounting_section.dart` — bar chart (via `fl_chart`) of `AccountingMonth` income/expense plus two summary tiles (Income/Expenses); tiles and "View all" link to `/accounting`. **Still disconnected**, not part of this round of changes.
- **Providers**: `EventsSection` reads `CalendarProvider`, `ServicesProvider`, and `TasksProvider` via `context.watch`/`context.read` — the first real provider usage in this feature. The other three widgets still take no providers.
- **Repositories**: none directly (consumed indirectly through `CalendarProvider`/`ServicesProvider`).
- **Domain entities**: `frontend/lib/features/dashboard/domain/entities/dashboard_data.dart` —
  - `RecentProperty(name, address, status: PropertyStatus, imageUrl?)`
  - `AccountingMonth(month, income, expense)`
  - `DashboardData(todayDate, reminderCount, onboardingProgress, onboardingStep, onboardingTotal, recentProperties, accountingMonths, totalIncome, totalExpenses)` — the `tasks`/`DashboardTask` field and class were removed (their only consumer, `TasksSection`, no longer exists). Still defines a `static const DashboardData.mock` (8 mock properties, 9 months of chart data) that is **not used anywhere** in the current screen.

## Backend
- Router: none. No `dashboard.py` (or similarly named file) exists under `backend/routers/`, and `backend/main.py`'s router include list has no dashboard entry. `EventsSection` reads from the existing `calendar.py`/`service_requests.py` routers via their respective providers, not a dashboard-specific endpoint.

## Database
- Tables: none directly owned by this feature. `EventsSection` indirectly reads `events` (via `CalendarProvider`) and `service_requests` (via `ServicesProvider`).

## Recent changes (real "Events" feed + create-event action)
- **`EventsSection` is the first genuinely live section on this screen.** It merges `CalendarProvider.upcomingEvents` (already future-sorted, capped at 10), `ServicesProvider.requests` filtered to exclude `Completed`/`Declined`, and `TasksProvider.tasks` filtered to exclude `completed`/`cancelled` — all three combined into a small private `_DashboardEventItem` type (kept local to `events_section.dart`, not a domain entity, since it's a pure presentation-merge artifact) and sorted ascending by date (service requests by `initiated_date ?? created_at`; calendar events by `startAt`; tasks by `dueDate ?? createdAt`), showing the top 8. Calendar-event rows navigate to `/calendar`; service-request rows navigate to `/services?request_id={id}` (reusing the notification deep-link mechanism already built in `admin_services_screen.dart`, opening that request's detail dialog directly); task rows navigate to `/tasks` (no per-task deep link exists there yet).
- **Tasks were initially left out of the merge on purpose** (confirmed with the user that "task can be a calendar event and also a service request" first meant a display merge of just those two, not a schema change linking the `tasks` table itself to calendar events) **but were added in a follow-up** after the user created a real task and expected to see it here — re-confirmed and added. The backend's `related_service_request_id` field on `tasks.py`'s `TaskIn` remains separately unused/unwired drift, still out of scope.
- **`CalendarProvider` is now globally registered** in `main.dart`'s `MultiProvider` (`ChangeNotifierProvider(create: (_) => CalendarProvider()..load())`) instead of being created locally inside `calendar_screen.dart`. The calendar screen (converted to `StatefulWidget`) now re-triggers `.load()` in its own `initState` on top of the eager app-start load, matching how every other feature provider refreshes on screen visit. `EventsSection` also defensively re-triggers `.load()` on `CalendarProvider`, `ServicesProvider`, and `TasksProvider` if their data is still empty on mount, since the very first eager load at app startup can race with the app's network/auth bootstrap and silently fail with no retry otherwise.
- **"Add Event" action**: the calendar screen's existing create-event dialog (previously a private `_CreateEventDialog` in `calendar_screen.dart`) was extracted, unchanged in behavior, into a shared public widget — `frontend/lib/features/calendar/presentation/widgets/create_event_dialog.dart` → `CreateEventDialog({required CalendarProvider provider})`. Both the calendar screen's "New Event" button and the dashboard's "Add Event" link now open the same dialog against the same globally-shared `CalendarProvider`, so an event created from the dashboard immediately shows up on `/calendar` too (and vice versa).
- **Found and fixed real, pre-existing backend bugs while wiring this up**:
  1. `backend/routers/calendar.py`'s `list_events`/`upcoming_events` (`GET /` and `GET /upcoming`) called `.order("start_at", ascending=True)` — the installed `postgrest` version's `order()` only accepts `desc` (bool), not `ascending`, so both endpoints 500'd on every call. Fixed to `.order("start_at", desc=False)`. The same bug pattern existed in `backend/routers/tasks.py`'s `list_tasks` and was fixed too.
  2. The `tasks` table **did not exist at all** in the live Supabase database — `backend/routers/tasks.py` had always assumed it existed, but no migration ever created it, so `GET`/`POST /api/v1/tasks/` (including the "New Task" button on `/tasks`) had never actually worked. Added `supabase/migrations/011_tasks.sql`; user ran it and confirmed both listing and creating tasks now work. See `tasks.md`.
- Deliberately still **not** part of this change: `RecentlyViewedSection` and `AccountingSection` remain fully disconnected (hardcoded/empty).

## Key patterns / architecture notes
- Navigation is still the most consistently "live" piece of behavior across all four sections: every section's "View all"/action affordance correctly deep-links to the corresponding real feature route (`/calendar`, `/accounting`, `/properties`, and now `/services?request_id=...` from `EventsSection`'s service-request rows).
- All chart/currency formatting uses `intl`'s `NumberFormat` (`AccountingSection` uses `en_IN`/`₹` for summary tiles but a plain `$` symbol inside the bar-chart tooltip — inconsistent currency symbol between the two, worth normalizing if this is picked back up).

## Known Issues
- `RecentlyViewedSection`/`AccountingSection` remain hardcoded/disconnected from real data (`RecentlyViewedSection(properties: [])` literal in both `_DesktopLayout`/`_MobileLayout`; `AccountingSection` reads only from the still-empty `DashboardData` literal in `_DashboardBody`) — not part of this round of changes, see Recent changes above for what was fixed.
- `RecentlyViewedSection` tile taps go to the generic `/properties` list, not a specific property detail route — likely a placeholder pending a real "recently viewed" tracking mechanism (would need a data source, e.g. a local/analytics table, none of which currently exists).
- Given this session's noted history of silent reverts, re-check `dashboard_screen.dart`/`events_section.dart` for provider wiring before assuming any prior "live dashboard" work still exists.

## Related features
- `frontend/lib/features/calendar/` (`CalendarProvider`, now globally registered), `frontend/lib/features/services/` (`ServicesProvider`), and `frontend/lib/features/tasks/` (`TasksProvider`) — the three real data sources merged into `EventsSection`; see `calendar.md`/`services.md`/`tasks.md`.
- `frontend/lib/features/accounting/` (`AccountingProvider`) — logical data source for `AccountingSection`, not currently wired.
- `frontend/lib/features/properties/` (`PropertiesProvider`/`LeasingProvider`) — logical data source for `RecentlyViewedSection` and the onboarding CTA, not currently wired.
- `frontend/lib/shared/widgets/app_shell.dart` — the shell this screen is rendered inside; see `.claude/feature/auth.md` for how users are routed to `/` (admin) vs `/tenant`.
