"""Use case: GetFinancialSummaryInline — calls accounting-service and returns JSON."""

from __future__ import annotations

import logging
from typing import Any
from uuid import UUID

from app.domain.exceptions import ExternalServiceError
from app.infrastructure.external.accounting_client import AccountingClient

logger = logging.getLogger(__name__)


class GetFinancialSummaryInline:
    """Returns financial summary as a structured dict (no PDF generation)."""

    def __init__(self, accounting_client: AccountingClient) -> None:
        self._accounting = accounting_client

    async def execute(
        self,
        property_id: UUID,
        from_date: str,
        to_date: str,
    ) -> dict[str, Any]:
        logger.info(
            "Inline financial summary: property=%s from=%s to=%s",
            property_id,
            from_date,
            to_date,
        )
        try:
            data = await self._accounting.get_financial_summary(
                property_id=str(property_id),
                from_date=from_date,
                to_date=to_date,
            )
        except Exception as exc:
            raise ExternalServiceError(f"Failed to fetch financial summary: {exc}") from exc

        return data
