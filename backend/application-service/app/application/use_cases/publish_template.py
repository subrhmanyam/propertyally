"""Use case: Publish an application template (make it active)."""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from uuid import UUID

from app.domain.exceptions import TemplateNotFoundError
from app.domain.repositories.abstract_template_repository import AbstractTemplateRepository

logger = logging.getLogger(__name__)


class PublishTemplateUseCase:
    def __init__(self, template_repo: AbstractTemplateRepository) -> None:
        self._repo = template_repo

    async def execute(self, template_id: UUID) -> None:
        template = await self._repo.get_by_id(template_id)
        if template is None:
            raise TemplateNotFoundError(template_id)

        template.is_active = True
        template.updated_at = datetime.now(timezone.utc)
        await self._repo.update(template)
        logger.info("Template published: id=%s", template_id)
