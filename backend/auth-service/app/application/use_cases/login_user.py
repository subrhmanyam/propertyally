"""LoginUserUseCase — validate credentials and issue a JWT pair."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from supabase import Client

from app.config import get_settings
from app.domain.entities.token import TokenPair
from app.domain.entities.user import User
from app.domain.exceptions import (
    AccountInactiveError,
    AccountLockedError,
    InvalidCredentialsError,
    UserNotFoundError,
)
from app.domain.repositories.abstract_user_repository import AbstractUserRepository

logger = logging.getLogger(__name__)


@dataclass
class LoginUserInput:
    email: str
    password: str


@dataclass
class LoginUserOutput:
    user: User
    tokens: TokenPair


class LoginUserUseCase:
    """
    Orchestrates login:
      1. Look up the user in the local DB (guards lockout before hitting Supabase).
      2. Reject if inactive or locked.
      3. Delegate credential validation to Supabase Auth.
      4. On success: stamp last_login, reset failure counter.
      5. On failure: increment failure counter, raise InvalidCredentialsError.
    """

    def __init__(
        self,
        user_repo: AbstractUserRepository,
        supabase: Client,
    ) -> None:
        self._user_repo = user_repo
        self._supabase = supabase

    async def execute(self, inp: LoginUserInput) -> LoginUserOutput:
        email = inp.email.lower().strip()
        settings = get_settings()

        # 1. Resolve user in our DB
        user = await self._user_repo.get_by_email(email)
        if user is None:
            # Avoid user-enumeration by always calling Supabase (timing equalisation)
            self._attempt_supabase_sign_in(email, inp.password)
            raise InvalidCredentialsError()

        # 2. Active check
        if not user.is_active:
            raise AccountInactiveError()

        # 3. Lockout check (needs raw model for counters)
        # Use the concrete repo's extended method if available
        from app.infrastructure.db.repositories.user_repository import UserRepository

        if isinstance(self._user_repo, UserRepository):
            model = await self._user_repo.get_model_by_id(user.id)
            if model is not None:
                self._check_lockout(model, settings)

        # 4. Supabase credential validation
        try:
            response = self._supabase.auth.sign_in_with_password(
                {"email": email, "password": inp.password}
            )
        except Exception as exc:
            logger.warning("Failed login attempt for %s: %s", email, exc)
            if isinstance(self._user_repo, UserRepository):
                await self._user_repo.increment_failed_login(user.id)
            raise InvalidCredentialsError() from exc

        if response.user is None or response.session is None:
            if isinstance(self._user_repo, UserRepository):
                await self._user_repo.increment_failed_login(user.id)
            raise InvalidCredentialsError()

        # 5. Stamp successful login
        await self._user_repo.record_login(user.id)

        # Refresh the entity after the update
        updated_user = await self._user_repo.get_by_id(user.id)
        if updated_user is None:
            raise UserNotFoundError(str(user.id))

        session = response.session
        logger.info("Successful login for user id=%s", user.id)

        return LoginUserOutput(
            user=updated_user,
            tokens=TokenPair(
                access_token=session.access_token,
                refresh_token=session.refresh_token,
            ),
        )

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _attempt_supabase_sign_in(self, email: str, password: str) -> None:
        """Fire-and-forget Supabase call to equalise timing for missing users."""
        try:
            self._supabase.auth.sign_in_with_password(
                {"email": email, "password": password}
            )
        except Exception:
            pass

    @staticmethod
    def _check_lockout(model: object, settings: object) -> None:
        """Raise AccountLockedError if the account is currently locked out."""
        from app.infrastructure.db.models import UserModel

        if not isinstance(model, UserModel):
            return

        max_attempts = settings.max_failed_login_attempts  # type: ignore[union-attr]
        window_minutes = settings.lockout_window_minutes  # type: ignore[union-attr]

        if model.failed_login_count < max_attempts:
            return

        window_start = model.failed_login_window_start
        if window_start is None:
            return

        # Make window_start offset-aware if it isn't already
        if window_start.tzinfo is None:
            window_start = window_start.replace(tzinfo=timezone.utc)

        window_end = window_start + timedelta(minutes=window_minutes)
        if datetime.now(tz=timezone.utc) < window_end:
            raise AccountLockedError()
