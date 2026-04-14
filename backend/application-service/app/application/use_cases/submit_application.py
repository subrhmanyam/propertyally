"""Use case: Submit an application — validates required fields then sets SUBMITTED."""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from uuid import UUID

from app.domain.entities.application import Application, ApplicationStatus
from app.domain.exceptions import (
    ApplicationNotFoundError,
    InvalidStatusTransitionError,
    TemplateNotFoundError,
    ValidationError,
)
from app.domain.repositories.abstract_application_repository import AbstractApplicationRepository
from app.domain.repositories.abstract_template_repository import AbstractTemplateRepository

logger = logging.getLogger(__name__)


class SubmitApplicationUseCase:
    def __init__(
        self,
        application_repo: AbstractApplicationRepository,
        template_repo: AbstractTemplateRepository,
    ) -> None:
        self._application_repo = application_repo
        self._template_repo = template_repo

    async def execute(self, application_id: UUID) -> Application:
        app = await self._application_repo.get_by_id(application_id)
        if app is None:
            raise ApplicationNotFoundError(application_id)
        if app.status != ApplicationStatus.DRAFT:
            raise InvalidStatusTransitionError(app.status.value, ApplicationStatus.SUBMITTED.value)

        template = await self._template_repo.get_by_id(app.template_id)
        if template is None:
            raise TemplateNotFoundError(app.template_id)

        required_ids = template.all_required_field_ids()
        missing = app.missing_required_fields(required_ids)
        if missing:
            raise ValidationError(
                "Required fields are missing",
                details=[f"Field {fid} is required" for fid in missing],
            )

        now = datetime.now(timezone.utc)
        app.status = ApplicationStatus.SUBMITTED
        app.submitted_at = now
        app.updated_at = now
        updated = await self._application_repo.update(app)
        logger.info("Application submitted: id=%s", application_id)
        return updated
