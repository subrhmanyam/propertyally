# Auth

## Purpose
Email+password authentication via Supabase Auth, plus role-based routing that
sends users to either the admin shell (`AppShell`) or the tenant portal
(`TenantShell`) based on a `role` claim embedded in the JWT.

## Frontend
- **Screens/Widgets**: `frontend/lib/features/auth/presentation/screens/login_screen.dart` — single screen with a 2-tab (Sign In / Register) card UI; sign-in email field defaults to `admin@boginenigroup.com`; register tab lets the user pick "Tenant" or "Admin" as `_role` (defaults to `tenant`).
- **Providers**: `frontend/lib/features/auth/presentation/providers/auth_provider.dart` — `AuthProvider extends ChangeNotifier`. Owns `AuthStatus status` (initial/loading/authenticated/unauthenticated/error), `User? user`, `String _userRole` (default `'admin'`), and exposes `isAuthenticated`, `isTenant` (`_userRole == 'tenant'`). Subscribes to `_repo.authStateChanges` in `_init()`. Constructed once in `main.dart` via `ChangeNotifierProvider(create: (_) => AuthProvider())` and passed into `AppRouter.build(authProvider)` as `refreshListenable`.
- **Repositories**: `frontend/lib/features/auth/data/repositories/auth_repository.dart` — wraps `Supabase.instance.client.auth` for `signIn`/`signOut`/`authStateChanges`/`currentUser`; calls backend `POST /api/v1/auth/register` (via `ApiClient`/Dio) for registration; decodes the JWT locally (`userRole` getter, splits `accessToken`, base64-decodes the payload, reads `app_metadata.role`) as the primary role source; `fetchRole(userId)` calls backend `GET /api/v1/auth/profile?user_id=` as a fallback.
- **Domain entities**: none — uses Supabase's own `User`/`AuthState`/`AuthResponse` types directly, no local entity wrapper.

## Backend
- Router: `backend/routers/auth.py`, mounted at prefix `/api/v1/auth` (see `backend/main.py:62`).
- Key endpoints:
  - `POST /api/v1/auth/register` — creates a Supabase auth user via `sb.auth.admin.create_user` (service-role, `email_confirm=True` so dev signups skip confirmation email), then updates the auto-created `profiles` row's `role`/`full_name`, and if `role == 'tenant'` also inserts a row into `tenants` (linked via `auth_user_id`) unless one already exists.
  - `GET /api/v1/auth/profile?user_id=` — returns `profiles` row (`id, role, full_name, email`) for a user; 404 if not found. Used by the frontend as a fallback role lookup when the JWT doesn't yet carry `app_metadata.role`.

## Database
- Tables:
  - `profiles` (`id uuid PK references auth.users`, `full_name`, `email unique`, `phone`, `avatar_url`, `role text default 'admin'`, timestamps) — `supabase/migrations/001_initial_schema.sql:22`. Auto-populated by an `on_auth_user_created` trigger (`handle_new_user()`) that inserts a `profiles` row with default `role='admin'` whenever a new `auth.users` row is created (`001_initial_schema.sql:38-50`, refined in `004_fix_handle_new_user.sql`).
  - `tenants` (`auth_user_id` FK to profile/user, `first_name`, `last_name`, `email`, plus lease/unit fields elsewhere) — a row is created here for role='tenant' registrations.

## Key patterns / architecture notes
- **Primary auth pattern**: email + password via `supabase.auth.signInWithPassword` — no magic link, no OAuth. Session account documented in project `CLAUDE.md`: `subrhmanyam.as@gmail.com` (Supabase auth account for dev/testing). The login screen's default pre-filled email (`admin@boginenigroup.com`) is a UI convenience default, not necessarily the account to use for testing — prefer the CLAUDE.md-documented session account.
- **Role source of truth**: a Postgres function `public.custom_access_token_hook(event jsonb)` (`supabase/migrations/003_tenant_portal.sql:99-118`) is meant to be registered as a Supabase Auth "Custom Access Token" hook. It looks up `profiles.role` for the signing-in user and injects it into the JWT's `app_metadata.role` claim. **This requires manual enablement in the Supabase Dashboard (Auth → Hooks)** — the migration only defines the function and grants; it does not enable the hook.
- **Frontend role detection is 2-tier**, in `AuthRepository`/`AuthProvider`:
  1. `AuthRepository.userRole` decodes the current session's JWT locally, reading `app_metadata.role`; defaults to `'admin'` if absent/unparseable.
  2. If that resolves to `'admin'`, `AuthProvider._fetchRoleFromBackend(userId)` fires and calls `GET /api/v1/auth/profile` as a fallback/cross-check, in case the JWT hook isn't enabled yet on this Supabase project — the backend value overwrites `_userRole` if different. This means: **if the hook is disabled, every user's role is resolved via a live backend call after login**, adding a request on every sign-in and on every auth-state change.
  3. Note the fallback logic only ever re-checks when the JWT-derived role is `'admin'` — if the JWT hook is misconfigured and injects the wrong non-'admin' value, the backend fallback never fires to correct it.
