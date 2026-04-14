"""GetCurrentUserUseCase — resolve the authenticated user from a Bearer token."""

from __future__ import annotations

import logging
from dataclasses import dataclass

from supabase import Client

from app.domain.entities.user import User
from app.domain.exceptions import InvalidTokenError, UnauthorizedError, UserNotFoundError
from app.domain.repositories.abstract_user_repository import AbstractUserRepository

logger = logging.getLogger(__name__)


@dataclass
class GetCurrentUserInput:
    access_token: str


class GetCurrentUserUseCase:
    """
    1. Validate the JWT by calling Supabase Auth (get_user) — this verifies
       signature, expiry, and revocation status server-side.
    2. Resolve the corresponding local user record.
    """

    def __init__(
        self,
        user_repo: AbstractUserRepository,
        supabase: Client,
    ) -> None:
        self._user_repo = user_repo
        self._supabase = supabase

    async def execute(self, inp: GetCurrentUserInput) -> User:
        # 1. Ask Supabase to validate the token and return the auth user
        try:
            response = self._supabase.auth.get_user(inp.access_token)
        except Exception as exc:
            logger.warning("get_user call failed: %s", exc)
            raise InvalidTokenError("Token validation failed.") from exc

        if response is None or response.user is None:
            raise UnauthorizedError("Invalid or expired token.")

        supabase_uid = str(response.user.id)
        email = response.user.email

        if not email:
            raise UnauthorizedError("Token does not carry an email claim.")

        # 2. Resolve the local record (prefer email lookup for consistency)
        user = await self._user_repo.get_by_email(email)
        if user is None:
            logger.error(
                "Supabase user %s authenticated but has no local record", supabase_uid
            )
            raise UserNotFoundError(email)

        return user
