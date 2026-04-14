"""Abstract repository interface for User persistence.

Use cases depend on this interface only — never on the concrete implementation.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Optional
from uuid import UUID

from app.domain.entities.user import User, UserRole


class AbstractUserRepository(ABC):
    @abstractmethod
    async def get_by_id(self, user_id: UUID) -> Optional[User]:
        """Return a User by primary key, or None if not found."""
        ...

    @abstractmethod
    async def get_by_email(self, email: str) -> Optional[User]:
        """Return a User by unique email address, or None if not found."""
        ...

    @abstractmethod
    async def create(
        self,
        *,
        id: UUID,
        email: str,
        password_hash: str,
        full_name: str,
        role: UserRole,
    ) -> User:
        """Persist a new user record and return the created entity."""
        ...

    @abstractmethod
    async def update(self, user_id: UUID, **fields: object) -> User:
        """Update arbitrary fields on an existing user and return the updated entity."""
        ...

    @abstractmethod
    async def record_login(self, user_id: UUID) -> None:
        """Stamp the last_login timestamp for the given user."""
        ...
