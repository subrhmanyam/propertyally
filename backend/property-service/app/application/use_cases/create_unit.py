"""Use case: Add a new unit to an existing property."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from decimal import Decimal
from uuid import UUID

from app.domain.entities.property import Unit
from app.domain.exceptions import DuplicateUnitNumberError, PropertyNotFoundError
from app.domain.repositories.abstract_property_repository import AbstractPropertyRepository
from app.domain.repositories.abstract_unit_repository import AbstractUnitRepository

logger = logging.getLogger(__name__)


@dataclass
class CreateUnitInput:
    property_id: UUID
    unit_number: str
    bedrooms: int
    bathrooms: Decimal
    rent_amount: Decimal
    deposit_amount: Decimal
    square_feet: int | None
    floor: int | None
    features: list[str]
    photos: list[str]


class CreateUnitUseCase:
    def __init__(
        self,
        property_repo: AbstractPropertyRepository,
        unit_repo: AbstractUnitRepository,
    ) -> None:
        self._property_repo = property_repo
        self._unit_repo = unit_repo

    async def execute(self, data: CreateUnitInput) -> Unit:
        # Ensure the parent property exists and is active.
        property_ = await self._property_repo.get_by_id(data.property_id)
        if property_ is None:
            raise PropertyNotFoundError(str(data.property_id))

        # Guard against duplicate unit numbers on the same property.
        existing_unit = await self._unit_repo.get_by_number(data.property_id, data.unit_number)
        if existing_unit is not None:
            raise DuplicateUnitNumberError(data.unit_number, str(data.property_id))

        unit = await self._unit_repo.create(
            property_id=data.property_id,
            unit_number=data.unit_number,
            bedrooms=data.bedrooms,
            bathrooms=data.bathrooms,
            square_feet=data.square_feet,
            rent_amount=data.rent_amount,
            deposit_amount=data.deposit_amount,
            floor=data.floor,
            features=data.features,
            photos=data.photos,
        )

        logger.info(
            "unit.created",
            extra={
                "unit_id": str(unit.id),
                "property_id": str(data.property_id),
                "unit_number": data.unit_number,
            },
        )
        return unit
