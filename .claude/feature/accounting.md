# Accounting

## Purpose
Tracks income/expense transactions (rent, maintenance, etc.) tied to leases/tenants/units, shows KPI summaries (income, expenses, net, outstanding rent), and can bulk-generate this month's rent transactions ("invoices") for all active leases.

## Frontend
- **Screens/Dialogs**: `frontend/lib/features/accounting/presentation/screens/accounting_screen.dart` — KPI cards, filter chips (All/Income/Expenses/Rent Roll), search, desktop table / mobile card list of transactions, header buttons "Generate Invoices" and "Add Transaction".
- **Providers**: `frontend/lib/features/accounting/presentation/providers/accounting_provider.dart` — owns `List<Transaction>`, active `AccountingFilter`, search query, `isGenerating` flag; computes `filtered`, `totalIncome`, `totalExpenses`, `netIncome`, `outstandingRent` client-side from the loaded list (no server-side aggregation used by the UI even though a `/summary` endpoint exists — see Known Issues).
- **Repositories**: `frontend/lib/features/accounting/data/repositories/accounting_repository.dart` — Dio calls to `/api/v1/accounting/transactions` (GET, filterable by type/status/leasing_unit_id/date range), `/api/v1/accounting/summary` (GET, unused by provider), `/api/v1/accounting/invoices/generate` (POST), `/api/v1/accounting/transactions/{id}/status` (PATCH, mark paid).
- **Domain entities/models**: `frontend/lib/features/accounting/domain/entities/transaction.dart` — `Transaction` (id, type: income|expense, category, amount, date, description, status: paid|pending|overdue, propertyId/propertyName, tenantId/tenantName, leaseId, referenceNo, notes). `fromJson` maps DB column `leasing_unit_id` (falls back to legacy `property_id`) to `propertyId`.

## Backend
- Router: `backend/routers/accounting.py`
- Key endpoints:
  - `GET /transactions` — list, filterable by type/status/leasing_unit_id/from_date/to_date, ordered by date desc.
  - `GET /transactions/{id}` — single transaction.
  - `POST /transactions` — create (full `TransactionIn` payload).
  - `PUT /transactions/{id}` — update.
  - `PATCH /transactions/{id}/status` — set status to paid/pending/overdue.
  - `DELETE /transactions/{id}`.
  - `POST /invoices/generate` — for every `leases` row with `status='active'` whose date range covers today, creates a `type=income, category=Rent` transaction (idempotent per calendar month, dedup via `period` key stored in the JSON `notes` field). Computes CGST/SGST at 9%+9% and stores `base_rent`, `cgst_9pct`, `sgst_9pct`, `total_with_gst`, `fiscal_year`, `invoice_no` (format `BG/{fiscal_yr}/{seq:04d}`) inside `notes` (JSON string), but the actual `transactions.amount` column is only the **base rent** (GST not added to `amount`). Status is `overdue` if today.day > 5, else `pending`. Due date is always the 1st of the current month.
  - `GET /summary` — aggregates `total_income`/`total_expenses` (paid only), `outstanding_rent` (pending), `overdue_rent` from all transactions (optionally date-filtered). Not called from `AccountingProvider`; the KPI row in `accounting_screen.dart` is computed client-side instead.

## Database
- Tables (`supabase/migrations/001_initial_schema.sql`):
  - `transactions` (id uuid, type, category, amount, currency default INR, date, description, status default 'paid', leasing_unit_id → leasing_units, tenant_id → tenants, lease_id → leases, reference_no, notes, created_at/updated_at).
  - `leases` (id uuid, tenant_id, leasing_unit_id, start_date, end_date, monthly_rent, deposit_amount, status, signed_date, document_url) — separate table from `leasing_units`/`tenants`; `invoices/generate` reads active leases from here, not from `leasing_units` directly.
  - `rent_schedules` (id, lease_id, due_day, amount, is_active) — exists in schema but is **not used by the accounting feature at all**. It's only read by `backend/routers/calendar.py:166` (for calendar reminders). Monthly invoice generation in `accounting.py` computes rent straight from `leases.monthly_rent`, ignoring `rent_schedules` entirely.
  - `stripe_payments` (in `supabase/migrations/003_tenant_portal.sql`) references `transactions.id` — online payment sessions link back to a transaction row (see Related features).

## Key patterns / architecture notes
- "Invoice" in this feature means a `transactions` row with `category='Rent'`, not a PDF document — contrast with the separate `frontend/lib/features/invoices/` feature (see `invoices.md`), which is a client-side-only PDF generator with **no connection** to this table.
- GST is computed and stored in `notes` (JSON string) at generation time but not reflected in the `amount` column or in `GET /summary` totals — summary/KPI math only ever uses `amount`.
- `AccountingRepository`/`AccountingProvider` never call `/transactions` POST/PUT/DELETE for manual entry — only list, generate, and mark-paid are wired up from the UI.
- Tenant portal (`backend/routers/tenant.py:82` `GET /my-invoices`) and Stripe checkout (`backend/routers/stripe_payments.py`) both read/write the same `transactions` table, so rent transactions generated here are what tenants see and pay against.

## Known Issues
- `accounting_screen.dart:163` — "Add Transaction" button has `onPressed: () {}` — no-op, dialog not implemented. Manual transaction entry is not possible from the UI despite the backend supporting `POST /transactions`.
- GST amounts computed in `invoices/generate` are not added to `transactions.amount`, so any consumer relying on `amount` alone (KPI cards, `/summary`) undercounts rent revenue by the 18% GST portion whenever GST applies.
- `GET /summary` backend endpoint is implemented but currently dead code from the frontend's perspective — `AccountingProvider` recomputes the same KPIs from the full transaction list on the client instead.

## Related features
- `invoices.md` — separate, client-side-only PDF invoice/receipt generator; not integrated with `transactions`.
- Tenant portal (`backend/routers/tenant.py`) — reads `transactions` for "My Invoices".
- Stripe payments (`backend/routers/stripe_payments.py`) — creates Checkout Sessions against a `transaction_id`.
- Calendar (`backend/routers/calendar.py`) — the only consumer of `rent_schedules`.
