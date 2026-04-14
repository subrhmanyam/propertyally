"""Domain entities for the property service. Pure dataclasses — no ORM or framework imports."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from decimal import Decimal
from enum import Enum
from uuid import UUID


class PropertyType(str, Enum):
    SINGLE_FAMILY = "SINGLE_FAMILY"
    MULTI_FAMILY = "MULTI_FAMILY"
    APARTMENT = "APARTMENT"
    COMMERCIAL = "COMMERCIAL"


class UnitStatus(str, Enum):
    VACANT = "VACANT"
    OCCUPIED = "OCCUPIED"
    UNDER_MAINTENANCE = "UNDER_MAINTENANCE"
    RESERVED = "RESERVED"


@dataclass
class Address:
    street: str
    city: str
    state: str
    zip_code: str
    country: str = "US"


@dataclass
class Property:
    id: UUID
    owner_id: UUID
    name: str
    address: Address
    property_type: PropertyType
    amenities: list[str]
    photos: list[str]
    is_active: bool
    created_at: datetime
    updated_at: datetime
    year_built: int | None = None


@dataclass
class Unit:
    id: UUID
    property_id: UUID
    unit_number: str
    bedrooms: int
    bathrooms: Decimal
    rent_amount: Decimal
    deposit_amount: Decimal
    status: UnitStatus
    features: list[str]
    photos: list[str]
    created_at: datetime
    updated_at: datetime
    square_feet: int | None = None
    floor: int | None = None


@dataclass
class OccupancySummary:
    property_id: UUID
    total_units: int
    occupied: int
    vacant: int
    under_maintenance: int
    occupancy_rate: Decimal
