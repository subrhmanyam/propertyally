"""Use case: Get a single property with all its units."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from uuid import UUID

from app.domain.entities.property import Property, Unit
from app.domain.exceptions import PropertyNotFoundError
from app.domain.repositories.abstract_property_repository import AbstractPropertyRepository
from app.domain.repositories.abstract_unit_repository import AbstractUnitRepository

logger = logging.getLogger(__name__)


@dataclass
class GetPropertyOutput:
    property: Property
    units: list[Unit]


class GetPropertyUseCase:
    def __init__(
        self,
        property_repo: AbstractPropertyRepository,
        unit_repo: AbstractUnitRepository,
    ) -> None:
        self._property_repo = property_repo
        self._unit_repo = unit_repo

    async def execute(self, property_id: UUID) -> GetPropertyOutput:
        property_ = await self._property_repo.get_by_id(property_id)
        if property_ is None:
            raise PropertyNotFoundError(str(property_id))

        units = await self._unit_repo.list_by_property(property_id)

        logger.debug("get_property", extra={"property_id": str(property_id)})
        return GetPropertyOutput(property=property_, units=units)
