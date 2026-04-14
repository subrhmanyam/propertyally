"""Abstract repository interface for Expense entities."""

from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import date
from uuid import UUID

from app.domain.entities.accounting import Expense, ExpenseCategory


class AbstractExpenseRepository(ABC):
    @abstractmethod
    async def get_by_id(self, expense_id: UUID) -> Expense | None:
        """Return a single expense by primary key, or None if not found."""
        ...

    @abstractmethod
    async def list_by_property(
        self,
        property_id: UUID,
        from_date: date | None = None,
        to_date: date | None = None,
        category: ExpenseCategory | None = None,
    ) -> list[Expense]:
        """Return expenses for a property, optionally filtered by date range and category."""
        ...

    @abstractmethod
    async def create(self, expense: Expense) -> Expense:
        """Persist a new expense and return the saved entity."""
        ...

    @abstractmethod
    async def update(self, expense: Expense) -> Expense:
        """Update an existing expense and return the updated entity."""
        ...

    @abstractmethod
    async def delete(self, expense_id: UUID) -> None:
        """Delete an expense by primary key."""
        ...
