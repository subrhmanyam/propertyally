# Tenants (Admin CRUD)

## Purpose
Admin-facing feature for managing tenant contacts, their leases, and viewing rental agreements, organized around properties (`leasing_units`). Used by property managers/admins, not tenants themselves.

## Frontend
- **Screens**:
  - `frontend/lib/features/tenants/presentation/screens/tenant_list_screen.dart` — 3-level drill-down UI: (1) property grid, (2) single property's tenant/agreement view, (2b) "unassigned tenants" view. Route `/tenants`.
  - `frontend/lib/features/tenants/presentation/screens/tenant_detail_screen.dart` — full-page view for one named tenant (contact info, lease card, agreement card, emergency contact). Route `/tenants/:id`.
- **Providers**: `frontend/lib/features/tenants/presentation/providers/tenants_provider.dart` (`TenantsProvider`) — owns `tenants` list (filtered by status/search), `selectedTenant`, `selectedLease`. Wraps CRUD calls to `TenantRepository` and lease CRUD.
- **Repositories**: `frontend/lib/features/tenants/data/repositories/tenant_repository.dart` (`TenantRepository`) — talks **directly to Supabase** via `supabase_flutter` client (`Supabase.instance.client.from('tenants')` / `.from('leases')`). Does **not** call the backend `tenants.py` router at all (see Known Issues / architecture notes below).
- **Key widgets/dialogs**:
  - `frontend/lib/features/tenants/presentation/widgets/tenant_form_dialog.dart` — contains `editTenant()` (shared save flow, see below), `showTenantForm()` (the Add/Edit Tenant form itself, dialog on desktop / bottom sheet on mobile), and `markPropertyOccupiedIfVacant()`.
  - `frontend/lib/features/tenants/presentation/widgets/lease_form_dialog.dart` — `showLeaseForm()`, Add/Edit Lease dialog.
  - `frontend/lib/features/properties/presentation/widgets/unit_agreement_dialog.dart` (`UnitAgreementDialog.show(...)`) — reused from the properties feature; called with **`unitId`** (never `tenantId`) from both `tenant_list_screen.dart` (`_viewAgreement`, admin mode) and `tenant_detail_screen.dart`'s `_AgreementCard` (view/upload mode).
- **Domain entities**: `frontend/lib/features/tenants/domain/entities/tenant.dart`
  - `Tenant`: `id, firstName, lastName, email, phone, status, unitId, propertyId, companyName, floor, moveInDate, emergencyContactName, emergencyContactPhone`. Note `unitId` and `propertyId` are **both** populated from the same DB column `leasing_unit_id` (redundant alias). `fullName` is a computed getter.
  - `Lease`: `id, tenantId, startDate, endDate, monthlyRent, status, depositAmount`.
  - **Gap**: the tenant form (`tenant_form_dialog.dart`) collects and submits `business_type` and `area_entries` (and DB stores them, see below), but the `Tenant` entity class has **no `businessType` or `areaEntries` fields** — those values round-trip to the DB but are never read back into the app's domain model or displayed anywhere in `tenant_list_screen.dart` / `tenant_detail_screen.dart`.

