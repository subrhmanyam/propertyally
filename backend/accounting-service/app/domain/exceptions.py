"""Domain-level exceptions for the accounting service.

Each exception carries a machine-readable code and HTTP status so API handlers
can produce consistent error responses without embedding HTTP concerns in the
domain layer.
"""

from __future__ import annotations


class AccountingServiceError(Exception):
    """Base class for all accounting-service domain errors."""

    code: str = "ACCOUNTING_SERVICE_ERROR"
    http_status: int = 500

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


class ChargeNotFoundError(AccountingServiceError):
    """Raised when a rent charge lookup returns no result."""

    code = "CHARGE_NOT_FOUND"
    http_status = 404

    def __init__(self, charge_id: str) -> None:
        super().__init__(f"Rent charge not found: {charge_id}")


class PaymentNotFoundError(AccountingServiceError):
    """Raised when a payment lookup returns no result."""

    code = "PAYMENT_NOT_FOUND"
    http_status = 404

    def __init__(self, payment_id: str) -> None:
        super().__init__(f"Payment not found: {payment_id}")


class ExpenseNotFoundError(AccountingServiceError):
    """Raised when an expense lookup returns no result."""

    code = "EXPENSE_NOT_FOUND"
    http_status = 404

    def __init__(self, expense_id: str) -> None:
        super().__init__(f"Expense not found: {expense_id}")


class PaymentFailedError(AccountingServiceError):
    """Raised when a payment transaction cannot be completed."""

    code = "PAYMENT_FAILED"
    http_status = 422

    def __init__(self, reason: str) -> None:
        super().__init__(f"Payment failed: {reason}")


class InsufficientFundsError(AccountingServiceError):
    """Raised when the tenants payment amount is zero or negative."""

    code = "INSUFFICIENT_FUNDS"
    http_status = 422

    def __init__(self) -> None:
        super().__init__("Payment amount must be greater than zero.")


class ChargeAlreadyPaidError(AccountingServiceError):
    """Raised when attempting to pay a charge that is already fully paid."""

    code = "CHARGE_ALREADY_PAID"
    http_status = 409

    def __init__(self, charge_id: str) -> None:
        super().__init__(f"Rent charge {charge_id} is already paid.")


class ChargeAlreadyWaivedError(AccountingServiceError):
    """Raised when attempting to waive a charge that is already waived."""

    code = "CHARGE_ALREADY_WAIVED"
    http_status = 409

    def __init__(self, charge_id: str) -> None:
        super().__init__(f"Rent charge {charge_id} is already waived.")


class DuplicateChargeError(AccountingServiceError):
    """Raised when monthly charges already exist for the given period."""

    code = "DUPLICATE_CHARGE"
    http_status = 409

    def __init__(self, tenant_id: str, month: int, year: int) -> None:
        super().__init__(
            f"Rent charge already exists for tenant {tenant_id} for {month}/{year}."
        )


class RefundNotAllowedError(AccountingServiceError):
    """Raised when a payment is not in a refundable state."""

    code = "REFUND_NOT_ALLOWED"
    http_status = 422

    def __init__(self, payment_id: str, reason: str) -> None:
        super().__init__(f"Refund not allowed for payment {payment_id}: {reason}")


class TenantServiceUnavailableError(AccountingServiceError):
    """Raised when the tenant service cannot be reached."""

    code = "TENANT_SERVICE_UNAVAILABLE"
    http_status = 503

    def __init__(self) -> None:
        super().__init__("Tenant service is currently unavailable.")


class UnauthorizedError(AccountingServiceError):
    """Raised when a request lacks a valid or sufficient token."""

    code = "UNAUTHORIZED"
    http_status = 401

    def __init__(self, reason: str = "Authentication required.") -> None:
        super().__init__(reason)


class ForbiddenError(AccountingServiceError):
    """Raised when an authenticated user lacks the required role."""

    code = "FORBIDDEN"
    http_status = 403

    def __init__(self, reason: str = "Insufficient permissions.") -> None:
        super().__init__(reason)
