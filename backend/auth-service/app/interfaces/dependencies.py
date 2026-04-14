"""FastAPI dependency providers for the auth service."""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession
from supabase import Client

from app.application.use_cases.get_current_user import (
    GetCurrentUserInput,
    GetCurrentUserUseCase,
)
from app.domain.entities.user import User
from app.domain.exceptions import AuthServiceError
from app.infrastructure.db.repositories.refresh_token_repository import (
    RefreshTokenRepository,
)
from app.infrastructure.db.repositories.user_repository import UserRepository
from app.infrastructure.db.session import get_async_session
from app.infrastructure.external.supabase_client import get_supabase_client

_bearer_scheme = HTTPBearer(auto_error=True)


# ---------------------------------------------------------------------------
# Raw dependencies
# ---------------------------------------------------------------------------


def get_db_session(
    session: AsyncSession = Depends(get_async_session),
) -> AsyncSession:
    """Re-export the session dependency under a friendlier name."""
    return session


def get_supabase(
    client: Client = Depends(get_supabase_client),
) -> Client:
    return client


# ---------------------------------------------------------------------------
# Repository dependencies
# ---------------------------------------------------------------------------


def get_user_repository(
    session: AsyncSession = Depends(get_async_session),
) -> UserRepository:
    return UserRepository(session)


def get_refresh_token_repository(
    session: AsyncSession = Depends(get_async_session),
) -> RefreshTokenRepository:
    return RefreshTokenRepository(session)


# ---------------------------------------------------------------------------
# Authenticated-user dependency
# ---------------------------------------------------------------------------


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer_scheme),
    user_repo: UserRepository = Depends(get_user_repository),
    supabase: Client = Depends(get_supabase),
) -> User:
    """
    Validate the Bearer token via Supabase and resolve the local User entity.
    Raises HTTP 401 for all invalid-token scenarios.
    """
    use_case = GetCurrentUserUseCase(user_repo=user_repo, supabase=supabase)
    try:
        return await use_case.execute(GetCurrentUserInput(access_token=credentials.credentials))
    except AuthServiceError as exc:
        raise HTTPException(
            status_code=exc.http_status,
            detail={"error": {"code": exc.code, "message": exc.message}},
        ) from exc


# ---------------------------------------------------------------------------
# Type aliases for route signatures
# ---------------------------------------------------------------------------

CurrentUser = Annotated[User, Depends(get_current_user)]
