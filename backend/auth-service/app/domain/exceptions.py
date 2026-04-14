"""Domain-level exceptions for the auth service.

These exceptions carry a machine-readable code so API handlers can map them to
consistent HTTP error responses without hard-coding status codes in the domain.
"""

from __future__ import annotations


class AuthServiceError(Exception):
    """Base class for all auth-service domain errors."""

    code: str = "AUTH_SERVICE_ERROR"
    http_status: int = 500

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


class UserNotFoundError(AuthServiceError):
    """Raised when a user lookup returns no result."""

    code = "USER_NOT_FOUND"
    http_status = 404

    def __init__(self, identifier: str) -> None:
        super().__init__(f"User not found: {identifier}")


class InvalidCredentialsError(AuthServiceError):
    """Raised when email/password do not match."""

    code = "INVALID_CREDENTIALS"
    http_status = 401

    def __init__(self) -> None:
        super().__init__("Invalid email or password.")


class EmailAlreadyExistsError(AuthServiceError):
    """Raised when a registration attempt uses an already-registered email."""

    code = "EMAIL_ALREADY_EXISTS"
    http_status = 409

    def __init__(self, email: str) -> None:
        super().__init__(f"Email already registered: {email}")


class UnauthorizedError(AuthServiceError):
    """Raised when a request lacks a valid or sufficient token."""

    code = "UNAUTHORIZED"
    http_status = 401

    def __init__(self, reason: str = "Authentication required.") -> None:
        super().__init__(reason)


class ForbiddenError(AuthServiceError):
    """Raised when an authenticated user lacks the required role."""

    code = "FORBIDDEN"
    http_status = 403

    def __init__(self, reason: str = "Insufficient permissions.") -> None:
        super().__init__(reason)


class TokenExpiredError(AuthServiceError):
    """Raised when a JWT or refresh token has expired."""

    code = "TOKEN_EXPIRED"
    http_status = 401

    def __init__(self) -> None:
        super().__init__("Token has expired.")


class InvalidTokenError(AuthServiceError):
    """Raised when a token cannot be decoded or is structurally invalid."""

    code = "INVALID_TOKEN"
    http_status = 401

    def __init__(self, reason: str = "Token is invalid.") -> None:
        super().__init__(reason)


class AccountInactiveError(AuthServiceError):
    """Raised when a disabled account attempts to authenticate."""

    code = "ACCOUNT_INACTIVE"
    http_status = 403

    def __init__(self) -> None:
        super().__init__("Account is disabled. Contact support.")


class AccountLockedError(AuthServiceError):
    """Raised when too many failed login attempts lock the account."""

    code = "ACCOUNT_LOCKED"
    http_status = 429

    def __init__(self) -> None:
        super().__init__("Account temporarily locked due to too many failed login attempts.")
