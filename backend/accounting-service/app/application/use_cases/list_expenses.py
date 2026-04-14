"""Use case: ListExpenses.

Retrieves expenses for a property, optionally filtered by date range and category.
"""

from __future__ import annotations

import logging
import uuid
from datetime import date

from app.domain.entities.accounting import Expense, ExpenseCategory
from app.domain.repositories.abstract_expense_repository import AbstractExpenseRepository

logger = logging.getLogger(__name__)


class ListExpenses:
    """List expenses for a property with optional filters."""

    def __init__(self, expense_repo: AbstractExpenseRepository) -> None:
        self._expense_repo = expense_repo

    async def execute(
        self,
        property_id: uuid.UUID,
        from_date: date | None = None,
        to_date: date | None = None,
        category: ExpenseCategory | None = None,
    ) -> list[Expense]:
        expenses = await self._expense_repo.list_by_property(
            property_id=property_id,
            from_date=from_date,
            to_date=to_date,
            category=category,
        )
        logger.info(
            "Listed %d expenses for property %s", len(expenses), property_id
        )
        return expenses