- **Router redirect logic** (`frontend/lib/core/router/app_router.dart:43-60`), evaluated via `GoRouter.redirect` with `refreshListenable: authProvider`:
  - `loggedIn = authProvider.isAuthenticated`, `isTenant = authProvider.isTenant`.
  - Not logged in and not headed to `/login` → redirect to `/login`.
  - Logged in and headed to `/login` → redirect to `/tenant` if `isTenant`, else `/`.
  - Logged in, `isTenant`, and headed to any non-tenant/non-login route → redirect to `/tenant`.
  - Logged in, admin (`!isTenant`), and headed to `/tenant*` → redirect to `/`.
  - Two `ShellRoute`s: `AppShell` wraps all admin routes (`/`, `/properties`, `/tenants`, `/accounting`, `/maintenance`, `/tasks`, `/services`, `/reports`, `/listings`, `/calendar`, `/documents`); `TenantShell` wraps `/tenant`, `/tenant/invoices`, `/tenant/services`, `/tenant/maintenance`, `/tenant/messages`.
- **Supabase connection**: `frontend/lib/core/config/supabase_config.dart` — `url = 'https://lysvzsheclvlvabbbiea.supabase.co'`, field is named `anonKey` but its value (`sb_publishable_vjmOoWa7DvWqLPy3uRT3YA_ikoei1Ow`) is already in the newer `sb_publishable_...` key format, not the legacy JWT-style anon key. `Supabase.initialize(url:, anonKey:)` is called in `frontend/lib/main.dart:22-25` before `runApp`, using this same field name (the `supabase_flutter` package's `initialize` API still names the parameter `anonKey` even when a publishable key is passed, so no analyzer warning is expected here despite the naming mismatch with newer Supabase docs terminology).
- `AuthProvider` is registered first in `MultiProvider` in `main.dart` and is the only provider passed to `AppRouter.build()`; all other feature providers (`LeasingProvider`, `AccountingProvider`, etc.) are sibling providers in the same tree but are not consulted by the router.

## Known Issues
- Role resolution has a race/consistency gap: the JWT-decoded role is used first and immediately reflected in `isTenant`/redirects; the backend fallback (`fetchRole`) runs asynchronously afterward and can flip the role (and trigger another redirect) shortly after the first navigation, causing a visible flash to the wrong shell if the JWT hook is disabled and the user is actually a tenant (since only the 'admin' default triggers backend re-check, not other unexpected values).
- `register()` in `AuthProvider` immediately calls `signIn()` after registration; if the Supabase project requires email confirmation (i.e. `email_confirm=True` is not honored, or if it's a different environment than what `backend/routers/auth.py` targets), this sign-in would fail silently into `AuthStatus.error` with a generic message.
- No password-reset / forgot-password flow found anywhere in `features/auth/`.
- Re-verify whether the Supabase "Custom Access Token" hook is actually enabled in the dashboard for the live project before assuming the JWT path (tier 1) is authoritative — this cannot be confirmed from code alone.

## Related features
- `frontend/lib/features/tenant/` — the tenant-facing screens rendered inside `TenantShell` for `isTenant == true` users.
- `frontend/lib/features/tenants/` — the admin-facing tenant *management* feature (different from `features/tenant/`), reachable only by admins via `/tenants`.
- `frontend/lib/shared/widgets/app_shell.dart` and `tenant_shell.dart` — the two shells selected by the redirect logic documented above.
