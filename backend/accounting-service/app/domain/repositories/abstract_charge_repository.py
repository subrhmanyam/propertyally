"""Abstract repository interface for RentCharge entities."""

from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import date
from uuid import UUID

from app.domain.entities.accounting import ChargeStatus, RentCharge


class AbstractChargeRepository(ABC):
    @abstractmethod
    async def get_by_id(self, charge_id: UUID) -> RentCharge | None:
        """Return a single charge by primary key, or None if not found."""
        ...

    @abstractmethod
    async def list_by_property(
        self,
        property_id: UUID,
        month: int,
        year: int,
    ) -> list[RentCharge]:
        """Return all charges for a property in the given period."""
        ...

    @abstractmethod
    async def list_by_tenant(self, tenant_id: UUID) -> list[RentCharge]:
        """Return all charges for a given tenant."""
        ...

    @abstractmethod
    async def bulk_insert(self, charges: list[RentCharge]) -> list[RentCharge]:
        """Insert multiple charges and return them with assigned IDs."""
        ...

    @abstractmethod
    async def update_status(self, charge_id: UUID, status: ChargeStatus) -> RentCharge:
        """Update the status of an existing charge and return the updated entity."""
        ...

    @abstractmethod
    async def waive(
        self,
        charge_id: UUID,
        waived_by: UUID,
        waive_reason: str,
    ) -> RentCharge:
        """Mark a charge as waived, recording who waived it and why."""
        ...

    @abstractmethod
    async def list_overdue(self, as_of: date) -> list[RentCharge]:
        """Return all PENDING charges whose due_date is before as_of."""
        ...

    @abstractmethod
    async def mark_overdue_bulk(self, as_of: date) -> int:
        """Mark all PENDING charges past due_date as OVERDUE. Returns count updated."""
        ...
