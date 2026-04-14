"""Use case: Approve an application — set APPROVED and POST to notification-service."""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from uuid import UUID

import httpx

from app.domain.entities.application import Application, ApplicationStatus
from app.domain.exceptions import ApplicationNotFoundError, InvalidStatusTransitionError
from app.domain.repositories.abstract_application_repository import AbstractApplicationRepository

logger = logging.getLogger(__name__)

_APPROVABLE_STATUSES = {
    ApplicationStatus.SUBMITTED,
    ApplicationStatus.UNDER_REVIEW,
    ApplicationStatus.SCREENING,
}


class ApproveApplicationUseCase:
    def __init__(
        self,
        application_repo: AbstractApplicationRepository,
        notification_service_url: str,
        http_client: httpx.AsyncClient,
    ) -> None:
        self._repo = application_repo
        self._notification_url = notification_service_url
        self._http = http_client

    async def execute(
        self,
        application_id: UUID,
        reviewer_id: UUID,
        reviewer_notes: str | None = None,
    ) -> Application:
        app = await self._repo.get_by_id(application_id)
        if app is None:
            raise ApplicationNotFoundError(application_id)
        if app.status not in _APPROVABLE_STATUSES:
            raise InvalidStatusTransitionError(app.status.value, ApplicationStatus.APPROVED.value)

        now = datetime.now(timezone.utc)
        app.status = ApplicationStatus.APPROVED
        app.reviewer_id = reviewer_id
        app.reviewer_notes = reviewer_notes
        app.reviewed_at = now
        app.updated_at = now
        updated = await self._repo.update(app)

        await self._notify_approved(updated)
        logger.info("Application approved: id=%s reviewer=%s", application_id, reviewer_id)
        return updated

    async def _notify_approved(self, app: Application) -> None:
        payload = {
            "event": "application.approved",
            "application_id": str(app.id),
            "applicant_id": str(app.applicant_id),
            "applicant_email": app.applicant_email,
            "property_id": str(app.property_id),
        }
        try:
            resp = await self._http.post(
                f"{self._notification_url}/api/v1/notifications/events",
                json=payload,
                timeout=5.0,
            )
            resp.raise_for_status()
        except httpx.HTTPError as exc:
            logger.warning("Failed to notify approval: %s", exc)
