"""Domain exceptions for the Reports Service."""

from __future__ import annotations


class ReportsServiceError(Exception):
    """Base exception for all reports service errors."""

    http_status: int = 500
    code: str = "REPORTS_SERVICE_ERROR"

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


class ReportNotFoundError(ReportsServiceError):
    """Raised when a report request cannot be found."""

    http_status = 404
    code = "REPORT_NOT_FOUND"


class ReportNotReadyError(ReportsServiceError):
    """Raised when a download is attempted on a non-READY report."""

    http_status = 409
    code = "REPORT_NOT_READY"


class ReportGenerationError(ReportsServiceError):
    """Raised when PDF/CSV generation fails."""

    http_status = 500
    code = "REPORT_GENERATION_ERROR"


class ExternalServiceError(ReportsServiceError):
    """Raised when a downstream service call fails."""

    http_status = 502
    code = "EXTERNAL_SERVICE_ERROR"


class ScheduleNotFoundError(ReportsServiceError):
    """Raised when a schedule cannot be found."""

    http_status = 404
    code = "SCHEDULE_NOT_FOUND"


class InvalidParametersError(ReportsServiceError):
    """Raised when report parameters are invalid for the requested type."""

    http_status = 422
    code = "INVALID_PARAMETERS"
