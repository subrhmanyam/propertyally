"""SQLAlchemy ORM models for the property service (schema: property).

These models are infrastructure concerns only — they must not be imported by the
domain or application layers.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import (
    ARRAY,
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    SmallInteger,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class PropertyModel(Base):
    __tablename__ = "properties"
    __table_args__ = {"schema": "property"}

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=func.gen_random_uuid(),
    )
    owner_id: Mapped[uuid.UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    street: Mapped[str] = mapped_column(String(255), nullable=False)
    city: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    state: Mapped[str] = mapped_column(String(50), nullable=False)
    zip_code: Mapped[str] = mapped_column(String(20), nullable=False)
    country: Mapped[str] = mapped_column(String(50), nullable=False, default="US")
    property_type: Mapped[str] = mapped_column(String(50), nullable=False)
    year_built: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    amenities: Mapped[list[str]] = mapped_column(
        ARRAY(Text), nullable=False, server_default="{}"
    )
    photos: Mapped[list[str]] = mapped_column(
        ARRAY(Text), nullable=False, server_default="{}"
    )
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )

    units: Mapped[list[UnitModel]] = relationship(
        "UnitModel", back_populates="property", cascade="all, delete-orphan"
    )


class UnitModel(Base):
    __tablename__ = "units"
    __table_args__ = {"schema": "property"}

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=func.gen_random_uuid(),
    )
    property_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("property.properties.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    unit_number: Mapped[str] = mapped_column(String(50), nullable=False)
    bedrooms: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=0)
    bathrooms: Mapped[float] = mapped_column(Numeric(3, 1), nullable=False, default=1)
    square_feet: Mapped[int | None] = mapped_column(Integer, nullable=True)
    rent_amount: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    deposit_amount: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False, default=0)
    status: Mapped[str] = mapped_column(
        String(30), nullable=False, default="VACANT", index=True
    )
    floor: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    features: Mapped[list[str]] = mapped_column(
        ARRAY(Text), nullable=False, server_default="{}"
    )
    photos: Mapped[list[str]] = mapped_column(
        ARRAY(Text), nullable=False, server_default="{}"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )

    property: Mapped[PropertyModel] = relationship("PropertyModel", back_populates="units")
