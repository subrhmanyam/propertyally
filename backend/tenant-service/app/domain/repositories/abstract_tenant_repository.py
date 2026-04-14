"""Abstract repository interface for Tenant entities."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Optional
from uuid import UUID

from app.domain.entities.tenant import Tenant, TenantStatus


class AbstractTenantRepository(ABC):
    """Contract that all concrete tenant repositories must satisfy."""

    @abstractmethod
    async def create(self, tenant: Tenant) -> Tenant:
        """Persist a new tenant and return the saved entity."""
        ...

    @abstractmethod
    async def get_by_id(self, tenant_id: UUID) -> Optional[Tenant]:
        """Return a tenant by primary key, or None if not found."""
        ...

    @abstractmethod
    async def get_by_user_id(self, user_id: UUID) -> Optional[Tenant]:
        """Return the tenant associated with a given user account."""
        ...

    @abstractmethod
    async def update(self, tenant: Tenant) -> Tenant:
        """Persist changes to an existing tenant and return the updated entity."""
        ...

    @abstractmethod
    async def list_by_property(
        self,
        property_id: UUID,
        status: Optional[TenantStatus],
        offset: int,
        limit: int,
    ) -> tuple[list[Tenant], int]:
        """Return a paginated list of tenants for a property, plus total count."""
        ...

    @abstractmethod
    async def list_all(
        self,
        status: Optional[TenantStatus],
        offset: int,
        limit: int,
    ) -> tuple[list[Tenant], int]:
        """Return a paginated list of all tenants (optionally filtered by status)."""
        ...
