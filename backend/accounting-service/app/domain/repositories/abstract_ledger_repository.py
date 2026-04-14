"""Abstract repository interface for LedgerEntry entities."""

from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import date
from decimal import Decimal
from uuid import UUID

from app.domain.entities.accounting import LedgerEntry


class AbstractLedgerRepository(ABC):
    @abstractmethod
    async def list_by_property(
        self,
        property_id: UUID,
        from_date: date,
        to_date: date,
    ) -> list[LedgerEntry]:
        """Return ledger entries for a property within the specified date range."""
        ...

    @abstractmethod
    async def post_debit(
        self,
        property_id: UUID,
        entry_date: date,
        description: str,
        amount: Decimal,
        reference_id: UUID,
        reference_type: str,
    ) -> LedgerEntry:
        """Post a debit entry to the ledger (e.g. an expense) and return the entry."""
        ...

    @abstractmethod
    async def get_financial_summary(
        self,
        property_id: UUID,
        from_date: date,
        to_date: date,
    ) -> dict[str, Decimal]:
        """Call the stored procedure and return a dict with keys:
        total_revenue, total_expenses, net_income, outstanding.
        """
        ...
