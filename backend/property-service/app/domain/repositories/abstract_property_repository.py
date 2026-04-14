"""Abstract repository interface for Property persistence.

Use cases depend solely on this interface — never on the concrete implementation.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from uuid import UUID

from app.domain.entities.property import Address, Property, PropertyType


class AbstractPropertyRepository(ABC):
    @abstractmethod
    async def list_by_owner(
        self,
        owner_id: UUID,
        *,
        city: str | None = None,
        property_type: PropertyType | None = None,
        is_active: bool | None = True,
        limit: int = 20,
        offset: int = 0,
    ) -> tuple[list[Property], int]:
        """Return a page of properties matching the given filters plus total count."""
        ...

    @abstractmethod
    async def list_all(
        self,
        *,
        owner_id: UUID | None = None,
        city: str | None = None,
        property_type: PropertyType | None = None,
        is_active: bool | None = True,
        limit: int = 20,
        offset: int = 0,
    ) -> tuple[list[Property], int]:
        """Return a page of properties with optional filters plus total count."""
        ...

    @abstractmethod
    async def get_by_id(self, property_id: UUID) -> Property | None:
        """Return a single Property by primary key, or None if not found."""
        ...

    @abstractmethod
    async def create(
        self,
        *,
        owner_id: UUID,
        name: str,
        address: Address,
        property_type: PropertyType,
        year_built: int | None,
        amenities: list[str],
        photos: list[str],
    ) -> Property:
        """Persist a new property record and return the created entity."""
        ...

    @abstractmethod
    async def update(self, property_id: UUID, **fields: object) -> Property:
        """Update arbitrary fields on an existing property and return the updated entity."""
        ...

    @abstractmethod
    async def soft_delete(self, property_id: UUID) -> Property:
        """Mark a property as inactive (is_active=False) and return the updated entity."""
        ...
