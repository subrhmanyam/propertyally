"""Pure domain entities for the accounting service.

No framework imports — these are plain Python dataclasses.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
from decimal import Decimal
from enum import Enum
from uuid import UUID


class ChargeStatus(str, Enum):
    PENDING = "PENDING"
    PAID = "PAID"
    PARTIAL = "PARTIAL"
    OVERDUE = "OVERDUE"
    WAIVED = "WAIVED"


class PaymentMethod(str, Enum):
    ACH = "ACH"
    CREDIT_CARD = "CREDIT_CARD"
    CHECK = "CHECK"
    CASH = "CASH"


class PaymentStatus(str, Enum):
    PENDING = "PENDING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"
    REFUNDED = "REFUNDED"


class ExpenseCategory(str, Enum):
    MAINTENANCE = "MAINTENANCE"
    INSURANCE = "INSURANCE"
    TAX = "TAX"
    UTILITY = "UTILITY"
    OTHER = "OTHER"


@dataclass
class RentCharge:
    id: UUID
    tenant_id: UUID
    unit_id: UUID
    property_id: UUID
    amount: Decimal
    due_date: date
    period_month: int
    period_year: int
    status: ChargeStatus
    created_at: datetime
    waived_by: UUID | None = None
    waived_at: datetime | None = None
    waive_reason: str | None = None


@dataclass
class Payment:
    id: UUID
    rent_charge_id: UUID
    tenant_id: UUID
    amount: Decimal
    payment_date: date
    payment_method: PaymentMethod
    transaction_ref: str
    status: PaymentStatus
    created_at: datetime
    refunded_at: datetime | None = None


@dataclass
class Expense:
    id: UUID
    property_id: UUID
    category: ExpenseCategory
    description: str
    amount: Decimal
    expense_date: date
    created_at: datetime
    vendor_name: str | None = None
    receipt_url: str | None = None


@dataclass
class LedgerEntry:
    id: UUID
    property_id: UUID
    entry_date: date
    description: str
    debit: Decimal
    credit: Decimal
    balance: Decimal
    reference_id: UUID | None
    reference_type: str | None
    created_at: datetime
