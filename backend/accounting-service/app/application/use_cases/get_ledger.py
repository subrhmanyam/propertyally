"""Use case: GetLedger.

Returns ledger entries for a property within a date range.
"""

from __future__ import annotations

import logging
import uuid
from datetime import date

from app.domain.entities.accounting import LedgerEntry
from app.domain.repositories.abstract_ledger_repository import AbstractLedgerRepository

logger = logging.getLogger(__name__)


class GetLedger:
    """Return ledger entries for a property over a date range."""

    def __init__(self, ledger_repo: AbstractLedgerRepository) -> None:
        self._ledger_repo = ledger_repo

    async def execute(
        self,
        property_id: uuid.UUID,
        from_date: date,
        to_date: date,
    ) -> list[LedgerEntry]:
        entries = await self._ledger_repo.list_by_property(
            property_id=property_id,
            from_date=from_date,
            to_date=to_date,
        )
        logger.info(
            "Ledger: %d entries for property %s from %s to %s",
            len(entries),
            property_id,
            from_date,
            to_date,
        )
        return entries
