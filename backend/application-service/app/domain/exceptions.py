"""Domain exceptions for the Application Service."""

from __future__ import annotations


class ApplicationServiceError(Exception):
    """Base exception for all application service errors."""


class TemplateNotFoundError(ApplicationServiceError):
    def __init__(self, template_id: object) -> None:
        super().__init__(f"Template not found: {template_id}")


class ApplicationNotFoundError(ApplicationServiceError):
    def __init__(self, application_id: object) -> None:
        super().__init__(f"Application not found: {application_id}")


class InvalidStatusTransitionError(ApplicationServiceError):
    def __init__(self, current: str, target: str) -> None:
        super().__init__(f"Cannot transition application from {current} to {target}")


class TemplateNotActiveError(ApplicationServiceError):
    def __init__(self, template_id: object) -> None:
        super().__init__(f"Template {template_id} is not active and cannot accept applications")


class ValidationError(ApplicationServiceError):
    def __init__(self, message: str, details: list[str] | None = None) -> None:
        super().__init__(message)
        self.details: list[str] = details or []


class UnauthorizedError(ApplicationServiceError):
    def __init__(self, message: str = "Unauthorized") -> None:
        super().__init__(message)
