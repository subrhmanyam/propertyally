"""RegisterUserUseCase — create a new account via Supabase auth + local DB."""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass

from passlib.context import CryptContext
from supabase import Client

from app.domain.entities.token import TokenPair
from app.domain.entities.user import User, UserRole
from app.domain.exceptions import EmailAlreadyExistsError, InvalidCredentialsError
from app.domain.repositories.abstract_user_repository import AbstractUserRepository

logger = logging.getLogger(__name__)

_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto", bcrypt__rounds=12)


@dataclass
class RegisterUserInput:
    email: str
    password: str
    full_name: str
    role: UserRole


@dataclass
class RegisterUserOutput:
    user: User
    tokens: TokenPair


class RegisterUserUseCase:
    """
    Orchestrates user registration:
      1. Verify the email is not already taken in our DB.
      2. Create the user in Supabase Auth (which sends the verification email).
      3. Persist a local user row (bcrypt password hash + supabase_uid).
      4. Return domain entity + token pair from Supabase.
    """

    def __init__(
        self,
        user_repo: AbstractUserRepository,
        supabase: Client,
    ) -> None:
        self._user_repo = user_repo
        self._supabase = supabase

    async def execute(self, inp: RegisterUserInput) -> RegisterUserOutput:
        email = inp.email.lower().strip()

        # 1. Guard against duplicate email
        existing = await self._user_repo.get_by_email(email)
        if existing is not None:
            raise EmailAlreadyExistsError(email)

        # 2. Create user in Supabase Auth
        try:
            response = self._supabase.auth.sign_up(
                {
                    "email": email,
                    "password": inp.password,
                    "options": {
                        "data": {
                            "full_name": inp.full_name,
                            "role": inp.role.value,
                        }
                    },
                }
            )
        except Exception as exc:
            logger.error("Supabase sign_up failed for %s: %s", email, exc)
            # Surface as a generic credential error — don't leak internals
            raise InvalidCredentialsError() from exc

        if response.user is None:
            logger.error("Supabase sign_up returned no user for %s", email)
            raise InvalidCredentialsError()

        supabase_user = response.user
        supabase_uid = str(supabase_user.id)

        # Extract tokens — Supabase returns a session immediately when email
        # confirmation is disabled; when enabled, session may be None.
        session = response.session
        access_token = session.access_token if session else ""
        refresh_token = session.refresh_token if session else ""

        # 3. Hash the password for local storage (service-layer defence-in-depth)
        password_hash = _pwd_context.hash(inp.password)

        # 4. Persist the user row
        local_id = uuid.UUID(supabase_uid) if supabase_uid else uuid.uuid4()
        try:
            user = await self._user_repo.create(
                id=local_id,
                email=email,
                password_hash=password_hash,
                full_name=inp.full_name,
                role=inp.role,
                supabase_uid=supabase_uid,
            )
        except Exception as exc:
            logger.error("DB user creation failed for %s: %s", email, exc)
            # Best-effort cleanup: remove Supabase user so DB stays authoritative
            try:
                self._supabase.auth.admin.delete_user(supabase_uid)
            except Exception:
                pass
            raise

        logger.info("Registered user id=%s email=%s role=%s", user.id, user.email, user.role)

        return RegisterUserOutput(
            user=user,
            tokens=TokenPair(
                access_token=access_token,
                refresh_token=refresh_token,
            ),
        )
