"""Use case: Soft-delete a property (marks is_active=False)."""

from __future__ import annotations

import logging
from uuid import UUID

from app.domain.entities.property import Property
from app.domain.exceptions import PropertyNotFoundError
from app.domain.repositories.abstract_property_repository import AbstractPropertyRepository

logger = logging.getLogger(__name__)


class DeletePropertyUseCase:
    def __init__(self, property_repo: AbstractPropertyRepository) -> None:
        self._property_repo = property_repo

    async def execute(self, property_id: UUID) -> Property:
        existing = await self._property_repo.get_by_id(property_id)
        if existing is None:
            raise PropertyNotFoundError(str(property_id))

        deleted = await self._property_repo.soft_delete(property_id)

        logger.info("property.deleted", extra={"property_id": str(property_id)})
        return deleted
