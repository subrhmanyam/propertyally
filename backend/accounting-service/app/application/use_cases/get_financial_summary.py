"""Use case: GetFinancialSummary.

Delegates to the ledger repository which calls the stored procedure
`accounting.get_financial_summary` to compute revenue, expenses, net income,
and outstanding balance for a property over a date range.
"""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass
from datetime import date
from decimal import Decimal

from app.domain.repositories.abstract_ledger_repository import AbstractLedgerRepository

logger = logging.getLogger(__name__)


@dataclass
class FinancialSummary:
    property_id: uuid.UUID
    from_date: date
    to_date: date
    total_revenue: Decimal
    total_expenses: Decimal
    net_income: Decimal
    outstanding: Decimal


class GetFinancialSummary:
    """Return aggregated financial metrics for a property over a date range."""

    def __init__(self, ledger_repo: AbstractLedgerRepository) -> None:
        self._ledger_repo = ledger_repo

    async def execute(
        self,
        property_id: uuid.UUID,
        from_date: date,
        to_date: date,
    ) -> FinancialSummary:
        result = await self._ledger_repo.get_financial_summary(
            property_id=property_id,
            from_date=from_date,
            to_date=to_date,
        )

        summary = FinancialSummary(
            property_id=property_id,
            from_date=from_date,
            to_date=to_date,
            total_revenue=result.get("total_revenue", Decimal("0")),
            total_expenses=result.get("total_expenses", Decimal("0")),
            net_income=result.get("net_income", Decimal("0")),
            outstanding=result.get("outstanding", Decimal("0")),
        )

        logger.info(
            "Financial summary for property %s: revenue=%.2f, expenses=%.2f, net=%.2f",
            property_id,
            summary.total_revenue,
            summary.total_expenses,
            summary.net_income,
        )
        return summary
