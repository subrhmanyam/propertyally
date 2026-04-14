"""Domain-level exceptions for the maintenance service.

Each exception carries a machine-readable ``code`` and a suggested HTTP status
so API handlers can produce consistent error responses without embedding HTTP
knowledge in the domain.
"""

from __future__ import annotations


class MaintenanceServiceError(Exception):
    """Base class for all maintenance-service domain errors."""

    code: str = "MAINTENANCE_SERVICE_ERROR"
    http_status: int = 500

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


class RequestNotFoundError(MaintenanceServiceError):
    """Raised when a MaintenanceRequest lookup returns no result."""

    code = "REQUEST_NOT_FOUND"
    http_status = 404

    def __init__(self, identifier: str) -> None:
        super().__init__(f"Maintenance request not found: {identifier}")


class WorkOrderNotFoundError(MaintenanceServiceError):
    """Raised when a WorkOrder lookup returns no result."""

    code = "WORK_ORDER_NOT_FOUND"
    http_status = 404

    def __init__(self, identifier: str) -> None:
        super().__init__(f"Work order not found: {identifier}")


class VendorNotFoundError(MaintenanceServiceError):
    """Raised when a Vendor lookup returns no result."""

    code = "VENDOR_NOT_FOUND"
    http_status = 404

    def __init__(self, identifier: str) -> None:
        super().__init__(f"Vendor not found: {identifier}")


class InvalidStatusTransitionError(MaintenanceServiceError):
    """Raised when a status change violates the allowed state machine."""

    code = "INVALID_STATUS_TRANSITION"
    http_status = 422

    def __init__(self, from_status: str, to_status: str) -> None:
        super().__init__(
            f"Cannot transition from '{from_status}' to '{to_status}'."
        )


class WorkOrderAlreadyExistsError(MaintenanceServiceError):
    """Raised when trying to assign a request that already has a work order."""

    code = "WORK_ORDER_ALREADY_EXISTS"
    http_status = 409

    def __init__(self, request_id: str) -> None:
        super().__init__(
            f"A work order already exists for maintenance request: {request_id}"
        )


class RequestNotAssignableError(MaintenanceServiceError):
    """Raised when a request cannot be assigned because of its current status."""

    code = "REQUEST_NOT_ASSIGNABLE"
    http_status = 422

    def __init__(self, status: str) -> None:
        super().__init__(
            f"Maintenance request in status '{status}' cannot be assigned."
        )


class RequestNotCancellableError(MaintenanceServiceError):
    """Raised when attempting to cancel a request in a terminal or late-stage status."""

    code = "REQUEST_NOT_CANCELLABLE"
    http_status = 422

    def __init__(self, status: str) -> None:
        super().__init__(
            f"Maintenance request in status '{status}' cannot be cancelled."
        )


class StorageUploadError(MaintenanceServiceError):
    """Raised when a Supabase Storage upload fails."""

    code = "STORAGE_UPLOAD_ERROR"
    http_status = 502

    def __init__(self, reason: str) -> None:
        super().__init__(f"Photo upload failed: {reason}")


class AccountingServiceError(MaintenanceServiceError):
    """Raised when the call to the accounting service fails."""

    code = "ACCOUNTING_SERVICE_ERROR"
    http_status = 502

    def __init__(self, reason: str) -> None:
        super().__init__(f"Accounting service call failed: {reason}")
