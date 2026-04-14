"""Abstract repository interface for Lease entities."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Optional
from uuid import UUID

from app.domain.entities.tenant import Lease, LeaseStatus


class AbstractLeaseRepository(ABC):
    """Contract that all concrete lease repositories must satisfy."""

    @abstractmethod
    async def create(self, lease: Lease) -> Lease:
        """Persist a new lease and return the saved entity."""
        ...

    @abstractmethod
    async def get_by_id(self, lease_id: UUID) -> Optional[Lease]:
        """Return a lease by primary key, or None if not found."""
        ...

    @abstractmethod
    async def get_active_by_tenant(self, tenant_id: UUID) -> Optional[Lease]:
        """Return the currently ACTIVE lease for a tenant, or None."""
        ...

    @abstractmethod
    async def get_latest_by_tenant(self, tenant_id: UUID) -> Optional[Lease]:
        """Return the most-recently-created lease for a tenant, or None."""
        ...

    @abstractmethod
    async def list_by_tenant(self, tenant_id: UUID) -> list[Lease]:
        """Return all leases for a tenant, ordered by start_date descending."""
        ...

    @abstractmethod
    async def update(self, lease: Lease) -> Lease:
        """Persist changes to an existing lease and return the updated entity."""
        ...

    @abstractmethod
    async def count_active_by_tenant(self, tenant_id: UUID) -> int:
        """Return the number of ACTIVE leases for a tenant (should be 0 or 1)."""
        ...
