"""Use case: List applications with optional filters."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Optional
from uuid import UUID

from app.domain.entities.application import Application, ApplicationStatus
from app.domain.repositories.abstract_application_repository import AbstractApplicationRepository

logger = logging.getLogger(__name__)


@dataclass
class ListApplicationsInput:
    property_id: Optional[UUID] = None
    applicant_id: Optional[UUID] = None
    status: Optional[ApplicationStatus] = None
    offset: int = 0
    limit: int = 50


class ListApplicationsUseCase:
    def __init__(self, application_repo: AbstractApplicationRepository) -> None:
        self._repo = application_repo

    async def execute(self, filters: ListApplicationsInput) -> list[Application]:
        return await self._repo.list_by_filters(
            property_id=filters.property_id,
            applicant_id=filters.applicant_id,
            status=filters.status,
            offset=filters.offset,
            limit=filters.limit,
        )
