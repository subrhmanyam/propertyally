"""LogoutUserUseCase — revoke session on Supabase and invalidate local tokens."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from uuid import UUID

from supabase import Client

from app.domain.repositories.abstract_refresh_token_repository import (
    AbstractRefreshTokenRepository,
)

logger = logging.getLogger(__name__)


@dataclass
class LogoutUserInput:
    access_token: str
    user_id: UUID


class LogoutUserUseCase:
    """
    Signs the user out of Supabase (invalidating the JWT server-side) and
    revokes all stored refresh tokens in our local DB.
    """

    def __init__(
        self,
        refresh_token_repo: AbstractRefreshTokenRepository,
        supabase: Client,
    ) -> None:
        self._rt_repo = refresh_token_repo
        self._supabase = supabase

    async def execute(self, inp: LogoutUserInput) -> None:
        # Sign out from Supabase using the user's token as context
        try:
            # Set the session so sign_out operates on this specific user
            self._supabase.auth.set_session(inp.access_token, "")
            self._supabase.auth.sign_out()
        except Exception as exc:
            # Log but don't fail — local revocation still happens
            logger.warning("Supabase sign_out error for user %s: %s", inp.user_id, exc)

        # Revoke all local refresh tokens
        await self._rt_repo.revoke_all_for_user(inp.user_id)
        logger.info("User %s logged out; all refresh tokens revoked", inp.user_id)
