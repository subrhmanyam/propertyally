"""Domain-level exceptions for the property service.

Each exception carries a machine-readable code and an HTTP status so the API
layer can produce consistent error responses without embedding HTTP concepts in
the domain.
"""

from __future__ import annotations


class PropertyServiceError(Exception):
    """Base class for all property-service domain errors."""

    code: str = "PROPERTY_SERVICE_ERROR"
    http_status: int = 500

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


class PropertyNotFoundError(PropertyServiceError):
    """Raised when a property lookup returns no result."""

    code = "PROPERTY_NOT_FOUND"
    http_status = 404

    def __init__(self, property_id: str) -> None:
        super().__init__(f"Property not found: {property_id}")


class UnitNotFoundError(PropertyServiceError):
    """Raised when a unit lookup returns no result."""

    code = "UNIT_NOT_FOUND"
    http_status = 404

    def __init__(self, unit_id: str) -> None:
        super().__init__(f"Unit not found: {unit_id}")


class DuplicateUnitNumberError(PropertyServiceError):
    """Raised when a unit_number already exists on the same property."""

    code = "DUPLICATE_UNIT_NUMBER"
    http_status = 409

    def __init__(self, unit_number: str, property_id: str) -> None:
        super().__init__(
            f"Unit number '{unit_number}' already exists on property {property_id}."
        )


class PropertyInactiveError(PropertyServiceError):
    """Raised when an operation is attempted on a soft-deleted property."""

    code = "PROPERTY_INACTIVE"
    http_status = 422

    def __init__(self, property_id: str) -> None:
        super().__init__(f"Property {property_id} is inactive and cannot be modified.")


class UnauthorizedError(PropertyServiceError):
    """Raised when a request lacks a valid authentication token."""

    code = "UNAUTHORIZED"
    http_status = 401

    def __init__(self, reason: str = "Authentication required.") -> None:
        super().__init__(reason)


class ForbiddenError(PropertyServiceError):
    """Raised when an authenticated user lacks the required permission."""

    code = "FORBIDDEN"
    http_status = 403

    def __init__(self, reason: str = "Insufficient permissions.") -> None:
        super().__init__(reason)
