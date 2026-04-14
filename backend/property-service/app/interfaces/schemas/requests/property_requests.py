"""Pydantic v2 request schemas for property and unit endpoints."""

from __future__ import annotations

from decimal import Decimal

from pydantic import BaseModel, Field, field_validator

from app.domain.entities.property import PropertyType, UnitStatus


class AddressRequest(BaseModel):
    street: str = Field(..., min_length=1, max_length=255, examples=["123 Main St"])
    city: str = Field(..., min_length=1, max_length=100, examples=["Austin"])
    state: str = Field(..., min_length=2, max_length=50, examples=["TX"])
    zip_code: str = Field(..., min_length=3, max_length=20, examples=["78701"])
    country: str = Field(default="US", max_length=50, examples=["US"])


class CreatePropertyRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=255, examples=["Sunrise Apartments"])
    address: AddressRequest
    property_type: PropertyType
    year_built: int | None = Field(default=None, ge=1800, le=2100)
    amenities: list[str] = Field(default_factory=list)
    photos: list[str] = Field(default_factory=list)

    @field_validator("amenities", "photos", mode="before")
    @classmethod
    def ensure_list(cls, v: object) -> list[object]:
        if v is None:
            return []
        return v  # type: ignore[return-value]


class UpdatePropertyRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    street: str | None = Field(default=None, min_length=1, max_length=255)
    city: str | None = Field(default=None, min_length=1, max_length=100)
    state: str | None = Field(default=None, min_length=2, max_length=50)
    zip_code: str | None = Field(default=None, min_length=3, max_length=20)
    country: str | None = Field(default=None, max_length=50)
    property_type: PropertyType | None = None
    year_built: int | None = Field(default=None, ge=1800, le=2100)
    amenities: list[str] | None = None
    photos: list[str] | None = None


class CreateUnitRequest(BaseModel):
    unit_number: str = Field(..., min_length=1, max_length=50, examples=["1A"])
    bedrooms: int = Field(..., ge=0, le=20, examples=[2])
    bathrooms: Decimal = Field(..., ge=Decimal("0.5"), le=Decimal("20.0"), examples=[Decimal("1.5")])
    rent_amount: Decimal = Field(..., gt=Decimal("0"), examples=[Decimal("1500.00")])
    deposit_amount: Decimal = Field(
        default=Decimal("0.00"), ge=Decimal("0"), examples=[Decimal("1500.00")]
    )
    square_feet: int | None = Field(default=None, gt=0, examples=[850])
    floor: int | None = Field(default=None, ge=0, examples=[2])
    features: list[str] = Field(default_factory=list)
    photos: list[str] = Field(default_factory=list)

    @field_validator("bathrooms", "rent_amount", "deposit_amount", mode="before")
    @classmethod
    def coerce_decimal(cls, v: object) -> Decimal:
        return Decimal(str(v))


class UpdateUnitRequest(BaseModel):
    unit_number: str | None = Field(default=None, min_length=1, max_length=50)
    bedrooms: int | None = Field(default=None, ge=0, le=20)
    bathrooms: Decimal | None = Field(default=None, ge=Decimal("0.5"), le=Decimal("20.0"))
    rent_amount: Decimal | None = Field(default=None, gt=Decimal("0"))
    deposit_amount: Decimal | None = Field(default=None, ge=Decimal("0"))
    square_feet: int | None = Field(default=None, gt=0)
    floor: int | None = Field(default=None, ge=0)
    features: list[str] | None = None
    photos: list[str] | None = None

    @field_validator("bathrooms", "rent_amount", "deposit_amount", mode="before")
    @classmethod
    def coerce_decimal(cls, v: object) -> Decimal | None:
        if v is None:
            return None
        return Decimal(str(v))


class UpdateUnitStatusRequest(BaseModel):
    status: UnitStatus
