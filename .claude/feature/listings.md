# Listings

## Purpose
Publishes a vacant `leasing_unit` to external real-estate portals (Housing.com, 99acres, MagicBricks, NoBroker). A backend "listing agent" calls Claude to generate platform-optimized title/description, then attempts to post to each platform via a per-platform poster class, tracking status per (listing, platform) pair.

## Frontend
- **Screens/Widgets**:
  - `frontend/lib/features/listings/presentation/screens/listings_screen.dart` — table of all listings with a per-row platform status strip and a "Publish" button (shown only if the listing has zero platform posts yet); tapping a row navigates to detail.
  - `frontend/lib/features/listings/presentation/screens/listing_detail_screen.dart` — listing info card + a 2-column grid of per-platform cards (status dot, "View" link if posted, "Retry" if failed, "Copy" dialog with Claude-generated title/description if `manual_required`).
  - `frontend/lib/features/listings/presentation/widgets/platform_picker_dialog.dart` — `PlatformPickerDialog.show(context, unitId)` modal; fetches relevant platforms for the unit's category via `GET /listing-agent/platforms/{unit_id}`, lets user check/uncheck, returns selected platform keys (all pre-checked by default).
  - `frontend/lib/features/listings/presentation/widgets/platform_status_strip.dart` — 4 fixed colored dots (housing_com, 99acres, magicbricks, nobroker) with tooltips; grey/dim if no post exists for that platform yet.
- **Providers**: `frontend/lib/features/listings/presentation/providers/listings_provider.dart` (`ListingsProvider extends BaseProvider`) — owns `_listings: List<Listing>` and `_platformPosts: Map<listingId, List<PlatformPost>>`; exposes `load()`, `loadPlatformPosts(listingId)`, `getPlatformsForUnit(unitId)`, `triggerAgent(unitId, platformKeys)`, `retryPost(postId, listingId)`. Registered globally in `frontend/lib/main.dart:41`.
- **Repositories**: `frontend/lib/features/listings/data/repositories/listings_repository.dart`
  - `getAll()` / `getPlatformPosts(listingId)` — direct Supabase table reads (`listings`, `listing_platform_posts`), not via backend API.
  - `getPlatforms()` → `GET /api/v1/listing-agent/platforms`
  - `getPlatformsForUnit(unitId)` → `GET /api/v1/listing-agent/platforms/{unitId}`
  - `triggerAgent(unitId, platformKeys)` → `POST /api/v1/listing-agent/trigger/{unitId}` body `{platform_keys}`
  - `retryPost(postId)` → `POST /api/v1/listing-agent/retry/{postId}`
  - Client-side `_platformName()` maps platform_key → display name, duplicating the backend's `PLATFORM_REGISTRY` names.
- **Domain entities**: `frontend/lib/features/listings/domain/entities/listing.dart`
  - `Listing`: id, leasingUnitId, title, monthlyRent, isPublished, description, availableFrom, contactEmail, contactPhone, photos, videoUrls, virtualTourUrl, features, platformPosts, createdAt. Computed counters: postedCount/manualCount/failedCount/pendingCount.
  - `PlatformPost`: id, listingId, platformKey, platformName, status (`pending|posting|posted|failed|manual_required`), externalId, externalUrl, platformTitle, platformDesc, errorMessage, postedAt.
- **Route**: `/listings` and `/listings/:id` registered in `frontend/lib/core/router/app_router.dart:128-136`.

