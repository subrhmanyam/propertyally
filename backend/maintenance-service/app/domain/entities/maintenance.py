"""Domain entities for the maintenance service.

Pure Python dataclasses and enums — zero framework or ORM imports.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
from decimal import Decimal
from enum import Enum
from typing import Optional
from uuid import UUID


# ---------------------------------------------------------------------------
# Enumerations
# ---------------------------------------------------------------------------


class MaintenanceCategory(str, Enum):
    PLUMBING = "PLUMBING"
    ELECTRICAL = "ELECTRICAL"
    HVAC = "HVAC"
    APPLIANCE = "APPLIANCE"
    STRUCTURAL = "STRUCTURAL"
    OTHER = "OTHER"


class Priority(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    EMERGENCY = "EMERGENCY"


class RequestStatus(str, Enum):
    OPEN = "OPEN"
    ASSIGNED = "ASSIGNED"
    IN_PROGRESS = "IN_PROGRESS"
    PENDING_APPROVAL = "PENDING_APPROVAL"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"


# ---------------------------------------------------------------------------
# SLA constants — response target in hours per priority level
# ---------------------------------------------------------------------------

SLA_RESPONSE_HOURS: dict[Priority, int] = {
    Priority.EMERGENCY: 1,
    Priority.HIGH: 4,
    Priority.MEDIUM: 24,
    Priority.LOW: 48,
}

SLA_COMPLETION_HOURS: dict[Priority, int] = {
    Priority.EMERGENCY: 24,
    Priority.HIGH: 72,    # 3 days
    Priority.MEDIUM: 168,  # 7 days
    Priority.LOW: 336,    # 14 days
}


# ---------------------------------------------------------------------------
# Entities
# ---------------------------------------------------------------------------


@dataclass
class MaintenanceRequest:
    id: UUID
    unit_id: UUID
    property_id: UUID
    tenant_id: Optional[UUID]  # None when submitted by a manager
    title: str
    description: str
    category: MaintenanceCategory
    priority: Priority
    status: RequestStatus
    photos: list[str]  # Supabase Storage public URLs
    created_at: datetime
    updated_at: datetime


@dataclass
class WorkOrder:
    id: UUID
    request_id: UUID
    vendor_id: Optional[UUID]
    assigned_staff_id: Optional[UUID]
    scheduled_date: Optional[date]
    estimated_cost: Optional[Decimal]
    actual_cost: Optional[Decimal]
    work_notes: str
    completion_photos: list[str]  # Supabase Storage public URLs
    completed_at: Optional[datetime]
    approved_at: Optional[datetime]
    approved_by: Optional[UUID]  # Manager who signed off


@dataclass
class Vendor:
    id: UUID
    name: str
    contact_name: str
    email: str
    phone: str
    trade: str  # e.g. "Plumber", "Electrician", "HVAC Tech", "General"
    is_active: bool
    rating: Optional[Decimal]  # 0.00 – 5.00
