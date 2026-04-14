"""Use case: Get a template by ID or list templates for a property."""

from __future__ import annotations

import logging
from uuid import UUID

from app.domain.entities.application import ApplicationTemplate
from app.domain.exceptions import TemplateNotFoundError
from app.domain.repositories.abstract_template_repository import AbstractTemplateRepository

logger = logging.getLogger(__name__)


class GetTemplateUseCase:
    def __init__(self, template_repo: AbstractTemplateRepository) -> None:
        self._repo = template_repo

    async def execute(self, template_id: UUID) -> ApplicationTemplate:
        template = await self._repo.get_by_id(template_id)
        if template is None:
            raise TemplateNotFoundError(template_id)
        return template

    async def list_by_property(self, property_id: UUID) -> list[ApplicationTemplate]:
        return await self._repo.list_by_property(property_id)