## Backend
- Routers (both under `backend/routers/`, mounted separately in `backend/main.py`):
  - `listings.py` → prefix `/api/v1/listings` — CRUD + public-facing advert features: list/get/create/update/delete listing, record a view, create/list inquiries, convert an inquiry, get analytics (views/inquiries/conversion rate). Independent of the AI agent; reads/writes the `listings` and `listing_inquiries` tables directly.
  - `listing_agent.py` → prefix `/api/v1/listing-agent` — the actual AI-driven multi-platform publish trigger. Endpoints:
    - `GET /platforms` — all active platforms from the in-memory `PLATFORM_REGISTRY`.
    - `GET /platforms/{unit_id}` — platforms relevant to the unit's `category` (falls back to all active platforms if unit not found).
    - `POST /trigger/{unit_id}` — validates unit exists and `platform_keys` non-empty, then fires `run_listing_agent` as a `BackgroundTasks` job (fire-and-forget; returns immediately with `{message, unit_id, unit_name, platforms}`).
    - `GET /posts/{listing_id}` — all `listing_platform_posts` rows for a listing.
    - `POST /retry/{post_id}` — re-runs `poster.post()` for one platform post as a background task, reusing the previously stored `platform_title`/`platform_desc` (does not call Claude again).
    - `GET /status` — dashboard counts of posts by status.
  - Core agent logic: `backend/agents/listing_agent.py` (`run_listing_agent`) — fetches unit + `area_entries`, ensures a `listings` row exists (creates one with a generated title/estimated rent if missing), calls Claude once (`claude-sonnet-4-6`) to generate title+description per platform, upserts a `listing_platform_posts` row per platform, calls the platform's poster, updates status, creates an in-app `notifications` row for every profile, and marks the row processed in `listing_agent_queue` if present.
  - Platform config: `backend/platforms/registry.py` — `PLATFORM_REGISTRY` dict, 4 entries (housing_com, 99acres, magicbricks — `api_type: rest_api`; nobroker — `api_type: manual`), each with property_types, tone, active flag, and `api_key_env`/`base_url_env` names. `get_platforms_for_category()` filters by unit category; `DISABLED_PLATFORMS` env var can exclude keys.
  - Posting: `backend/platforms/posters.py` — `RestApiPoster` (rest_api platforms) and `ManualPoster` (manual platforms), selected via `get_poster(key)`.

- External integration status: **STUB for the 3 REST-API platforms, by design, until real partner credentials exist.** In `RestApiPoster.post()` (`backend/platforms/posters.py:37-90`): if `api_key_env`/`base_url_env` are unset (they are — no `HOUSING_COM_API_KEY` etc. exist in this repo), it logs the payload and returns a mock `external_id` of the form `stub_{platform_key}_{listing_id[:8]}` with `external_url: None`, i.e. status ends up `posted` with a fake ID and no clickable link. If credentials were ever configured, the code path does make a real `httpx.AsyncClient` POST to `{base_url}/listings`. `nobroker` (api_type=manual) never attempts any network call — it always returns `manual_required` so the admin copy-pastes the Claude-generated content via the "Copy" action in the UI. **The Claude call itself (title/description generation) is real** — uses `anthropic.Anthropic` client with `ANTHROPIC_API_KEY`, model `claude-sonnet-4-6`.

## Database
- `listings` (`supabase/migrations/001_initial_schema.sql:185-199`): id (uuid), leasing_unit_id (text fk), title, description, monthly_rent, available_from, is_published, contact_email, contact_phone, photos (text[]), features (text[]), created_at, updated_at.
- `listing_platform_posts` (`supabase/migrations/002_listing_agent.sql:11-29`): id, listing_id (fk → listings, cascade), platform_key, status (pending|posting|posted|failed|manual_required), external_id, external_url, platform_title, platform_desc, error_message, posted_at, last_attempted_at, created_at, updated_at. Unique on (listing_id, platform_key).
- `listing_agent_queue` (`supabase/migrations/002_listing_agent.sql:55-61`): id, leasing_unit_id (fk, unique), triggered_at, processed, processed_at. Populated by DB trigger `on_unit_becomes_vacant` (`notify_unit_vacant()`) whenever `leasing_units.status` transitions to `vacant` — described as a "belt-and-suspenders" queue, but **nothing in the backend currently reads/drains this queue** (only `run_listing_agent` marks a row processed at the end, it never polls for unprocessed ones — see Known Issues).

## Key patterns / architecture notes
- Two-router split: `listings.py` = public advert CRUD/analytics (views, inquiries, conversion), `listing_agent.py` = the AI publish-to-platforms workflow. They share the `listings` table but otherwise don't call each other.
- Frontend reads `listings` and `listing_platform_posts` directly via Supabase client (`ListingsRepository.getAll/getPlatformPosts`), but all *mutations* (trigger, retry) go through the FastAPI backend so the Claude call + multi-table orchestration stay server-side.
- `POST /trigger/{unit_id}` and `POST /retry/{post_id}` both return immediately and do the work in a `BackgroundTasks` job — the frontend has no polling/websocket; `ListingsScreen`/`ListingDetailScreen` rely on manual refresh or re-navigating to see updated status.
- Platform-name display is duplicated in three places: `platforms/registry.py` (`PLATFORM_REGISTRY[key]["name"]`, backend source of truth), `ListingsRepository._platformName()` (frontend repo), and `PlatformStatusStrip`/`_PlatformCard` (`_label` switch statements) — adding a 5th platform requires updating all of these plus the `_knownPlatforms` list in `platform_status_strip.dart:10-15`.
- `listing_agent.py`'s photo/video URL normalization (`_resolve_media_url`) is duplicated verbatim between `backend/routers/listings.py:19-41` and `backend/agents/listing_agent.py:35-57`.

