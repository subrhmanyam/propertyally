"""ValidateTokenUseCase — lightweight token check for inter-service calls."""

from __future__ import annotations

import logging
from dataclasses import dataclass

from supabase import Client

from app.domain.entities.user import User
from app.domain.exceptions import InvalidTokenError, UnauthorizedError, UserNotFoundError
from app.domain.repositories.abstract_user_repository import AbstractUserRepository

logger = logging.getLogger(__name__)


@dataclass
class ValidateTokenInput:
    access_token: str


@dataclass
class ValidateTokenOutput:
    user: User
    supabase_uid: str
    email: str


class ValidateTokenUseCase:
    """
    Called by other services to verify a Bearer token is valid and to obtain
    the resolved user principal.  Identical in logic to GetCurrentUserUseCase
    but returns extra fields useful for downstream authorisation checks.
    """

    def __init__(
        self,
        user_repo: AbstractUserRepository,
        supabase: Client,
    ) -> None:
        self._user_repo = user_repo
        self._supabase = supabase

    async def execute(self, inp: ValidateTokenInput) -> ValidateTokenOutput:
        try:
            response = self._supabase.auth.get_user(inp.access_token)
        except Exception as exc:
            logger.warning("Token validation failed: %s", exc)
            raise InvalidTokenError("Token is invalid or has expired.") from exc

        if response is None or response.user is None:
            raise UnauthorizedError("Token is invalid or has expired.")

        supabase_uid = str(response.user.id)
        email = response.user.email or ""

        user = await self._user_repo.get_by_email(email)
        if user is None:
            raise UserNotFoundError(email)

        return ValidateTokenOutput(user=user, supabase_uid=supabase_uid, email=email)
