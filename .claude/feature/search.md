# Search

## Purpose
Global "search anything" bar that queries properties (leasing units), tenants, and maintenance requests from a single input, and deep-links to the matching record. There is no dedicated search screen/page — the feature is surfaced entirely as a widget embedded in the shared top bar.

## Frontend
- **Screens/Widgets**: `frontend/lib/shared/widgets/top_bar.dart` — **the actual search UI lives here, not under `features/search/`.** `TopBar` renders `_SearchField` (a `StatefulWidget`) in its middle `Expanded` slot; `_SearchField` owns a `TextEditingController`, 350ms debounce `Timer`, and an `OverlayEntry` (`_SearchOverlay`) that lists up to 15 results (5 per category) with icon + type-label + subtitle, positioned under the search box via `CompositedTransformTarget`/`Follower`. Tapping a result calls `context.go(result.route)` (GoRouter) and clears the field. There is no `features/search/presentation/` directory at all — confirmed no screens exist there.
- **Providers**: none. `_SearchField` is a plain `StatefulWidget` managing its own `_results`/`_loading` state directly — no `ChangeNotifier`/Provider wraps this feature.
- **Repositories**: `frontend/lib/features/search/data/search_repository.dart` — `SearchRepository.search(query)` calls `GET /api/v1/search/?q=<query>` via `ApiClient` (Dio), returns `[]` immediately for empty/whitespace-only queries without hitting the network. Merges the three category arrays (`properties`, `tenants`, `maintenance`) from the response into one flat `List<SearchResult>`.
- **Domain entities**: `SearchResult` class defined inline in `search_repository.dart` (no separate `domain/entities/` folder) — fields: `id`, `type` (`'property'|'tenant'|'maintenance'`), `title`, `subtitle`, `status`, `route` (pre-built by the backend, e.g. `/properties`, `/tenants/{id}`, `/maintenance`).

## Backend
- Router: `backend/routers/search.py`, mounted at `/api/v1/search` (see `backend/main.py` line 69).
- Key endpoints:
  - `GET /api/v1/search/?q=<term>` (min_length=1, max_length=100) — searches `leasing_units`, `tenants`, and `maintenance_requests` in parallel, returns `{query, properties: [...], tenants: [...], maintenance: [...]}`, capped at 5 results per category.

## Database
- Real backend query via Supabase `.or_()` with `ilike` (case-insensitive substring match), not a Postgres full-text-search index — this is a filter query, not `tsvector`/`to_tsquery` FTS.
- Tables queried:
  - `leasing_units` (id, name, company_name, category, floor, status) — matched on `name`, `company_name`, `category` via `ilike '%term%'`
  - `tenants` (id, first_name, last_name, email, phone, status, leasing_unit_id) — matched on `first_name`, `last_name`, `email`, `phone`
  - `maintenance_requests` (id, title, status, priority, leasing_unit_id) — matched on `title`, `category` (note: `category` is selected in the `.or_()` filter but not in the `.select()` list — see Known Issues)

## Key patterns / architecture notes
- Search term is lowercased client-side-in-Python (`term = q.strip().lower()`) before being interpolated into the `.or_()` ilike filter string — `ilike` is already case-insensitive so the `.lower()` is redundant but harmless.
- The `.or_()` filter strings are built with plain f-string interpolation of `term` (e.g. `f"name.ilike.%{term}%,..."`) — Supabase's PostgREST client, not raw SQL, so this is not a classic SQL-injection vector, but a query containing `,` or `%` in the search term could break the filter syntax (PostgREST `.or_()` uses commas/parens as separators). Worth hardening if user-supplied punctuation causes broken/empty results.
- Debounce (350ms) and empty-query short-circuit both live client-side in `_SearchField`/`SearchRepository` — the backend has no rate limiting of its own beyond FastAPI's normal request handling.
- Result routes are backend-authored strings (`route` field), meaning the API controls navigation targets, not the frontend — a change to frontend routes requires updating `search.py` too.

## Known Issues
- `backend/routers/search.py` maintenance query selects `id,title,status,priority,leasing_unit_id` but the `.or_()` filter references `category.ilike.%{term}%` (line 47) — `category` is not in the `.select()` list. This likely still works (PostgREST can filter on columns not selected) but is worth double-checking if maintenance search results seem to miss expected matches, since `category` isn't returned/inspectable in the response either.
- No pagination or "see all results" — hard-capped at 5 per category (15 total) with no UI affordance to view more.
- No dedicated `/search` route/screen exists in the app router — if a full-page search results view is ever expected, it does not currently exist.

## Related features
- `.claude/feature/reports.md` — same `ApiClient`/Dio call pattern; both features read from `leasing_units` and `maintenance_requests`.
- Tenants feature (`frontend/lib/features/tenants/`) — search results of type `'tenant'` route to `/tenants/{id}`, which is the tenant detail screen.
- `frontend/lib/shared/widgets/app_shell.dart` — hosts `TopBar` (search lives inside `TopBar`, not `AppShell` itself); confirmed no search references in `app_shell.dart`.
