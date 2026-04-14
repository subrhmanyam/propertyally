"""Use case: GetReportStatus — fetch current state of a report request."""

from __future__ import annotations

import logging
from uuid import UUID

from app.domain.entities.report import ReportRequest
from app.domain.exceptions import ReportNotFoundError
from app.domain.repositories.abstract_report_repository import AbstractReportRepository

logger = logging.getLogger(__name__)


class GetReportStatus:
    def __init__(self, report_repo: AbstractReportRepository) -> None:
        self._repo = report_repo

    async def execute(self, report_id: UUID) -> ReportRequest:
        report = await self._repo.get_report_request(report_id)
        if report is None:
            raise ReportNotFoundError(f"Report {report_id} not found")
        return report
