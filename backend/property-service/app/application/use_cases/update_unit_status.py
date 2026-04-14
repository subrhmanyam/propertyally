"""Use case: Change the occupancy status of a unit."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from uuid import UUID

from app.domain.entities.property import Unit, UnitStatus
from app.domain.exceptions import UnitNotFoundError
from app.domain.repositories.abstract_unit_repository import AbstractUnitRepository

logger = logging.getLogger(__name__)


@dataclass
class UpdateUnitStatusInput:
    unit_id: UUID
    status: UnitStatus


class UpdateUnitStatusUseCase:
    def __init__(self, unit_repo: AbstractUnitRepository) -> None:
        self._unit_repo = unit_repo

    async def execute(self, data: UpdateUnitStatusInput) -> Unit:
        existing = await self._unit_repo.get_by_id(data.unit_id)
        if existing is None:
            raise UnitNotFoundError(str(data.unit_id))

        previous_status = existing.status
        updated = await self._unit_repo.update_status(data.unit_id, data.status)

        logger.info(
            "unit.status_changed",
            extra={
                "unit_id": str(data.unit_id),
                "property_id": str(updated.property_id),
                "previous_status": previous_status.value,
                "new_status": data.status.value,
            },
        )
        return updated