## Recent changes (org-admin authorization hardening)
- `listing_agent.py`'s `POST /trigger/{unit_id}` and `POST /retry/{post_id}` — the two live, actually-called mutating endpoints — previously had zero auth and now require a `user_id` query param + `require_org_admin_for_unit` (resolved via the unit directly for trigger, via `post → listing_id → listings.leasing_unit_id` for retry). `ListingsRepository.triggerAgent()`/`retryPost()` now pass `Supabase.instance.client.auth.currentUser?.id` as `user_id`.
- `listings.py`'s own CRUD (`POST/PUT/DELETE /`) was hardened the same way for defense-in-depth, but per the new Known Issues bullet below, the live frontend doesn't call these at all — so it has no effect on the actual listings screen's access control.
- Deliberately left alone: `convert_inquiry`, `record_listing_view`, `create_listing_inquiry` (the latter two are public-facing, used by the external listing site) — no auth added there.

## Known Issues
- **Frontend bypasses `listings.py`'s CRUD entirely** — `ListingsRepository.getAll()` reads the `listings` table directly via the Supabase client, and there's no frontend caller anywhere for `listings.py`'s `POST/PUT/DELETE /` at all (confirmed by grep). Supabase RLS on `listings` is still the wide-open `listings_auth_all using (true) with check (true)` policy from `001_initial_schema.sql:339`, so any authenticated user can currently write to `listings` directly regardless of the backend router's auth checks — same gap pattern as `leasing_units`/`tenants`, see `properties.md`'s Known Issues. Deferred, not fixed, this session.
- **Schema/code mismatch in `listings.py`**: the router filters/reads columns (`status`, `property_type`, `city`, `bedrooms`, `views_count`, `inquiry_count`) and a table (`listing_inquiries`) that do **not exist in any migration file** under `supabase/migrations/` (checked 001–009 plus `supabase_tenants_migration.sql`). Only `id, leasing_unit_id, title, description, monthly_rent, available_from, is_published, contact_email, contact_phone, photos, features, created_at, updated_at` exist on `listings` per `001_initial_schema.sql`. Endpoints `GET /`, `POST /{id}/view`, the inquiry endpoints, and `GET /{id}/analytics` will fail at runtime against a DB built purely from checked-in migrations, unless these columns/table were added ad hoc directly in the Supabase dashboard (not reflected in this repo). Verify against the live DB before trusting these endpoints.
- Similarly, the `Listing` Dart entity and `listing_agent.py`'s `new_listing` insert both reference `video_urls` and `virtual_tour_url`, which also don't appear in any migration for the `listings` table — same drift.
- `listing_agent_queue` is written to by a DB trigger but nothing appears to consume/poll it as an entry point into `run_listing_agent`; the only place it's touched from Python is marking rows processed after a manual `/trigger` call already ran. If the intent was "auto-publish when a unit goes vacant," that automation is not wired up.
- `RestApiPoster` stub mode returns `error_message: None` and a fake `external_id`, so a "posted" status in the UI does not guarantee a real live listing exists on Housing.com/99acres/MagicBricks — the "View" link (`externalUrl`) will be `None` for all stub posts, so `_CardAction` for "View" won't render (`listing_detail_screen.dart:270` guards on `externalUrl != null`), but the status dot still shows green/"Posted", which could mislead an admin into thinking the listing is genuinely live.

## Related features
- properties.md, tenants.md (both trigger "Publish to platforms" for a leasing_unit) — call sites: `frontend/lib/features/properties/presentation/screens/leasing_list_screen.dart:362-380` (`_publishUnit`) and `frontend/lib/features/tenants/presentation/screens/tenant_list_screen.dart:182-200` (`_publishUnit`), both identical: open `PlatformPickerDialog.show`, then `context.read<ListingsProvider>().triggerAgent(unit.id, selected)`.
