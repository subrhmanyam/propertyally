-- ============================================================
-- Bogineni Group — Property/Space Photos
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run)
--
-- leasing_units (properties/spaces/rentals) had no way to attach images.
-- Photos are stored in a separate PUBLIC GCS bucket (bogi-property-app-photos,
-- distinct from the private bogi-property-app-documents bucket used for lease
-- agreements) since they're not sensitive and benefit from stable, non-expiring
-- URLs — see backend/gcs.py and backend/routers/leasing.py.
-- ============================================================

alter table leasing_units add column if not exists photos text[] default '{}';
