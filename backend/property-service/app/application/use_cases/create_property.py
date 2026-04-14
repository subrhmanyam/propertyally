"""Use case: Create a new property."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from uuid import UUID

from app.domain.entities.property import Address, Property, PropertyType
from app.domain.repositories.abstract_property_repository import AbstractPropertyRepository

logger = logging.getLogger(__name__)


@dataclass
class CreatePropertyInput:
    owner_id: UUID
    name: str
    street: str
    city: str
    state: str
    zip_code: str
    country: str
    property_type: PropertyType
    year_built: int | None
    amenities: list[str]
    photos: list[str]


class CreatePropertyUseCase:
    def __init__(self, property_repo: AbstractPropertyRepository) -> None:
        self._property_repo = property_repo

    async def execute(self, data: CreatePropertyInput) -> Property:
        address = Address(
            street=data.street,
            city=data.city,
            state=data.state,
            zip_code=data.zip_code,
            country=data.country,
        )

        property_ = await self._property_repo.create(
            owner_id=data.owner_id,
            name=data.name,
            address=address,
            property_type=data.property_type,
            year_built=data.year_built,
            amenities=data.amenities,
            photos=data.photos,
        )

        logger.info(
            "property.created",
            extra={"property_id": str(property_.id), "owner_id": str(data.owner_id)},
        )
        return property_
