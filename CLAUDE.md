# Bogi Property Management — Project Setup

## Session Account
- **Primary user email:** subrhmanyam.as@gmail.com
- This is the Supabase auth account used to log in to the app during development and testing.
- When testing or verifying features in the browser, sign in with this account.

## Project Overview
Property management platform for Bogineni Group built with Flutter Web + Python FastAPI + Supabase.

## URLs
- **Frontend (live):** https://bogi-property-app.web.app
- **Backend API (Cloud Run):** https://bogi-api-465312640914.asia-south1.run.app
- **API Docs:** https://bogi-api-465312640914.asia-south1.run.app/docs
- **Supabase Dashboard:** https://supabase.com (project: bogi-property-app)

## Tech Stack
- **Frontend:** Flutter (Web + Mobile), Provider, GoRouter, Supabase Flutter client, Dio
- **Backend:** Python 3.12, FastAPI, Supabase Python client (service-role key)
- **Database:** Supabase (PostgreSQL) with RLS enabled
- **Hosting:** Firebase Hosting (frontend), Google Cloud Run (backend)
- **AI features:** Anthropic Claude API (PDF parsing, document extraction)

## Repository Structure
```
bogi/
├── frontend/          # Flutter app
│   └── lib/
│       ├── core/      # constants, network, router, utils
│       ├── features/  # one folder per feature (properties, tenants, reports, calendar…)
│       └── shared/    # reusable widgets (TopBar, AppShell, AppButton…)
├── backend/           # FastAPI app
│   └── routers/       # one file per domain (leasing, tenants, reports, calendar, search…)
├── supabase/
│   └── migrations/    # 001_initial_schema.sql — full DB schema
└── supabase_tenants_migration.sql  # incremental ALTER TABLE migrations (Phases 1–5)
```

## Key Patterns
- **Data access:** Frontend calls Supabase Flutter client directly for leasing_units and tenants. Backend API is used for PDF import, reports, calendar, and search.
- **Default backend URL:** Set in `frontend/lib/core/network/api_client.dart` — defaults to the Cloud Run URL; override with `--dart-define=BACKEND_URL=...` at build time.
- **leasing_units.id** is `TEXT` (not UUID). `tenants.leasing_unit_id` is also `TEXT` to match.

## Deploy Commands
```bash
# Frontend
cd frontend
flutter build web
firebase deploy --only hosting

# Backend
cd backend
gcloud run deploy bogi-api --source . --region asia-south1 --allow-unauthenticated
```

## Supabase Migrations
Run SQL in Supabase Dashboard → SQL Editor in order:
1. `supabase/migrations/001_initial_schema.sql` — full schema (run once on a fresh project)
2. `supabase_tenants_migration.sql` — Phases 1–5 (incremental fixes, safe to re-run)
