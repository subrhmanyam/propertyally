"""Concrete SQLAlchemy implementation of AbstractUserRepository."""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.entities.user import User, UserRole
from app.domain.exceptions import UserNotFoundError
from app.domain.repositories.abstract_user_repository import AbstractUserRepository
from app.infrastructure.db.models import UserModel

logger = logging.getLogger(__name__)


def _to_entity(row: UserModel) -> User:
    """Map an ORM row to a pure domain entity."""
    return User(
        id=row.id,
        email=row.email,
        full_name=row.full_name,
        role=UserRole(row.role),
        is_active=row.is_active,
        is_verified=row.is_verified,
        created_at=row.created_at,
        last_login=row.last_login,
        updated_at=row.updated_at,
    )


class UserRepository(AbstractUserRepository):
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, user_id: UUID) -> Optional[User]:
        stmt = select(UserModel).where(UserModel.id == user_id)
        result = await self._session.execute(stmt)
        row = result.scalar_one_or_none()
        return _to_entity(row) if row else None

    async def get_by_email(self, email: str) -> Optional[User]:
        stmt = select(UserModel).where(UserModel.email == email.lower().strip())
        result = await self._session.execute(stmt)
        row = result.scalar_one_or_none()
        return _to_entity(row) if row else None

    async def get_model_by_email(self, email: str) -> Optional[UserModel]:
        """Return the raw ORM row — used internally for auth checks that need password_hash."""
        stmt = select(UserModel).where(UserModel.email == email.lower().strip())
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_model_by_id(self, user_id: UUID) -> Optional[UserModel]:
        stmt = select(UserModel).where(UserModel.id == user_id)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def create(
        self,
        *,
        id: UUID,
        email: str,
        password_hash: str,
        full_name: str,
        role: UserRole,
        supabase_uid: str | None = None,
    ) -> User:
        row = UserModel(
            id=id,
            email=email.lower().strip(),
            password_hash=password_hash,
            full_name=full_name,
            role=role.value,
            is_active=True,
            is_verified=False,
            supabase_uid=supabase_uid,
        )
        self._session.add(row)
        await self._session.flush()
        await self._session.refresh(row)
        logger.info("Created user id=%s email=%s role=%s", row.id, row.email, row.role)
        return _to_entity(row)

    async def update(self, user_id: UUID, **fields: object) -> User:
        # Normalise email if included in the update
        if "email" in fields and isinstance(fields["email"], str):
            fields["email"] = fields["email"].lower().strip()
        fields["updated_at"] = datetime.now(tz=timezone.utc)

        stmt = (
            update(UserModel)
            .where(UserModel.id == user_id)
            .values(**fields)
            .returning(UserModel)
        )
        result = await self._session.execute(stmt)
        row = result.scalar_one_or_none()
        if row is None:
            raise UserNotFoundError(str(user_id))
        return _to_entity(row)

    async def record_login(self, user_id: UUID) -> None:
        stmt = (
            update(UserModel)
            .where(UserModel.id == user_id)
            .values(
                last_login=datetime.now(tz=timezone.utc),
                failed_login_count=0,
                failed_login_window_start=None,
            )
        )
        await self._session.execute(stmt)

    async def increment_failed_login(self, user_id: UUID) -> None:
        """Increment the failed-login counter, setting the window start if not already set."""
        row = await self.get_model_by_id(user_id)
        if row is None:
            return
        now = datetime.now(tz=timezone.utc)
        stmt = (
            update(UserModel)
            .where(UserModel.id == user_id)
            .values(
                failed_login_count=UserModel.failed_login_count + 1,
                failed_login_window_start=(
                    now if row.failed_login_window_start is None else row.failed_login_window_start
                ),
            )
        )
        await self._session.execute(stmt)

    async def reset_failed_login(self, user_id: UUID) -> None:
        stmt = (
            update(UserModel)
            .where(UserModel.id == user_id)
            .values(failed_login_count=0, failed_login_window_start=None)
        )
        await self._session.execute(stmt)
