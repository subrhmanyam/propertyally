"""RequestPasswordResetUseCase — initiate the password-reset OTP flow."""

from __future__ import annotations

import hashlib
import logging
import secrets
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from sqlalchemy.ext.asyncio import AsyncSession
from supabase import Client

from app.domain.repositories.abstract_user_repository import AbstractUserRepository

logger = logging.getLogger(__name__)

OTP_TTL_MINUTES = 10
OTP_BYTE_LENGTH = 6  # 6 random bytes → 12 hex chars → enough entropy for a short OTP


@dataclass
class RequestPasswordResetInput:
    email: str


class RequestPasswordResetUseCase:
    """
    Generate a one-time password-reset code, store it hashed in the DB, and
    trigger Supabase's built-in password reset email (which includes a magic
    link; we additionally store the OTP for a custom code-based flow).

    To prevent user enumeration we always return success regardless of whether
    the email is registered.
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

    async def execute(self, inp: RequestPasswordResetInput) -> None:
        email = inp.email.lower().strip()
        user = await self._user_repo.get_by_email(email)

        if user is None:
            # Silent success to prevent enumeration
            logger.debug("Password reset requested for unknown email %s", email)
            return

        # Generate a short numeric OTP (6 digits) for the custom code flow
        otp_raw = str(secrets.randbelow(900_000) + 100_000)  # 100000–999999
        otp_hash = hashlib.sha256(otp_raw.encode()).hexdigest()
        expires_at = datetime.now(tz=timezone.utc) + timedelta(minutes=OTP_TTL_MINUTES)

        # Persist the OTP
        from app.infrastructure.db.models import PasswordResetOTPModel

        otp_row = PasswordResetOTPModel(
            id=uuid.uuid4(),
            user_id=user.id,
            otp_hash=otp_hash,
            expires_at=expires_at,
            used=False,
        )
        self._session.add(otp_row)
        await self._session.flush()

        # Trigger Supabase's own reset email (magic link)
        try:
            self._supabase.auth.reset_password_email(email)
        except Exception as exc:
            logger.error("Supabase reset email failed for %s: %s", email, exc)
            # Don't raise — the OTP row is still persisted so the custom flow works

        # TODO: Emit an event / call notification-service with otp_raw so the
        #       user receives the numeric code via email.
        logger.info(
            "Password reset OTP created for user %s (expires %s)", user.id, expires_at
        )
