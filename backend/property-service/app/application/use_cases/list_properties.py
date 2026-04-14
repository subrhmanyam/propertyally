"""Use case: List properties with pagination and optional filters."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from uuid import UUID

from app.domain.entities.property import Property, PropertyType
from app.domain.repositories.abstract_property_repository import AbstractPropertyRepository

logger = logging.getLogger(__name__)


@dataclass
class ListPropertiesInput:
    owner_id: UUID | None = None
    city: str | None = None
    property_type: PropertyType | None = None
    is_active: bool | None = True
    page: int = 1
    page_size: int = 20


@dataclass
class ListPropertiesOutput:
    items: list[Property]
    total: int
    page: int
    page_size: int
    total_pages: int


class ListPropertiesUseCase:
    def __init__(self, property_repo: AbstractPropertyRepository) -> None:
        self._property_repo = property_repo

    async def execute(self, data: ListPropertiesInput) -> ListPropertiesOutput:
        limit = data.page_size
        offset = (data.page - 1) * data.page_size

        properties, total = await self._property_repo.list_all(
            owner_id=data.owner_id,
            city=data.city,
            property_type=data.property_type,
            is_active=data.is_active,
            limit=limit,
            offset=offset,
        )

        total_pages = max(1, (total + limit - 1) // limit)

        logger.debug(
            "list_properties",
            extra={
                "owner_id": str(data.owner_id) if data.owner_id else None,
                "city": data.city,
                "total": total,
                "page": data.page,
            },
        )

        return ListPropertiesOutput(
            items=properties,
            total=total,
            page=data.page,
            page_size=data.page_size,
            total_pages=total_pages,
        )
