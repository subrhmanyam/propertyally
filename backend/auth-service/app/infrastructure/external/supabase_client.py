"""Supabase client factory — created once and reused via FastAPI dependency."""

from __future__ import annotations

from functools import lru_cache

from supabase import Client, create_client

from app.config import get_settings


@lru_cache(maxsize=1)
def get_supabase_client() -> Client:
    """Return a singleton Supabase client using the service-role key.

    The service-role key bypasses Row Level Security and is appropriate for
    server-side auth operations (sign-up, sign-in validation, token refresh).
    It must NEVER be exposed to clients.
    """
    settings = get_settings()
    return create_client(settings.supabase_url, settings.supabase_service_key)
