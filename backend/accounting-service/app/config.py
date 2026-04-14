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

    # External services
    auth_service_url: str = Field(..., description="Base URL of the auth service")
    tenant_service_url: str = Field(..., description="Base URL of the tenant service")

    # Supabase
    supabase_url: str = Field(..., description="https://xxx.supabase.co")
    supabase_service_key: str = Field(..., description="service_role JWT from Supabase dashboard")

    # App meta
    environment: str = Field(default="development")
    log_level: str = Field(default="INFO")

    @property
    def is_production(self) -> bool:
        return self.environment.lower() == "production"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]
