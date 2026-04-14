"""Use case: GetRentRoll.

Retrieves all rent charges for a property in a given month, including tenant
and unit metadata sourced from the charge records themselves.  The result is a
flat rent-roll view suited for financial reporting.
"""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass
from decimal import Decimal

from app.domain.entities.accounting import ChargeStatus, RentCharge
from app.domain.repositories.abstract_charge_repository import AbstractChargeRepository

logger = logging.getLogger(__name__)


@dataclass
class RentRollRow:
    charge_id: uuid.UUID
    tenant_id: uuid.UUID
    unit_id: uuid.UUID
    property_id: uuid.UUID
    amount: Decimal
    due_date: object  # date
    period_month: int
    period_year: int
    status: ChargeStatus
    waive_reason: str | None


class GetRentRoll:
    """Return the rent roll for a property and period."""

    def __init__(self, charge_repo: AbstractChargeRepository) -> None:
        self._charge_repo = charge_repo

    async def execute(
        self,
        property_id: uuid.UUID,
        month: int,
        year: int,
    ) -> list[RentRollRow]:
        charges: list[RentCharge] = await self._charge_repo.list_by_property(
            property_id=property_id, month=month, year=year
        )

        rows = [
            RentRollRow(
                charge_id=c.id,
                tenant_id=c.tenant_id,
                unit_id=c.unit_id,
                property_id=c.property_id,
                amount=c.amount,
                due_date=c.due_date,
                period_month=c.period_month,
                period_year=c.period_year,
                status=c.status,
                waive_reason=c.waive_reason,
            )
            for c in charges
        ]

        logger.info(
            "Rent roll: %d rows for property %s %d/%d", len(rows), property_id, month, year
        )
        return rows
