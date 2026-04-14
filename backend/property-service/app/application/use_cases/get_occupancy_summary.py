"""Use case: Get occupancy statistics for a property via stored procedure."""

from __future__ import annotations

import logging
from uuid import UUID

from app.domain.entities.property import OccupancySummary
from app.domain.exceptions import PropertyNotFoundError
from app.domain.repositories.abstract_property_repository import AbstractPropertyRepository
from app.domain.repositories.abstract_unit_repository import AbstractUnitRepository

logger = logging.getLogger(__name__)


class GetOccupancySummaryUseCase:
    def __init__(
        self,
        property_repo: AbstractPropertyRepository,
        unit_repo: AbstractUnitRepository,
    ) -> None:
        self._property_repo = property_repo
        self._unit_repo = unit_repo

    async def execute(self, property_id: UUID) -> OccupancySummary:
        property_ = await self._property_repo.get_by_id(property_id)
        if property_ is None:
            raise PropertyNotFoundError(str(property_id))

        summary = await self._unit_repo.get_occupancy_summary(property_id)

        logger.debug(
            "get_occupancy_summary",
            extra={
                "property_id": str(property_id),
                "total_units": summary.total_units,
                "occupancy_rate": str(summary.occupancy_rate),
            },
        )
        return summary
