# Dashboard

## Purpose
The admin landing page (route `/`), rendered inside `AppShell`. Intended as an
aggregation/overview screen (today's reminders, tasks, recently viewed
properties, accounting summary) composed from other features' data.

## Frontend
- **Screens/Widgets**:
  - `frontend/lib/features/dashboard/presentation/screens/dashboard_screen.dart` — top-level screen; lays out a 2-column desktop / stacked mobile layout (`Responsive.isMobile`) using `TodayCard`, `TasksSection`, `RecentlyViewedSection`, `AccountingSection`. Rendered as the child of `AppShell`'s `ShellRoute` — does not wrap itself in `AppShell`.
  - `frontend/lib/features/dashboard/presentation/widgets/today_card.dart` — header banner ("Today, reminders") + an onboarding-progress card (circular progress ring, "Market your property" CTA linking to `/properties`). Purely presentational, takes `DashboardData data` as a constructor param.
  - `frontend/lib/features/dashboard/presentation/widgets/tasks_section.dart` — list of `DashboardTask` rows with a fake local checkbox (`_checked` state, not persisted anywhere). "Add task"/"View all" link to `/calendar`.
  - `frontend/lib/features/dashboard/presentation/widgets/recently_viewed_section.dart` — 2-column grid of `RecentProperty` tiles; tapping any tile navigates to `/properties` (not to the specific property). Shows an empty-state ("No recently viewed properties") when the list is empty.
  - `frontend/lib/features/dashboard/presentation/widgets/accounting_section.dart` — bar chart (via `fl_chart`) of `AccountingMonth` income/expense plus two summary tiles (Income/Expenses); tiles and "View all" link to `/accounting`.
- **Providers**: **none**. No widget in this feature imports `provider`, calls `context.watch`/`context.read`, or references `Consumer<...>`. Confirmed by grep — zero `Provider>()` references across all 5 dashboard files.
- **Repositories**: none.
- **Domain entities**: `frontend/lib/features/dashboard/domain/entities/dashboard_data.dart` —
  - `RecentProperty(name, address, status: PropertyStatus, imageUrl?)`
  - `DashboardTask(title, propertyName, propertyAddress, isRecurring, avatarInitial)`
  - `AccountingMonth(month, income, expense)`
  - `DashboardData(todayDate, reminderCount, onboardingProgress, onboardingStep, onboardingTotal, recentProperties, tasks, accountingMonths, totalIncome, totalExpenses)` — also defines a `static const DashboardData.mock` with realistic sample data (9 mock properties, 4 mock tasks, 9 months of chart data), but this mock is **not used anywhere** in the current screen.

## Backend
- Router: none. No `dashboard.py` (or similarly named file) exists under `backend/routers/`, and `backend/main.py`'s router include list has no dashboard entry.

## Database
- Tables: none directly — this screen is designed as a pure aggregation view over other features' data (accounting, tasks/calendar, properties), but as currently wired it doesn't actually pull from any of them (see Known Issues).

## Key patterns / architecture notes
- **Currently a static/disconnected screen, not a real aggregation view.** `_DashboardBody` in `dashboard_screen.dart:24-35` hardcodes its own empty `DashboardData` literal (`todayDate: ''`, `reminderCount: 0`, all lists `[]`, `totalIncome/Expenses: 0`) instead of using `DashboardData.mock` or fetching from `AccountingProvider`/`TasksProvider`/`PropertiesProvider`/etc. `RecentlyViewedSection` is also hardcoded to `properties: []` directly in both `_DesktopLayout` and `_MobileLayout` rather than being fed `data.recentProperties`.
- The other feature providers this screen *should* logically compose (based on the widgets present) are registered app-wide in `main.dart` — `AccountingProvider`, `TasksProvider`, `PropertiesProvider`, `LeasingProvider` — but the dashboard widgets never read them. Any future wiring work should inject `Consumer`/`context.watch` calls for these into `dashboard_screen.dart` and pass real data down instead of the current empty literal.
- Navigation is the one "live" piece of behavior: every section's "View all" affordance correctly deep-links to the corresponding real feature route (`/calendar`, `/accounting`, `/properties`), so the screen is wired for navigation but not for data.
- All chart/currency formatting uses `intl`'s `NumberFormat` (`AccountingSection` uses `en_IN`/`₹` for summary tiles but a plain `$` symbol inside the bar-chart tooltip — inconsistent currency symbol between the two, worth normalizing if this is picked back up).

## Known Issues
- `frontend/lib/features/dashboard/presentation/screens/dashboard_screen.dart:24-35` — screen renders an all-empty `DashboardData` instead of live or even mock data; as a result the dashboard currently shows no reminders, no tasks, no recently-viewed properties, and a zeroed-out accounting chart/tiles for every user, always.
- `TasksSection`'s per-row checkbox (`tasks_section.dart:94-96`, `_checked` local `State`) has no persistence/backend call — toggling it is purely cosmetic and resets on rebuild/navigation.
- `RecentlyViewedSection` tile taps go to the generic `/properties` list, not a specific property detail route — likely a placeholder pending a real "recently viewed" tracking mechanism (would need a data source, e.g. a local/analytics table, none of which currently exists).
- Given this session's noted history of silent reverts, re-check `dashboard_screen.dart` for provider wiring before assuming any prior "live dashboard" work still exists — as of this review it does not.

## Related features
- `frontend/lib/features/accounting/` (`AccountingProvider`) — logical data source for `AccountingSection`, not currently wired.
- `frontend/lib/features/tasks/` and `frontend/lib/features/calendar/` (`TasksProvider`) — logical data source for `TasksSection`; "Add task"/"View all" both route to `/calendar`.
- `frontend/lib/features/properties/` (`PropertiesProvider`/`LeasingProvider`) — logical data source for `RecentlyViewedSection` and the onboarding CTA.
- `frontend/lib/shared/widgets/app_shell.dart` — the shell this screen is rendered inside; see `.claude/feature/auth.md` for how users are routed to `/` (admin) vs `/tenant`.
