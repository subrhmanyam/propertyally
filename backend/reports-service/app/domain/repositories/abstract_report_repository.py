"""Abstract repository interface for reports."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Optional
from uuid import UUID

from app.domain.entities.report import ReportRequest, ReportSchedule, ReportStatus


class AbstractReportRepository(ABC):
    """Port defining all report persistence operations."""

    @abstractmethod
    async def create_report_request(self, report: ReportRequest) -> ReportRequest:
        """Persist a new report request."""
        ...

    @abstractmethod
    async def get_report_request(self, report_id: UUID) -> Optional[ReportRequest]:
        """Fetch a report request by ID."""
        ...

    @abstractmethod
    async def list_report_requests(
        self,
        requested_by: UUID,
        limit: int = 20,
        offset: int = 0,
    ) -> list[ReportRequest]:
        """List report requests for a user."""
        ...

    @abstractmethod
    async def update_report_status(
        self,
        report_id: UUID,
        status: ReportStatus,
        file_url: Optional[str] = None,
        error_message: Optional[str] = None,
    ) -> ReportRequest:
        """Update status (and optionally file_url / error) on a report."""
        ...

    @abstractmethod
    async def create_schedule(self, schedule: ReportSchedule) -> ReportSchedule:
        """Persist a new schedule."""
        ...

    @abstractmethod
    async def get_schedule(self, schedule_id: UUID) -> Optional[ReportSchedule]:
        """Fetch a schedule by ID."""
        ...

    @abstractmethod
    async def list_schedules(self, owner_id: UUID) -> list[ReportSchedule]:
        """List all schedules owned by a user."""
        ...

    @abstractmethod
    async def delete_schedule(self, schedule_id: UUID) -> None:
        """Remove a schedule."""
        ...
