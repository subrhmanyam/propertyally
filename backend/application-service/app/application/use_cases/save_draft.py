"""Use case: Save draft responses (upsert)."""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from uuid import UUID

from app.domain.entities.application import ApplicationStatus
from app.domain.exceptions import ApplicationNotFoundError, InvalidStatusTransitionError
from app.domain.repositories.abstract_application_repository import AbstractApplicationRepository

logger = logging.getLogger(__name__)


class SaveDraftUseCase:
    def __init__(self, application_repo: AbstractApplicationRepository) -> None:
        self._repo = application_repo

    async def execute(self, application_id: UUID, responses: dict[str, object]) -> None:
        app = await self._repo.get_by_id(application_id)
        if app is None:
            raise ApplicationNotFoundError(application_id)
        if app.status != ApplicationStatus.DRAFT:
            raise InvalidStatusTransitionError(app.status.value, "DRAFT (save)")

        # Upsert — merge new responses over existing ones
        app.responses = {**app.responses, **responses}
        app.updated_at = datetime.now(timezone.utc)
        await self._repo.update(app)
        logger.info("Draft saved: application_id=%s", application_id)
