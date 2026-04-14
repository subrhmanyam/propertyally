"""Use case: WaiveCharge.

Allows an authorised manager to waive a rent charge with a mandatory reason.
"""

from __future__ import annotations

import logging
import uuid

from app.domain.entities.accounting import ChargeStatus, RentCharge
from app.domain.exceptions import (
    ChargeAlreadyPaidError,
    ChargeAlreadyWaivedError,
    ChargeNotFoundError,
)
from app.domain.repositories.abstract_charge_repository import AbstractChargeRepository

logger = logging.getLogger(__name__)


class WaiveCharge:
    """Waive an outstanding rent charge on behalf of a manager."""

    def __init__(self, charge_repo: AbstractChargeRepository) -> None:
        self._charge_repo = charge_repo

    async def execute(
        self,
        charge_id: uuid.UUID,
        waived_by: uuid.UUID,
        waive_reason: str,
    ) -> RentCharge:
        charge = await self._charge_repo.get_by_id(charge_id)
        if charge is None:
            raise ChargeNotFoundError(str(charge_id))

        if charge.status == ChargeStatus.WAIVED:
            raise ChargeAlreadyWaivedError(str(charge_id))

        if charge.status == ChargeStatus.PAID:
            raise ChargeAlreadyPaidError(str(charge_id))

        updated = await self._charge_repo.waive(
            charge_id=charge_id,
            waived_by=waived_by,
            waive_reason=waive_reason,
        )

        logger.info(
            "Charge %s waived by %s. Reason: %s", charge_id, waived_by, waive_reason
        )
        return updated
