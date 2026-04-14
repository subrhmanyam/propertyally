"""ChangePasswordUseCase — allow an authenticated user to update their password."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from uuid import UUID

from passlib.context import CryptContext
from supabase import Client

from app.domain.exceptions import InvalidCredentialsError, UserNotFoundError
from app.domain.repositories.abstract_user_repository import AbstractUserRepository

logger = logging.getLogger(__name__)

_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto", bcrypt__rounds=12)


@dataclass
class ChangePasswordInput:
    user_id: UUID
    current_password: str
    new_password: str
    access_token: str


class ChangePasswordUseCase:
    """
    1. Verify the current password by asking Supabase Auth to sign in.
    2. Update the password in Supabase (via admin API to avoid re-auth).
    3. Update the local bcrypt hash in our DB.
    """

    def __init__(
        self,
        user_repo: AbstractUserRepository,
        supabase: Client,
    ) -> None:
        self._user_repo = user_repo
        self._supabase = supabase

    async def execute(self, inp: ChangePasswordInput) -> None:
        user = await self._user_repo.get_by_id(inp.user_id)
        if user is None:
            raise UserNotFoundError(str(inp.user_id))

        # 1. Re-validate current password through Supabase
        try:
            self._supabase.auth.sign_in_with_password(
                {"email": user.email, "password": inp.current_password}
            )
        except Exception as exc:
            logger.warning("Invalid current password for user %s", inp.user_id)
            raise InvalidCredentialsError() from exc

        # 2. Update in Supabase (admin call — no need for old password again)
        try:
            # Use the user's own session so it targets their account
            self._supabase.auth.set_session(inp.access_token, "")
            self._supabase.auth.update_user({"password": inp.new_password})
        except Exception as exc:
            logger.error("Supabase password update failed for user %s: %s", inp.user_id, exc)
            raise InvalidCredentialsError() from exc

        # 3. Update local bcrypt hash
        new_hash = _pwd_context.hash(inp.new_password)
        await self._user_repo.update(inp.user_id, password_hash=new_hash)
        logger.info("Password updated for user %s", inp.user_id)
