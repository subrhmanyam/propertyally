"""Concrete SQLAlchemy implementation of AbstractRefreshTokenRepository."""

from __future__ import annotations

import logging
import uuid
from datetime import datetime
from typing import Optional
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.repositories.abstract_refresh_token_repository import (
    AbstractRefreshTokenRepository,
)
from app.infrastructure.db.models import RefreshTokenModel

logger = logging.getLogger(__name__)


class RefreshTokenRepository(AbstractRefreshTokenRepository):
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(
        self,
        *,
        user_id: UUID,
        token_hash: str,
        expires_at: datetime,
    ) -> UUID:
        row = RefreshTokenModel(
            id=uuid.uuid4(),
            user_id=user_id,
            token_hash=token_hash,
            expires_at=expires_at,
            revoked=False,
        )
        self._session.add(row)
        await self._session.flush()
        logger.debug("Stored refresh token for user_id=%s", user_id)
        return row.id

    async def get_by_hash(self, token_hash: str) -> Optional[dict[str, object]]:
        stmt = select(RefreshTokenModel).where(
            RefreshTokenModel.token_hash == token_hash,
            RefreshTokenModel.revoked.is_(False),
        )
        result = await self._session.execute(stmt)
        row = result.scalar_one_or_none()
        if row is None:
            return None
        return {
            "id": row.id,
            "user_id": row.user_id,
            "expires_at": row.expires_at,
            "revoked": row.revoked,
            "created_at": row.created_at,
        }

    async def revoke(self, token_hash: str) -> None:
        stmt = (
            update(RefreshTokenModel)
            .where(RefreshTokenModel.token_hash == token_hash)
            .values(revoked=True)
        )
        await self._session.execute(stmt)
        logger.debug("Revoked refresh token hash=%s…", token_hash[:8])

    async def revoke_all_for_user(self, user_id: UUID) -> None:
        stmt = (
            update(RefreshTokenModel)
            .where(
                RefreshTokenModel.user_id == user_id,
                RefreshTokenModel.revoked.is_(False),
            )
            .values(revoked=True)
        )
        await self._session.execute(stmt)
        logger.info("Revoked all refresh tokens for user_id=%s", user_id)