## Backend
- Router: `backend/routers/tenants.py`, mounted at `/api/v1/tenants` in `backend/main.py` (line ~54).
- Endpoints defined: `GET /`, `GET /{tenant_id}`, `POST /`, `PUT /{tenant_id}`, `DELETE /{tenant_id}`, `GET /{tenant_id}/leases`, `POST /{tenant_id}/leases`.
- **Not used by this feature's frontend.** `tenant_repository.dart` (admin side) bypasses this router entirely and talks to Supabase directly with the anon/user client. The only backend call made from within the `tenants/` feature folder is `ApiClient.properties.get('/api/v1/leasing/{unitId}/agreement')` in `tenant_list_screen.dart`'s `_UnitTenantInfoCardState._fetchAgreement()` — that's the properties/leasing router, not `tenants.py`.
- Auth pattern: N/A for this feature (direct Supabase client calls rely on the logged-in admin session + RLS/service role; no `user_id` query-param pattern here — that's the tenant-portal pattern, see `tenant-portal.md`).

## Database
- Tables: `tenants` (`id uuid, first_name, last_name, email, phone, status, leasing_unit_id text, move_in_date, emergency_contact_name, emergency_contact_phone, notes, business_type, floor, area_entries jsonb, company_name, auth_user_id uuid, created_at, updated_at`), `leases` (`id uuid, tenant_id uuid, leasing_unit_id text, start_date, end_date, monthly_rent, deposit_amount, status, signed_date, document_url, created_at, updated_at`).
- Migration history quirks:
  - Base `tenants` and `leases` tables come from `supabase/migrations/001_initial_schema.sql` (lines ~85–122), with only `first_name, last_name, email, phone, status, leasing_unit_id, move_in_date, emergency_contact_name, emergency_contact_phone, notes`.
  - `supabase_tenants_migration.sql` (NOT in the numbered migrations folder — a separate incremental file) layers on 5 "Phase" blocks:
    - Base block (before "Phase 2" label): re-creates `tenants` with `auth_user_id uuid references auth.users(id)` — this is the column the tenant-portal backend (`tenant.py`'s `_get_tenant`) depends on.
    - **Phase 2**: adds `business_type`, `floor`, `area_entries jsonb default '[]'`.
    - **Phase 3**: adds `company_name` to **`leasing_units`** (not `tenants`).
    - **Phase 4**: fixes `tenants.leasing_unit_id` from `UUID` to `TEXT` (to match `leasing_units.id` which is `TEXT`).
    - **Phase 5**: adds `company_name` to **`tenants`** (separate from Phase 3's `leasing_units.company_name`).
  - So `company_name` exists on **both** `leasing_units` and `tenants` via two different phases — don't confuse `unit.companyName` (owner name, shown on property cards) with `tenant.companyName` (tenant's business name, shown in the tenant form/detail).

## Key patterns / architecture notes
- **Single tenant contact per property.** A `leasing_unit` currently supports at most one formal `Tenant` row in the UI. Evidence, all in `tenant_list_screen.dart`:
  - `_PropertyTenantsView` renders a section literally labeled `'Contact'` (singular, line ~632) and passes `tenants: [tenants.first]` into `_TenantVCardGrid` (line ~639) — even if more than one `Tenant` row existed for that unit, only the first is ever shown.
  - The "Edit Tenant Details" button (line ~593) calls `onEditTenantDetails(tenants.isNotEmpty ? tenants.first : null)` — same pattern (edit-in-place, not "add another").
  - `_TenantListScreenState._openEditTenantDetails` doc comment (line ~89): *"only one tenant contact is supported per property"*.
  - The "assign unassigned tenant to a property" flow in `_openAssignProperty`/`_UnassignedTenantsView.onAssignProperty` explicitly filters out properties that already have a tenant (`occupiedUnitIds`), so a property can't be assigned a second tenant contact through that path either.
  - Separately, `_UnitTenantInfoCard` shows the **unit's own fields** (contact/email/area/rent from `LeasingUnit` + any AI-extracted `UnitAgreement`) as a stand-in "tenant record" — comment at line ~614: *"In this complex, the unit itself... usually *is* the tenant — formal Tenant rows below are additional named contacts, not a replacement for this."* So there are two layers of "tenant info" per property: the unit's own fields (always shown) and the optional single `Tenant` contact row (shown only if one exists).
- **Shared "edit tenant" function**: `editTenant(BuildContext context, {required List<LeasingUnit> units, required LeasingUnit preselectedUnit, Tenant? existingTenant})` in `tenant_form_dialog.dart` (line 21). Both `tenant_list_screen.dart` (`_openEditTenantDetails`) and `tenant_detail_screen.dart` (`_openEditTenant`) call this instead of duplicating save logic. It opens `showTenantForm`, then either `TenantsProvider.updateTenant` (existing) or `TenantsProvider.createTenant` (new) + `markPropertyOccupiedIfVacant`.
- **Auto-occupied on add**: `markPropertyOccupiedIfVacant(BuildContext context, String? unitId)` in `tenant_form_dialog.dart` (line 73). Called after creating a new tenant (inside `editTenant`, only on create not update) and after assigning an unassigned tenant to a property (`_openAssignProperty` in `tenant_list_screen.dart`, line 257). Skips the update if the unit's status is already in `{'occupied', 'in_house', 'owner_occupied'}`; otherwise calls `LeasingProvider.update(unit.copyWith(status: 'occupied'))`. There is **no** corresponding "flip back to vacant on delete" — deleting the last tenant contact does not revert the property's status.
- Lease editing exists: Add/Edit Lease dialog (`showLeaseForm` in `lease_form_dialog.dart`), invoked from `tenant_detail_screen.dart` (`_openAddLease` / `_openEditLease`). Writes to the `leases` table via `TenantsProvider.addLease` / `updateLease` → `TenantRepository.createLease` / `updateLease` (direct Supabase, not the backend `tenants.py` `/leases` endpoints).
- Rental agreement (AI-extracted from uploaded PDF/image) is a **property/unit-level** concept, not tenant-level: `UnitAgreementDialog.show(context, unitId: ..., ...)` always takes a `unitId`. `tenant_detail_screen.dart`'s `_AgreementCard` derives the `unitId` from `tenant.unitId` (falls back to "No property assigned" if null) — so the agreement itself lives on the property; the tenant-detail page just deep-links into it via the tenant's linked unit.

## Known Issues
- **Crash bug — Delete Tenant / Delete Property dialogs close over the outer `context`.** In `frontend/lib/features/tenants/presentation/screens/tenant_list_screen.dart`:
  - `_confirmDeleteTenant` (lines 96–124): `showDialog(context: context, builder: (_) => AlertDialog(...))` — the builder param is discarded (`_`), and the two button handlers call `Navigator.pop(context, false)` (line 109) and `Navigator.pop(context, true)` (line 114), both using the **outer** `State.context`, not a dialog-local context.
  - `_confirmDeleteProperty` (lines 136–167): identical pattern — `builder: (_) => AlertDialog(...)` (line 139), `Navigator.pop(context, false)` (line 149), `Navigator.pop(context, true)` (line 154).
  - Because the app's routing uses GoRouter's `ShellRoute` (nested `Navigator`), popping with the outer context here risks popping the wrong `Navigator`/route stack instead of just dismissing the dialog, causing a "You have popped the last page off of the stack" crash (blank screen) in some navigation states.
  - **Fix**: change `builder: (_) => AlertDialog(...)` to `builder: (dialogContext) => AlertDialog(...)` and use `Navigator.pop(dialogContext, false/true)` in place of `Navigator.pop(context, ...)` at all four call sites (lines 109, 114, 149, 154).
  - **Contrast**: `_openAssignProperty`'s dialog (lines 217–252) does this correctly already — `builder: (ctx) => ...` and `Navigator.pop(ctx, ...)` — use it as the reference pattern for the fix.
- **Currency symbol inconsistency**: `tenant_detail_screen.dart` line 410, `_LeaseCard` formats `lease.monthlyRent` and `lease.depositAmount` with `NumberFormat.currency(symbol: r'$')` (no locale, defaults to `$`). Every other money field in this feature (`lease_form_dialog.dart`'s rent/deposit inputs, `tenant_form_dialog.dart`'s rent breakdown, `tenant_list_screen.dart`'s `_UnitTenantInfoCard`) uses `NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN')`. The Lease Info card on the tenant detail page will show amounts as e.g. `$1,200.00` instead of `₹1,200`.
- `backend/routers/tenants.py` is effectively dead code from this feature's perspective — the frontend never calls it (see Backend section above). Confirm before deleting/refactoring it, in case some other caller (scripts, tests, a future mobile client) depends on it.
- Tenant form collects `business_type` and `area_entries` (per-area sqft/rate/type breakdown used to compute rent) which are saved to the DB but never read back into the `Tenant` entity or shown again anywhere in the tenant UI after saving — effectively write-only from the app's perspective.

## Related features
- `properties.md` (if present) — `LeasingUnit` entity, `LeasingProvider`, `unit_agreement_dialog.dart` / `UnitAgreement` entity, and the `/api/v1/leasing/{unitId}/agreement` endpoint are all owned by the properties feature and reused here.
- `tenant-portal.md` — the self-service side for the same `tenants` table (linked via `auth_user_id`), covering a tenant's own view of their unit/lease/invoices/maintenance/services.
