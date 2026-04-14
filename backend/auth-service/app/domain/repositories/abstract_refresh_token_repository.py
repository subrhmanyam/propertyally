"""Abstract repository interface for refresh token persistence."""

from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import datetime
from typing import Optional
from uuid import UUID


class AbstractRefreshTokenRepository(ABC):
    @abstractmethod
    async def create(
        self,
        *,
        user_id: UUID,
        token_hash: str,
        expires_at: datetime,
    ) -> UUID:
        """Persist a hashed refresh token, returning its row id."""
        ...

    @abstractmethod
    async def get_by_hash(self, token_hash: str) -> Optional[dict[str, object]]:
        """Return the refresh token record or None if not found / revoked."""
        ...

    @abstractmethod
    async def revoke(self, token_hash: str) -> None:
        """Mark the given token as revoked."""
        ...

    @abstractmethod
    async def revoke_all_for_user(self, user_id: UUID) -> None:
        """Revoke every active refresh token for the given user (logout-all)."""
        ...
