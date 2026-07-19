# Reports

## Purpose
Real-time analytics dashboard with five report types (occupancy, cash flow, rent collection, maintenance costs, profit & loss). All computation happens server-side on each request — nothing is precomputed or cached in a table.

## Frontend
- **Screens/Widgets**: `frontend/lib/features/reports/presentation/screens/reports_screen.dart` — single `ReportsScreen` with a horizontal tab bar (`ReportTab` enum: occupancy, cashFlow, rentCollection, maintenanceCosts, profitLoss) switching between five tab bodies. Registered at route `/reports` in the app router (`frontend/lib/core/router/*.dart`, line ~123). Uses `fl_chart` for bar charts (cash flow monthly income/expense, P&L monthly), custom `_HorizontalBarSection`/`_SimpleTable`/`_KpiCard` widgets for the rest. All amounts formatted with `NumberFormat.currency(symbol: '₹', locale: 'en_IN')`.
- **Providers**: `frontend/lib/features/reports/presentation/providers/reports_provider.dart` — `ReportsProvider extends BaseProvider`. Owns `activeTab` and one nullable report object per tab (`occupancy`, `cashFlow`, `rentCollection`, `maintenanceCosts`, `profitLoss`). `selectTab()` lazy-loads a tab only if its data is still null (simple per-tab cache for the provider's lifetime); `refresh()` nulls all five and reloads the active tab. No cross-tab prefetching — switching tabs triggers a new network call unless already cached in this provider instance.
- **Repositories**: `frontend/lib/features/reports/data/repositories/reports_repository.dart` — thin wrapper over `ApiClient` (Dio), one method per report hitting `GET /api/v1/reports/data/{occupancy,cash-flow,rent-collection,maintenance-costs,profit-loss}`. `cashFlow`/`maintenanceCosts` take a `months` param (default 12); `rentCollection`/`profitLoss` take optional `year`/`month`. **Note**: the UI never actually passes custom year/month/months values — `reports_screen.dart` and `reports_provider.dart` only call the zero-arg/default forms, so period filtering exists in the API and DTOs but has no UI control wired up yet.
- **Domain entities**: `frontend/lib/features/reports/domain/entities/report_data.dart` — plain immutable classes with `fromJson` factories, one per report:
  - `OccupancyReport` (totalUnits, occupied, vacant, inHouse, ownerOccupied, occupancyRate, byCategory: List<OccupancyBreakdown>, byFloor: List<OccupancyBreakdown>)
  - `CashFlowReport` (totalIncome, totalExpenses, net, months: List<MonthlyFlow>)
  - `RentCollectionReport` (period, collected, pending, overdue, total, collectionRate, byUnit: List<UnitRentSummary>)
  - `MaintenanceCostReport` (totalRequests, totalActualCost, totalEstimatedCost, byStatus: Map<String,int>, byCategory: List<CategoryCost>, byMonth: List<MonthCost>, byUnit: List<UnitCost>)
  - `ProfitLossReport` (periodStart, periodEnd, totalIncome, totalExpenses, netProfit, profitMargin, byMonth: List<MonthlyFlow>, byUnit: List<UnitPL>)

## Backend
- Router: `backend/routers/reports.py`, mounted at `/api/v1/reports` (see `backend/main.py` line 60).
- Key endpoints:
  - `GET /api/v1/reports/` — list saved report records (legacy/unused CRUD, table `reports`)
  - `GET /api/v1/reports/{report_id}` — fetch one saved report
  - `POST /api/v1/reports/` — create a saved report record
  - `DELETE /api/v1/reports/{report_id}` — delete a saved report record
  - `GET /api/v1/reports/data/occupancy` — unit counts by status/category/floor
  - `GET /api/v1/reports/data/cash-flow?months=N` — monthly income vs expense totals from `transactions`
  - `GET /api/v1/reports/data/rent-collection?year=&month=` — rent-category income transactions bucketed by status (paid/pending/overdue), per-unit breakdown
  - `GET /api/v1/reports/data/maintenance-costs?months=N` — spend by category/status/month/unit from `maintenance_requests`
  - `GET /api/v1/reports/data/profit-loss?year=&months=N` — income vs expenses per month and per unit

## Database
- **All five `/data/*` endpoints compute in Python from raw rows fetched via the Supabase client — there is no SQL aggregation (no `.rpc()`, no Postgres views/functions).** Each endpoint pulls the relevant table(s) with `select(...)`/`.eq()`/`.gte()`/`.lte()` filters, then does grouping/summing with plain Python (`collections.defaultdict`) before returning JSON.
- Tables queried:
  - `leasing_units` (id, name, company_name, category, floor, status) — occupancy report, and unit-name lookups for rent-collection/maintenance-costs/profit-loss
  - `transactions` (type, amount, date, category, status, leasing_unit_id, tenant_id, description) — cash-flow, rent-collection (filtered `type=income, category=Rent`), profit-loss
  - `maintenance_requests` (id, category, status, actual_cost, estimated_cost, created_at, leasing_unit_id) — maintenance-costs report
  - `reports` (name, type, filters, generated_by, generated_at) — legacy saved-report CRUD only, unrelated to the five analytics endpoints

## Key patterns / architecture notes
- Report computation is entirely request-time/server-side but **not SQL-aggregated** — every row in the relevant date range is pulled to the FastAPI process and reduced in Python. This is fine at current data volumes but will not scale well; a future migration to Postgres views/RPC would reduce payload size and latency.
- `_last_n_months(n)` / `_month_key()` / `_month_label()` helpers in `reports.py` generate contiguous month buckets (so months with zero transactions still appear as zero, not missing) — used by cash-flow, maintenance-costs, and profit-loss (non-year-filtered) paths.
- The five report DTOs are independent (no shared base class) but follow the same shape convention: totals/KPIs at top level + one or more `by_x: List<...>` breakdowns.
- `ReportsProvider` caches per-tab in memory for the provider's lifetime (until `ReportsScreen` is disposed/rebuilt or `refresh()` is called) — navigating away and back to `/reports` creates a fresh `ReportsProvider` (see `ReportsScreen.build`: `ChangeNotifierProvider(create: (_) => ReportsProvider()..loadAll())`), so caching does not persist across screen visits.

## Known Issues
- Period-filter params (`year`, `month`, `months`) are fully implemented on the backend and in `ReportsRepository`, but the UI (`reports_screen.dart`) never surfaces controls to set them — every report always requests its default period (last 12 months / current year+month). Confirm before assuming a "change period" UI exists anywhere.
- Backend aggregation is done client-side-in-Python (fetches full row sets), not via SQL — see note above. Could become a performance concern as `transactions`/`maintenance_requests` grow.
- No pagination/limit on the raw table fetches in any `/data/*` endpoint (e.g. `cash_flow_report` pulls all transactions since `start_date` with no cap).

## Related features
- `.claude/feature/search.md` — same `ApiClient`/Dio pattern for calling the backend; both features read from `leasing_units`, `transactions`-adjacent, and `maintenance_requests` tables.
- Tenants feature (`frontend/lib/features/tenants/`) — `transactions` referenced by `tenant_id` and `leasing_unit_id`, relevant to rent-collection and profit-loss reports.
