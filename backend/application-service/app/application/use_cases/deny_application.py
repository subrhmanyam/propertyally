"""Use case: Deny an application with a reason."""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from uuid import UUID

import httpx

from app.domain.entities.application import Application, ApplicationStatus
from app.domain.exceptions import ApplicationNotFoundError, InvalidStatusTransitionError
from app.domain.repositories.abstract_application_repository import AbstractApplicationRepository

logger = logging.getLogger(__name__)

_DENIABLE_STATUSES = {
    ApplicationStatus.SUBMITTED,
    ApplicationStatus.UNDER_REVIEW,
    ApplicationStatus.SCREENING,
}


class DenyApplicationUseCase:
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
        reason: str,
    ) -> Application:
        app = await self._repo.get_by_id(application_id)
        if app is None:
            raise ApplicationNotFoundError(application_id)
        if app.status not in _DENIABLE_STATUSES:
            raise InvalidStatusTransitionError(app.status.value, ApplicationStatus.DENIED.value)

        now = datetime.now(timezone.utc)
        app.status = ApplicationStatus.DENIED
        app.reviewer_id = reviewer_id
        app.reviewer_notes = reason
        app.reviewed_at = now
        app.updated_at = now
        updated = await self._repo.update(app)

        await self._notify_denied(updated, reason)
        logger.info("Application denied: id=%s reason=%s", application_id, reason)
        return updated

    async def _notify_denied(self, app: Application, reason: str) -> None:
        payload = {
            "event": "application.denied",
            "application_id": str(app.id),
            "applicant_id": str(app.applicant_id),
            "applicant_email": app.applicant_email,
            "reason": reason,
        }
        try:
            resp = await self._http.post(
                f"{self._notification_url}/api/v1/notifications/events",
                json=payload,
                timeout=5.0,
            )
            resp.raise_for_status()
        except httpx.HTTPError as exc:
            logger.warning("Failed to notify denial: %s", exc)
