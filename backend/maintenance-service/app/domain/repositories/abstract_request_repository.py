"""Abstract repository interface for MaintenanceRequest persistence."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Optional
from uuid import UUID

from app.domain.entities.maintenance import (
    MaintenanceCategory,
    MaintenanceRequest,
    Priority,
    RequestStatus,
)


class AbstractRequestRepository(ABC):
    @abstractmethod
    async def get_by_id(self, request_id: UUID) -> Optional[MaintenanceRequest]:
        """Return a request by primary key, or None."""
        ...

    @abstractmethod
    async def create(
        self,
        *,
        unit_id: UUID,
        property_id: UUID,
        tenant_id: Optional[UUID],
        title: str,
        description: str,
        category: MaintenanceCategory,
        priority: Priority,
        photos: list[str],
    ) -> MaintenanceRequest:
        """Persist a new maintenance request and return the created entity."""
        ...

    @abstractmethod
    async def update_status(self, request_id: UUID, status: RequestStatus) -> MaintenanceRequest:
        """Update the status of a request and return the updated entity."""
        ...

    @abstractmethod
    async def update_photos(self, request_id: UUID, photos: list[str]) -> MaintenanceRequest:
        """Replace the photos list on a request and return the updated entity."""
        ...

    @abstractmethod
    async def list_requests(
        self,
        *,
        property_id: Optional[UUID] = None,
        status: Optional[RequestStatus] = None,
        priority: Optional[Priority] = None,
        tenant_id: Optional[UUID] = None,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[MaintenanceRequest], int]:
        """Return a page of requests matching the given filters plus the total count."""
        ...
