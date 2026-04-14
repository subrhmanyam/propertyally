"""Domain-level exceptions for the tenant service.

Machine-readable codes let API handlers produce consistent HTTP responses
without hard-coding status codes in the domain.
"""

from __future__ import annotations


class TenantServiceError(Exception):
    """Base class for all tenant-service domain errors."""

    code: str = "TENANT_SERVICE_ERROR"
    http_status: int = 500

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


class TenantNotFoundError(TenantServiceError):
    """Raised when a tenant lookup returns no result."""

    code = "TENANT_NOT_FOUND"
    http_status = 404

    def __init__(self, identifier: str) -> None:
        super().__init__(f"Tenant not found: {identifier}")


class LeaseNotFoundError(TenantServiceError):
    """Raised when a lease lookup returns no result."""

    code = "LEASE_NOT_FOUND"
    http_status = 404

    def __init__(self, identifier: str) -> None:
        super().__init__(f"Lease not found: {identifier}")


class ActiveLeaseExistsError(TenantServiceError):
    """Raised when trying to create a new lease but one is already active."""

    code = "ACTIVE_LEASE_EXISTS"
    http_status = 409

    def __init__(self, tenant_id: str) -> None:
        super().__init__(f"Tenant {tenant_id} already has an active lease.")


class ScreeningNotFoundError(TenantServiceError):
    """Raised when a screening result lookup returns no result."""

    code = "SCREENING_NOT_FOUND"
    http_status = 404

    def __init__(self, identifier: str) -> None:
        super().__init__(f"Screening result not found: {identifier}")


class DocumentNotFoundError(TenantServiceError):
    """Raised when a document lookup returns no result."""

    code = "DOCUMENT_NOT_FOUND"
    http_status = 404

    def __init__(self, identifier: str) -> None:
        super().__init__(f"Document not found: {identifier}")


class InvalidLeaseTransitionError(TenantServiceError):
    """Raised when a lease status transition is not permitted."""

    code = "INVALID_LEASE_TRANSITION"
    http_status = 422

    def __init__(self, current: str, target: str) -> None:
        super().__init__(f"Cannot transition lease from {current} to {target}.")


class ExternalServiceError(TenantServiceError):
    """Raised when an inter-service HTTP call fails."""

    code = "EXTERNAL_SERVICE_ERROR"
    http_status = 502

    def __init__(self, service: str, reason: str) -> None:
        super().__init__(f"Call to {service} failed: {reason}")


class StorageUploadError(TenantServiceError):
    """Raised when a Supabase Storage upload fails."""

    code = "STORAGE_UPLOAD_ERROR"
    http_status = 502

    def __init__(self, reason: str) -> None:
        super().__init__(f"Document upload failed: {reason}")
