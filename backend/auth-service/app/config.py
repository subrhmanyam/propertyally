"""Centralised application settings loaded from environment variables."""

from __future__ import annotations

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # Database
    database_url: str = Field(..., description="asyncpg DSN, e.g. postgresql+asyncpg://...")

    # Supabase
    supabase_url: str = Field(..., description="https://xxx.supabase.co")
    supabase_service_key: str = Field(..., description="service_role JWT from Supabase dashboard")

    # JWT / security
    secret_key: str = Field(..., description="HS256 fallback signing key (min 32 chars)")

    # App meta
    environment: str = Field(default="development")
    log_level: str = Field(default="INFO")

    # Account lockout policy
    max_failed_login_attempts: int = Field(default=5)
    lockout_window_minutes: int = Field(default=15)

    # Token TTL (in seconds — these match Supabase defaults but are here for reference)
    access_token_ttl_seconds: int = Field(default=900)    # 15 min
    refresh_token_ttl_days: int = Field(default=30)

    @property
    def is_production(self) -> bool:
        return self.environment.lower() == "production"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]
