"""Use case: Update an existing unit's details (rent, features, etc.)."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from decimal import Decimal
from uuid import UUID

from app.domain.entities.property import Unit
from app.domain.exceptions import UnitNotFoundError
from app.domain.repositories.abstract_unit_repository import AbstractUnitRepository

logger = logging.getLogger(__name__)


@dataclass
class UpdateUnitInput:
    unit_id: UUID
    unit_number: str | None = None
    bedrooms: int | None = None
    bathrooms: Decimal | None = None
    square_feet: int | None = None
    rent_amount: Decimal | None = None
    deposit_amount: Decimal | None = None
    floor: int | None = None
    features: list[str] | None = None
    photos: list[str] | None = None


class UpdateUnitUseCase:
    def __init__(self, unit_repo: AbstractUnitRepository) -> None:
        self._unit_repo = unit_repo

    async def execute(self, data: UpdateUnitInput) -> Unit:
        existing = await self._unit_repo.get_by_id(data.unit_id)
        if existing is None:
            raise UnitNotFoundError(str(data.unit_id))

        updates: dict[str, object] = {}
        if data.unit_number is not None:
            updates["unit_number"] = data.unit_number
        if data.bedrooms is not None:
            updates["bedrooms"] = data.bedrooms
        if data.bathrooms is not None:
            updates["bathrooms"] = data.bathrooms
        if data.square_feet is not None:
            updates["square_feet"] = data.square_feet
        if data.rent_amount is not None:
            updates["rent_amount"] = data.rent_amount
        if data.deposit_amount is not None:
            updates["deposit_amount"] = data.deposit_amount
        if data.floor is not None:
            updates["floor"] = data.floor
        if data.features is not None:
            updates["features"] = data.features
        if data.photos is not None:
            updates["photos"] = data.photos

        if not updates:
            return existing

        updated = await self._unit_repo.update(data.unit_id, **updates)

        logger.info(
            "unit.updated",
            extra={"unit_id": str(data.unit_id), "fields": list(updates.keys())},
        )
        return updated
