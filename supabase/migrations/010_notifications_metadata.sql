-- ============================================================
-- Bogineni Group — Notifications metadata column
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run)
--
-- backend/services/notification_service.py's send_in_app() always
-- includes a `metadata` key in the insert payload (defaulting to `{}`
-- when the caller doesn't pass one), but the notifications table
-- (001_initial_schema.sql) never had that column — every single in-app
-- notification insert has been failing with a Postgrest schema-cache
-- error ("Could not find the 'metadata' column of 'notifications'")
-- since the feature was built. This adds the missing column.
-- ============================================================

alter table notifications add column if not exists metadata jsonb default '{}'::jsonb;
