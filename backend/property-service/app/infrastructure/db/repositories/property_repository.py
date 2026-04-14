"""Concrete SQLAlchemy implementation of AbstractPropertyRepository."""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.entities.property import Address, Property, PropertyType
from app.domain.repositories.abstract_property_repository import AbstractPropertyRepository
from app.infrastructure.db.models import PropertyModel

logger = logging.getLogger(__name__)


def _model_to_entity(row: PropertyModel) -> Property:
    return Property(
        id=row.id,
        owner_id=row.owner_id,
        name=row.name,
        address=Address(
            street=row.street,
            city=row.city,
            state=row.state,
            zip_code=row.zip_code,
            country=row.country,
        ),
        property_type=PropertyType(row.property_type),
        year_built=row.year_built,
        amenities=list(row.amenities or []),
        photos=list(row.photos or []),
        is_active=row.is_active,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


class PropertyRepository(AbstractPropertyRepository):
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_by_owner(
        self,
        owner_id: UUID,
        *,
        city: str | None = None,
        property_type: PropertyType | None = None,
        is_active: bool | None = True,
        limit: int = 20,
        offset: int = 0,
    ) -> tuple[list[Property], int]:
        return await self.list_all(
            owner_id=owner_id,
            city=city,
            property_type=property_type,
            is_active=is_active,
            limit=limit,
            offset=offset,
        )

    async def list_all(
        self,
        *,
        owner_id: UUID | None = None,
        city: str | None = None,
        property_type: PropertyType | None = None,
        is_active: bool | None = True,
        limit: int = 20,
        offset: int = 0,
    ) -> tuple[list[Property], int]:
        stmt = select(PropertyModel)

        if owner_id is not None:
            stmt = stmt.where(PropertyModel.owner_id == owner_id)
        if city is not None:
            stmt = stmt.where(func.lower(PropertyModel.city) == city.lower())
        if property_type is not None:
            stmt = stmt.where(PropertyModel.property_type == property_type.value)
        if is_active is not None:
            stmt = stmt.where(PropertyModel.is_active == is_active)

        count_stmt = select(func.count()).select_from(stmt.subquery())
        total_result = await self._session.execute(count_stmt)
        total: int = total_result.scalar_one()

        stmt = stmt.order_by(PropertyModel.created_at.desc()).limit(limit).offset(offset)
        result = await self._session.execute(stmt)
        rows = result.scalars().all()

        return [_model_to_entity(r) for r in rows], total

    async def get_by_id(self, property_id: UUID) -> Property | None:
        result = await self._session.execute(
            select(PropertyModel).where(PropertyModel.id == property_id)
        )
        row = result.scalar_one_or_none()
        return _model_to_entity(row) if row else None

    async def create(
        self,
        *,
        owner_id: UUID,
        name: str,
        address: Address,
        property_type: PropertyType,
        year_built: int | None,
        amenities: list[str],
        photos: list[str],
    ) -> Property:
        row = PropertyModel(
            owner_id=owner_id,
            name=name,
            street=address.street,
            city=address.city,
            state=address.state,
            zip_code=address.zip_code,
            country=address.country,
            property_type=property_type.value,
            year_built=year_built,
            amenities=amenities,
            photos=photos,
        )
        self._session.add(row)
        await self._session.flush()
        await self._session.refresh(row)
        return _model_to_entity(row)

    async def update(self, property_id: UUID, **fields: object) -> Property:
        fields["updated_at"] = datetime.now(tz=timezone.utc)

        # Coerce enum to its value if needed
        if "property_type" in fields and isinstance(fields["property_type"], PropertyType):
            fields["property_type"] = fields["property_type"].value  # type: ignore[assignment]

        await self._session.execute(
            update(PropertyModel)
            .where(PropertyModel.id == property_id)
            .values(**fields)
        )
        await self._session.flush()

        row = await self._session.get(PropertyModel, property_id)
        if row is None:
            raise RuntimeError(f"Property {property_id} disappeared after update.")
        await self._session.refresh(row)
        return _model_to_entity(row)

    async def soft_delete(self, property_id: UUID) -> Property:
        return await self.update(property_id, is_active=False)
