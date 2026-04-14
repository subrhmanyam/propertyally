"""Abstract repository interface for WorkOrder persistence."""

from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import date, datetime
from decimal import Decimal
from typing import Optional
from uuid import UUID

from app.domain.entities.maintenance import WorkOrder


class AbstractWorkOrderRepository(ABC):
    @abstractmethod
    async def get_by_id(self, work_order_id: UUID) -> Optional[WorkOrder]:
        """Return a work order by primary key, or None."""
        ...

    @abstractmethod
    async def get_by_request_id(self, request_id: UUID) -> Optional[WorkOrder]:
        """Return the work order associated with a given request, or None."""
        ...

    @abstractmethod
    async def create(
        self,
        *,
        request_id: UUID,
        vendor_id: Optional[UUID],
        assigned_staff_id: Optional[UUID],
        scheduled_date: Optional[date],
        estimated_cost: Optional[Decimal],
        work_notes: str,
    ) -> WorkOrder:
        """Persist a new work order and return the created entity."""
        ...

    @abstractmethod
    async def update(
        self,
        work_order_id: UUID,
        *,
        vendor_id: Optional[UUID] = None,
        assigned_staff_id: Optional[UUID] = None,
        scheduled_date: Optional[date] = None,
        estimated_cost: Optional[Decimal] = None,
        actual_cost: Optional[Decimal] = None,
        work_notes: Optional[str] = None,
        completion_photos: Optional[list[str]] = None,
        completed_at: Optional[datetime] = None,
        approved_at: Optional[datetime] = None,
        approved_by: Optional[UUID] = None,
    ) -> WorkOrder:
        """Update specified fields on a work order and return the updated entity."""
        ...
