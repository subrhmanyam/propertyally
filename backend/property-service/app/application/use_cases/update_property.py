"""Use case: Update an existing property's details."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from uuid import UUID

from app.domain.entities.property import Property, PropertyType
from app.domain.exceptions import PropertyNotFoundError
from app.domain.repositories.abstract_property_repository import AbstractPropertyRepository

logger = logging.getLogger(__name__)


@dataclass
class UpdatePropertyInput:
    property_id: UUID
    name: str | None = None
    street: str | None = None
    city: str | None = None
    state: str | None = None
    zip_code: str | None = None
    country: str | None = None
    property_type: PropertyType | None = None
    year_built: int | None = None
    amenities: list[str] | None = None
    photos: list[str] | None = None


class UpdatePropertyUseCase:
    def __init__(self, property_repo: AbstractPropertyRepository) -> None:
        self._property_repo = property_repo

    async def execute(self, data: UpdatePropertyInput) -> Property:
        existing = await self._property_repo.get_by_id(data.property_id)
        if existing is None:
            raise PropertyNotFoundError(str(data.property_id))

        # Build the dict of fields to update — skip None values so callers
        # only need to supply what they actually want to change.
        updates: dict[str, object] = {}
        if data.name is not None:
            updates["name"] = data.name
        if data.street is not None:
            updates["street"] = data.street
        if data.city is not None:
            updates["city"] = data.city
        if data.state is not None:
            updates["state"] = data.state
        if data.zip_code is not None:
            updates["zip_code"] = data.zip_code
        if data.country is not None:
            updates["country"] = data.country
        if data.property_type is not None:
            updates["property_type"] = data.property_type
        if data.year_built is not None:
            updates["year_built"] = data.year_built
        if data.amenities is not None:
            updates["amenities"] = data.amenities
        if data.photos is not None:
            updates["photos"] = data.photos

        if not updates:
            # Nothing to change — return existing entity unchanged.
            return existing

        updated = await self._property_repo.update(data.property_id, **updates)

        logger.info(
            "property.updated",
            extra={"property_id": str(data.property_id), "fields": list(updates.keys())},
        )
        return updated
