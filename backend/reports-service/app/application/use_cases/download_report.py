"""Use case: DownloadReport — return a Supabase signed URL (1 hour expiry)."""

from __future__ import annotations

import logging
from uuid import UUID

from supabase import AsyncClient as SupabaseAsyncClient

from app.domain.entities.report import ReportStatus
from app.domain.exceptions import ReportNotFoundError, ReportNotReadyError
from app.domain.repositories.abstract_report_repository import AbstractReportRepository
from app.infrastructure.generators.pdf_generator import SUPABASE_BUCKET

logger = logging.getLogger(__name__)

SIGNED_URL_EXPIRY_SECONDS = 3600  # 1 hour


class DownloadReport:
    def __init__(
        self,
        report_repo: AbstractReportRepository,
        supabase: SupabaseAsyncClient,
    ) -> None:
        self._repo = report_repo
        self._supabase = supabase

    async def execute(self, report_id: UUID) -> str:
        report = await self._repo.get_report_request(report_id)
        if report is None:
            raise ReportNotFoundError(f"Report {report_id} not found")

        if report.status != ReportStatus.READY or not report.file_url:
            raise ReportNotReadyError(
                f"Report {report_id} is not ready for download (status={report.status})"
            )

        try:
            response = await self._supabase.storage.from_(SUPABASE_BUCKET).create_signed_url(
                path=report.file_url,
                expires_in=SIGNED_URL_EXPIRY_SECONDS,
            )
        except Exception as exc:
            raise ReportNotReadyError(f"Could not generate signed URL: {exc}") from exc

        signed_url: str = response["signedURL"]
        logger.info("Signed URL generated for report %s", report_id)
        return signed_url
