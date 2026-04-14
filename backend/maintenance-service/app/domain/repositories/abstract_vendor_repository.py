"""Abstract repository interface for Vendor persistence."""

from __future__ import annotations

from abc import ABC, abstractmethod
from decimal import Decimal
from typing import Optional
from uuid import UUID

from app.domain.entities.maintenance import Vendor


class AbstractVendorRepository(ABC):
    @abstractmethod
    async def get_by_id(self, vendor_id: UUID) -> Optional[Vendor]:
        """Return a vendor by primary key, or None."""
        ...

    @abstractmethod
    async def create(
        self,
        *,
        name: str,
        contact_name: str,
        email: str,
        phone: str,
        trade: str,
    ) -> Vendor:
        """Persist a new vendor and return the created entity."""
        ...

    @abstractmethod
    async def update(
        self,
        vendor_id: UUID,
        *,
        name: Optional[str] = None,
        contact_name: Optional[str] = None,
        email: Optional[str] = None,
        phone: Optional[str] = None,
        trade: Optional[str] = None,
        is_active: Optional[bool] = None,
        rating: Optional[Decimal] = None,
    ) -> Vendor:
        """Update specified fields on a vendor and return the updated entity."""
        ...

    @abstractmethod
    async def list_vendors(
        self,
        *,
        trade: Optional[str] = None,
        is_active: Optional[bool] = None,
        offset: int = 0,
        limit: int = 50,
    ) -> tuple[list[Vendor], int]:
        """Return a page of vendors matching the given filters plus the total count."""
        ...
