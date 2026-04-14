"""Use case: CreateExpense.

Persists an expense record and posts a debit entry to the property ledger.
Both operations happen within the same DB transaction via the repositories.
"""

from __future__ import annotations

import logging
import uuid
from datetime import date
from decimal import Decimal

from app.domain.entities.accounting import Expense, ExpenseCategory
from app.domain.repositories.abstract_expense_repository import AbstractExpenseRepository
from app.domain.repositories.abstract_ledger_repository import AbstractLedgerRepository

logger = logging.getLogger(__name__)


class CreateExpense:
    """Record a new property expense and post a debit to the ledger."""

    def __init__(
        self,
        expense_repo: AbstractExpenseRepository,
        ledger_repo: AbstractLedgerRepository,
    ) -> None:
        self._expense_repo = expense_repo
        self._ledger_repo = ledger_repo

    async def execute(
        self,
        property_id: uuid.UUID,
        category: ExpenseCategory,
        description: str,
        amount: Decimal,
        expense_date: date,
        vendor_name: str | None = None,
        receipt_url: str | None = None,
    ) -> Expense:
        expense = Expense(
            id=uuid.uuid4(),
            property_id=property_id,
            category=category,
            description=description,
            amount=amount,
            expense_date=expense_date,
            created_at=date.today(),  # type: ignore[arg-type]
            vendor_name=vendor_name,
            receipt_url=receipt_url,
        )

        saved_expense = await self._expense_repo.create(expense)

        ledger_description = f"{category.value} expense: {description}"
        if vendor_name:
            ledger_description += f" ({vendor_name})"

        await self._ledger_repo.post_debit(
            property_id=property_id,
            entry_date=expense_date,
            description=ledger_description,
            amount=amount,
            reference_id=saved_expense.id,
            reference_type="EXPENSE",
        )

        logger.info(
            "Expense %s created for property %s — %.2f [%s]",
            saved_expense.id,
            property_id,
            amount,
            category.value,
        )
        return saved_expense
