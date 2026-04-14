"""Application service configuration loaded from environment variables."""

from __future__ import annotations

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql+asyncpg://user:password@localhost:5432/bogi"
    supabase_url: str = ""
    supabase_service_key: str = ""
    auth_service_url: str = "http://auth-service:8001"
    notification_service_url: str = "http://notification-service:8005"


settings = Settings()
