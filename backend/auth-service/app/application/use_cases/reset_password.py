"""ResetPasswordUseCase — validate OTP and set a new password."""

from __future__ import annotations

import hashlib
import logging
from dataclasses import dataclass
from datetime import datetime, timezone

from passlib.context import CryptContext
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from supabase import Client

from app.domain.exceptions import InvalidTokenError, UserNotFoundError
from app.domain.repositories.abstract_user_repository import AbstractUserRepository
from app.infrastructure.db.models import PasswordResetOTPModel

logger = logging.getLogger(__name__)

_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto", bcrypt__rounds=12)


@dataclass
class ResetPasswordInput:
    email: str
    otp: str
    new_password: str


class ResetPasswordUseCase:
    """
    1. Look up the user by email.
    2. Find the most-recent valid OTP for that user.
    3. Verify OTP hash, check expiry and single-use flag.
    4. Mark OTP as used.
    5. Update password in Supabase Admin API and local DB.
    """

    def __init__(
        self,
        user_repo: AbstractUserRepository,
        supabase: Client,
        session: AsyncSession,
    ) -> None:
        self._user_repo = user_repo
        self._supabase = supabase
        self._session = session

    async def execute(self, inp: ResetPasswordInput) -> None:
        email = inp.email.lower().strip()
        user = await self._user_repo.get_by_email(email)
        if user is None:
            raise UserNotFoundError(email)

        otp_hash = hashlib.sha256(inp.otp.encode()).hexdigest()

        # Find a valid (unused, unexpired) OTP matching the hash
        stmt = (
            select(PasswordResetOTPModel)
            .where(
                PasswordResetOTPModel.user_id == user.id,
                PasswordResetOTPModel.otp_hash == otp_hash,
                PasswordResetOTPModel.used.is_(False),
            )
            .order_by(PasswordResetOTPModel.expires_at.desc())
            .limit(1)
        )
        result = await self._session.execute(stmt)
        otp_row = result.scalar_one_or_none()

        if otp_row is None:
            raise InvalidTokenError("OTP is invalid or has already been used.")

        # Check expiry — make timezone-aware if needed
        expires_at = otp_row.expires_at
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)

        if datetime.now(tz=timezone.utc) > expires_at:
            raise InvalidTokenError("OTP has expired.")

        # Mark as used
        await self._session.execute(
            update(PasswordResetOTPModel)
            .where(PasswordResetOTPModel.id == otp_row.id)
            .values(used=True)
        )

        # Update password in Supabase via admin API
        supabase_uid = None
        from app.infrastructure.db.repositories.user_repository import UserRepository

        if isinstance(self._user_repo, UserRepository):
            model = await self._user_repo.get_model_by_id(user.id)
            if model:
                supabase_uid = model.supabase_uid

        if supabase_uid:
            try:
                self._supabase.auth.admin.update_user_by_id(
                    supabase_uid, {"password": inp.new_password}
                )
            except Exception as exc:
                logger.error(
                    "Supabase admin password update failed for user %s: %s", user.id, exc
                )
                raise

        # Update local bcrypt hash
        new_hash = _pwd_context.hash(inp.new_password)
        await self._user_repo.update(user.id, password_hash=new_hash)
        logger.info("Password reset complete for user %s", user.id)
