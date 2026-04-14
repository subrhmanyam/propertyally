"""Use case: Start a new application (creates DRAFT)."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID, uuid4

from app.domain.entities.application import Application, ApplicationStatus
from app.domain.exceptions import TemplateNotActiveError, TemplateNotFoundError
from app.domain.repositories.abstract_application_repository import AbstractApplicationRepository
from app.domain.repositories.abstract_template_repository import AbstractTemplateRepository

logger = logging.getLogger(__name__)


@dataclass
class StartApplicationInput:
    template_id: UUID
    property_id: UUID
    unit_id: Optional[UUID]
    applicant_id: UUID
    applicant_name: str
    applicant_email: str


class StartApplicationUseCase:
    def __init__(
        self,
        template_repo: AbstractTemplateRepository,
        application_repo: AbstractApplicationRepository,
    ) -> None:
        self._template_repo = template_repo
        self._application_repo = application_repo

    async def execute(self, data: StartApplicationInput) -> Application:
        template = await self._template_repo.get_by_id(data.template_id)
        if template is None:
            raise TemplateNotFoundError(data.template_id)
        if not template.is_active:
            raise TemplateNotActiveError(data.template_id)

        now = datetime.now(timezone.utc)
        application = Application(
            id=uuid4(),
            template_id=data.template_id,
            property_id=data.property_id,
            unit_id=data.unit_id,
            applicant_id=data.applicant_id,
            applicant_name=data.applicant_name,
            applicant_email=data.applicant_email,
            responses={},
            documents=[],
            status=ApplicationStatus.DRAFT,
            reviewer_id=None,
            reviewer_notes=None,
            submitted_at=None,
            reviewed_at=None,
            created_at=now,
            updated_at=now,
        )

        created = await self._application_repo.create(application)
        logger.info("Application started: id=%s applicant=%s", created.id, data.applicant_id)
        return created
