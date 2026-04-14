"""Concrete SQLAlchemy implementation of AbstractUnitRepository."""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from decimal import Decimal
from uuid import UUID

from sqlalchemy import select, text, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.entities.property import OccupancySummary, Unit, UnitStatus
from app.domain.repositories.abstract_unit_repository import AbstractUnitRepository
from app.infrastructure.db.models import UnitModel

logger = logging.getLogger(__name__)


def _model_to_entity(row: UnitModel) -> Unit:
    return Unit(
        id=row.id,
        property_id=row.property_id,
        unit_number=row.unit_number,
        bedrooms=row.bedrooms,
        bathrooms=Decimal(str(row.bathrooms)),
        square_feet=row.square_feet,
        rent_amount=Decimal(str(row.rent_amount)),
        deposit_amount=Decimal(str(row.deposit_amount)),
        status=UnitStatus(row.status),
        floor=row.floor,
        features=list(row.features or []),
        photos=list(row.photos or []),
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


class UnitRepository(AbstractUnitRepository):
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_by_property(
        self,
        property_id: UUID,
        *,
        status: UnitStatus | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> list[Unit]:
        stmt = select(UnitModel).where(UnitModel.property_id == property_id)
        if status is not None:
            stmt = stmt.where(UnitModel.status == status.value)
        stmt = stmt.order_by(UnitModel.unit_number).limit(limit).offset(offset)
        result = await self._session.execute(stmt)
        return [_model_to_entity(r) for r in result.scalars().all()]

    async def get_by_id(self, unit_id: UUID) -> Unit | None:
        result = await self._session.execute(
            select(UnitModel).where(UnitModel.id == unit_id)
        )
        row = result.scalar_one_or_none()
        return _model_to_entity(row) if row else None

    async def get_by_number(self, property_id: UUID, unit_number: str) -> Unit | None:
        result = await self._session.execute(
            select(UnitModel).where(
                UnitModel.property_id == property_id,
                UnitModel.unit_number == unit_number,
            )
        )
        row = result.scalar_one_or_none()
        return _model_to_entity(row) if row else None

    async def create(
        self,
        *,
        property_id: UUID,
        unit_number: str,
        bedrooms: int,
        bathrooms: Decimal,
        square_feet: int | None,
        rent_amount: Decimal,
        deposit_amount: Decimal,
        floor: int | None,
        features: list[str],
        photos: list[str],
    ) -> Unit:
        row = UnitModel(
            property_id=property_id,
            unit_number=unit_number,
            bedrooms=bedrooms,
            bathrooms=float(bathrooms),
            square_feet=square_feet,
            rent_amount=float(rent_amount),
            deposit_amount=float(deposit_amount),
            status=UnitStatus.VACANT.value,
            floor=floor,
            features=features,
            photos=photos,
        )
        self._session.add(row)
        await self._session.flush()
        await self._session.refresh(row)
        return _model_to_entity(row)

    async def update(self, unit_id: UUID, **fields: object) -> Unit:
        fields["updated_at"] = datetime.now(tz=timezone.utc)

        # Coerce UnitStatus enum to value
        if "status" in fields and isinstance(fields["status"], UnitStatus):
            fields["status"] = fields["status"].value  # type: ignore[assignment]

        # Coerce Decimal fields to float for the ORM column
        for key in ("bathrooms", "rent_amount", "deposit_amount"):
            if key in fields and isinstance(fields[key], Decimal):
                fields[key] = float(fields[key])  # type: ignore[assignment]

        await self._session.execute(
            update(UnitModel).where(UnitModel.id == unit_id).values(**fields)
        )
        await self._session.flush()

        row = await self._session.get(UnitModel, unit_id)
        if row is None:
            raise RuntimeError(f"Unit {unit_id} disappeared after update.")
        await self._session.refresh(row)
        return _model_to_entity(row)

    async def update_status(self, unit_id: UUID, status: UnitStatus) -> Unit:
        return await self.update(unit_id, status=status.value)

    async def get_occupancy_summary(self, property_id: UUID) -> OccupancySummary:
        """Call the property.get_occupancy_summary stored procedure."""
        sql = text("SELECT * FROM property.get_occupancy_summary(:p_property_id)")
        result = await self._session.execute(sql, {"p_property_id": str(property_id)})
        row = result.fetchone()

        if row is None:
            # Property exists but has no units — return zero counts.
            return OccupancySummary(
                property_id=property_id,
                total_units=0,
                occupied=0,
                vacant=0,
                under_maintenance=0,
                occupancy_rate=Decimal("0.00"),
            )

        return OccupancySummary(
            property_id=property_id,
            total_units=row.total_units or 0,
            occupied=row.occupied or 0,
            vacant=row.vacant or 0,
            under_maintenance=row.under_maintenance or 0,
            occupancy_rate=Decimal(str(row.occupancy_rate or 0)),
        )
