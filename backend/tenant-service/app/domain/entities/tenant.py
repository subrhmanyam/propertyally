"""Domain entities for the tenant service.

Pure Python dataclasses — zero ORM or framework imports.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
from decimal import Decimal
from enum import Enum
from typing import Optional
from uuid import UUID


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------


class TenantStatus(str, Enum):
    ACTIVE = "ACTIVE"
    PAST = "PAST"
    EVICTED = "EVICTED"


class LeaseStatus(str, Enum):
    DRAFT = "DRAFT"
    ACTIVE = "ACTIVE"
    EXPIRED = "EXPIRED"
    TERMINATED = "TERMINATED"


class CheckStatus(str, Enum):
    PENDING = "PENDING"
    PASSED = "PASSED"
    FAILED = "FAILED"


class ScreeningRecommendation(str, Enum):
    APPROVE = "APPROVE"
    DENY = "DENY"
    REVIEW = "REVIEW"


class DocumentType(str, Enum):
    ID = "ID"
    LEASE = "LEASE"
    REFERENCE = "REFERENCE"
    OTHER = "OTHER"


# ---------------------------------------------------------------------------
# Value Objects
# ---------------------------------------------------------------------------


@dataclass
class EmergencyContact:
    name: str
    phone: str
    relationship: str


# ---------------------------------------------------------------------------
# Domain Entities
# ---------------------------------------------------------------------------


@dataclass
class Tenant:
    id: UUID
    user_id: UUID
    unit_id: UUID
    property_id: UUID
    first_name: str
    last_name: str
    email: str
    phone: str
    date_of_birth: date
    ssn_last_four: str  # Stored encrypted at rest; decrypted value here
    emergency_contact: EmergencyContact
    move_in_date: date
    status: TenantStatus
    created_at: datetime
    move_out_date: Optional[date] = None
    updated_at: Optional[datetime] = None


@dataclass
class Lease:
    id: UUID
    tenant_id: UUID
    unit_id: UUID
    start_date: date
    end_date: date
    monthly_rent: Decimal
    deposit_paid: Decimal
    status: LeaseStatus
    created_at: datetime
    lease_document_url: Optional[str] = None
    signed_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


@dataclass
class ScreeningResult:
    id: UUID
    applicant_id: UUID
    credit_check_status: CheckStatus
    background_check_status: CheckStatus
    eviction_history: bool
    income_verified: bool
    recommendation: ScreeningRecommendation
    created_at: datetime
    credit_score: Optional[int] = None
    external_report_id: Optional[str] = None
    report_url: Optional[str] = None
    completed_at: Optional[datetime] = None


@dataclass
class TenantDocument:
    id: UUID
    tenant_id: UUID
    file_url: str
    uploaded_at: datetime
    document_type: DocumentType = DocumentType.OTHER
    file_name: Optional[str] = None


@dataclass
class TenantWithLease:
    """Aggregate view: tenant profile + current active lease."""

    tenant: Tenant
    current_lease: Optional[Lease] = None
    documents: list[TenantDocument] = field(default_factory=list)
