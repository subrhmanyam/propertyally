"""Domain entity for a platform user. Pure dataclass — no ORM or framework imports."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from typing import Optional
from uuid import UUID


class UserRole(str, Enum):
    SUPER_ADMIN = "super_admin"
    PROPERTY_MANAGER = "property_manager"
    LANDLORD = "landlord"
    MAINTENANCE_STAFF = "maintenance_staff"
    TENANT = "tenant"
    APPLICANT = "applicant"


@dataclass
class User:
    id: UUID
    email: str
    full_name: str
    role: UserRole
    is_active: bool
    is_verified: bool
    created_at: datetime
    last_login: Optional[datetime] = None
    updated_at: Optional[datetime] = None
