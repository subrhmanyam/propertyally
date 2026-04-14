"""Use case: RequestReport — create a QUEUED record and kick off background generation."""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Any

import httpx

from app.domain.entities.report import ReportFormat, ReportRequest, ReportStatus, ReportType
from app.domain.exceptions import InvalidParametersError
from app.domain.repositories.abstract_report_repository import AbstractReportRepository

logger = logging.getLogger(__name__)

# Required parameter keys per report type
_REQUIRED_PARAMS: dict[ReportType, list[str]] = {
    ReportType.FINANCIAL_SUMMARY: ["property_id", "from_date", "to_date"],
    ReportType.RENT_ROLL: ["property_id", "month", "year"],
    ReportType.OCCUPANCY: ["from_date", "to_date"],
    ReportType.MAINTENANCE_SUMMARY: ["property_id", "from_date", "to_date"],
    ReportType.TENANT_LEDGER: ["tenant_id", "from_date", "to_date"],
    ReportType.EXPENSE_BREAKDOWN: ["property_id", "from_date", "to_date"],
    ReportType.INCOME_STATEMENT: ["year"],
}


class RequestReport:
    """Validates parameters, creates a QUEUED report record, and fires the background task."""

    def __init__(
        self,
        report_repo: AbstractReportRepository,
        generate_report_url: str,
    ) -> None:
        self._repo = report_repo
        self._generate_url = generate_report_url

    def _validate_parameters(self, report_type: ReportType, parameters: dict[str, Any]) -> None:
        required = _REQUIRED_PARAMS.get(report_type, [])
        missing = [k for k in required if k not in parameters]
        if missing:
            raise InvalidParametersError(
                f"Missing required parameters for {report_type}: {', '.join(missing)}"
            )

    async def execute(
        self,
        report_type: ReportType,
        requested_by: uuid.UUID,
        parameters: dict[str, Any],
        format: ReportFormat = ReportFormat.PDF,
    ) -> ReportRequest:
        self._validate_parameters(report_type, parameters)

        report = ReportRequest(
            id=uuid.uuid4(),
            report_type=report_type,
            requested_by=requested_by,
            parameters=parameters,
            format=format,
            status=ReportStatus.QUEUED,
            file_url=None,
            error_message=None,
            generated_at=None,
            created_at=datetime.now(timezone.utc),
        )

        saved = await self._repo.create_report_request(report)
        logger.info("Report queued: id=%s type=%s user=%s", saved.id, report_type, requested_by)

        # Fire-and-forget: call our own /internal/generate endpoint in background
        # In production this would be a Celery task or message queue publish.
        await self._trigger_generation(saved.id)

        return saved

    async def _trigger_generation(self, report_id: uuid.UUID) -> None:
        """Asynchronously POST to the internal generation endpoint (best-effort)."""
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                await client.post(
                    f"{self._generate_url}/internal/reports/{report_id}/generate"
                )
        except Exception as exc:
            # Generation will still be triggered via polling / scheduler fallback
            logger.warning("Could not trigger generation for %s: %s", report_id, exc)
