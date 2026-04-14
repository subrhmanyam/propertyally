"""Use case: GenerateReport — background worker that fetches data, builds file, uploads to Supabase."""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from supabase import AsyncClient as SupabaseAsyncClient

from app.domain.entities.report import ReportFormat, ReportRequest, ReportStatus, ReportType
from app.domain.exceptions import ExternalServiceError, ReportGenerationError, ReportNotFoundError
from app.domain.repositories.abstract_report_repository import AbstractReportRepository
from app.infrastructure.external.accounting_client import AccountingClient
from app.infrastructure.external.property_client import PropertyClient
from app.infrastructure.generators.csv_generator import CsvGenerator
from app.infrastructure.generators.pdf_generator import PdfGenerator

logger = logging.getLogger(__name__)

SUPABASE_BUCKET = "reports"


class GenerateReport:
    """Orchestrates full report generation: fetch → build → upload → update DB."""

    def __init__(
        self,
        report_repo: AbstractReportRepository,
        accounting_client: AccountingClient,
        property_client: PropertyClient,
        pdf_generator: PdfGenerator,
        csv_generator: CsvGenerator,
        supabase: SupabaseAsyncClient,
    ) -> None:
        self._repo = report_repo
        self._accounting = accounting_client
        self._property = property_client
        self._pdf = pdf_generator
        self._csv = csv_generator
        self._supabase = supabase

    async def execute(self, report_id: UUID) -> ReportRequest:
        report = await self._repo.get_report_request(report_id)
        if report is None:
            raise ReportNotFoundError(f"Report {report_id} not found")

        # Mark as GENERATING
        report = await self._repo.update_report_status(report_id, ReportStatus.GENERATING)

        try:
            data = await self._fetch_data(report)
            file_bytes, content_type, extension = await self._build_file(report, data)
            file_url = await self._upload(report, file_bytes, content_type, extension)

            report = await self._repo.update_report_status(
                report_id,
                ReportStatus.READY,
                file_url=file_url,
            )
            logger.info("Report ready: id=%s url=%s", report_id, file_url)
        except (ExternalServiceError, ReportGenerationError) as exc:
            logger.error("Report generation failed: id=%s error=%s", report_id, exc)
            await self._repo.update_report_status(
                report_id,
                ReportStatus.FAILED,
                error_message=str(exc),
            )
            raise

        return report

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    async def _fetch_data(self, report: ReportRequest) -> dict[str, Any]:
        params = report.parameters
        match report.report_type:
            case ReportType.FINANCIAL_SUMMARY:
                return await self._accounting.get_financial_summary(
                    property_id=params["property_id"],
                    from_date=params["from_date"],
                    to_date=params["to_date"],
                )
            case ReportType.RENT_ROLL:
                charges = await self._accounting.get_rent_roll(
                    property_id=params["property_id"],
                    month=int(params["month"]),
                    year=int(params["year"]),
                )
                units = await self._property.get_units(property_id=params["property_id"])
                return {"charges": charges, "units": units}
            case ReportType.OCCUPANCY:
                units = await self._property.get_units(
                    property_id=params.get("property_id"),
                )
                return {"units": units}
            case ReportType.MAINTENANCE_SUMMARY:
                return await self._property.get_maintenance_summary(
                    property_id=params["property_id"],
                    from_date=params["from_date"],
                    to_date=params["to_date"],
                )
            case ReportType.TENANT_LEDGER:
                return await self._accounting.get_tenant_ledger(
                    tenant_id=params["tenant_id"],
                    from_date=params["from_date"],
                    to_date=params["to_date"],
                )
            case ReportType.EXPENSE_BREAKDOWN:
                return await self._accounting.get_expense_breakdown(
                    property_id=params["property_id"],
                    from_date=params["from_date"],
                    to_date=params["to_date"],
                )
            case ReportType.INCOME_STATEMENT:
                return await self._accounting.get_income_statement(
                    property_id=params.get("property_id"),
                    owner_id=params.get("owner_id"),
                    year=int(params["year"]),
                )
            case _:
                raise ReportGenerationError(f"Unknown report type: {report.report_type}")

    async def _build_file(
        self,
        report: ReportRequest,
        data: dict[str, Any],
    ) -> tuple[bytes, str, str]:
        if report.format == ReportFormat.CSV:
            file_bytes = self._csv.generate(report.report_type, data)
            return file_bytes, "text/csv", "csv"

        # Default: PDF
        file_bytes = self._pdf.generate(report.report_type, data, report.parameters)
        return file_bytes, "application/pdf", "pdf"

    async def _upload(
        self,
        report: ReportRequest,
        file_bytes: bytes,
        content_type: str,
        extension: str,
    ) -> str:
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
        path = f"{report.requested_by}/{report.report_type.value}_{timestamp}_{report.id}.{extension}"

        try:
            await self._supabase.storage.from_(SUPABASE_BUCKET).upload(
                path=path,
                file=file_bytes,
                file_options={"content-type": content_type, "upsert": "false"},
            )
        except Exception as exc:
            raise ReportGenerationError(f"Failed to upload report to storage: {exc}") from exc

        return path
