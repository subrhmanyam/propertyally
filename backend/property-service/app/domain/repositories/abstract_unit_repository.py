"""Abstract repository interface for Unit persistence.

Use cases depend solely on this interface — never on the concrete implementation.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from decimal import Decimal
from uuid import UUID

from app.domain.entities.property import OccupancySummary, Unit, UnitStatus


class AbstractUnitRepository(ABC):
    @abstractmethod
    async def list_by_property(
        self,
        property_id: UUID,
        *,
        status: UnitStatus | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> list[Unit]:
        """Return all units belonging to the given property, with optional status filter."""
        ...

    @abstractmethod
    async def get_by_id(self, unit_id: UUID) -> Unit | None:
        """Return a single Unit by primary key, or None if not found."""
        ...

    @abstractmethod
    async def get_by_number(self, property_id: UUID, unit_number: str) -> Unit | None:
        """Return a unit by its human-readable unit_number within a property, or None."""
        ...

    @abstractmethod
    async def create(
        self,
        *,
        property_id: UUID,
        unit_number: str,
        bedrooms: int,
        bathrooms: Decimal,
        square_feet: int | None,
        rent_amount: Decimal,
        deposit_amount: Decimal,
        floor: int | None,
        features: list[str],
        photos: list[str],
    ) -> Unit:
        """Persist a new unit record and return the created entity."""
        ...

    @abstractmethod
    async def update(self, unit_id: UUID, **fields: object) -> Unit:
        """Update arbitrary fields on an existing unit and return the updated entity."""
        ...

    @abstractmethod
    async def update_status(self, unit_id: UUID, status: UnitStatus) -> Unit:
        """Change the occupancy status of a unit and return the updated entity."""
        ...

    @abstractmethod
    async def get_occupancy_summary(self, property_id: UUID) -> OccupancySummary:
        """Return aggregated occupancy counts for the given property via stored procedure."""
        ...
