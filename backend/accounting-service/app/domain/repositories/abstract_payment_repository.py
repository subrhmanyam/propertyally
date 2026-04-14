"""Abstract repository interface for Payment entities."""

from __future__ import annotations

from abc import ABC, abstractmethod
from uuid import UUID

from app.domain.entities.accounting import Payment


class AbstractPaymentRepository(ABC):
    @abstractmethod
    async def get_by_id(self, payment_id: UUID) -> Payment | None:
        """Return a single payment by primary key, or None if not found."""
        ...

    @abstractmethod
    async def list_by_charge(self, rent_charge_id: UUID) -> list[Payment]:
        """Return all payments for a given rent charge."""
        ...

    @abstractmethod
    async def list_by_tenant(self, tenant_id: UUID) -> list[Payment]:
        """Return all payments made by a tenant."""
        ...

    @abstractmethod
    async def record_payment_and_post_ledger(
        self,
        charge_id: UUID,
        tenant_id: UUID,
        property_id: UUID,
        amount: float,
        method: str,
        transaction_ref: str,
        description: str,
    ) -> UUID:
        """Call the stored procedure to atomically record payment and post to ledger.

        Returns the new payment ID.
        """
        ...

    @abstractmethod
    async def refund(self, payment_id: UUID) -> Payment:
        """Mark a payment as REFUNDED and return the updated entity."""
        ...
