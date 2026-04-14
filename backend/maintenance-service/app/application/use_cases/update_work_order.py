"""Use case: update mutable fields on an existing work order."""

from __future__ import annotations

import logging
from datetime import date
from decimal import Decimal
from typing import Optional
from uuid import UUID

from app.domain.entities.maintenance import RequestStatus, WorkOrder
from app.domain.exceptions import RequestNotFoundError, WorkOrderNotFoundError
from app.domain.repositories.abstract_request_repository import AbstractRequestRepository
from app.domain.repositories.abstract_work_order_repository import AbstractWorkOrderRepository

logger = logging.getLogger(__name__)


class UpdateWorkOrderUseCase:
    """Update scheduling, cost estimate, notes, or vendor on a work order.

    Also transitions the request status to IN_PROGRESS when the work order is
    first meaningfully updated (i.e. status is still ASSIGNED).
    """

    def __init__(
        self,
        request_repo: AbstractRequestRepository,
        work_order_repo: AbstractWorkOrderRepository,
    ) -> None:
        self._request_repo = request_repo
        self._work_order_repo = work_order_repo

    async def execute(
        self,
        *,
        request_id: UUID,
        vendor_id: Optional[UUID] = None,
        assigned_staff_id: Optional[UUID] = None,
        scheduled_date: Optional[date] = None,
        estimated_cost: Optional[Decimal] = None,
        actual_cost: Optional[Decimal] = None,
        work_notes: Optional[str] = None,
    ) -> WorkOrder:
        # 1. Verify the request exists
        request = await self._request_repo.get_by_id(request_id)
        if request is None:
            raise RequestNotFoundError(str(request_id))

        # 2. Verify the work order exists
        work_order = await self._work_order_repo.get_by_request_id(request_id)
        if work_order is None:
            raise WorkOrderNotFoundError(f"request_id={request_id}")

        # 3. Apply updates
        updated = await self._work_order_repo.update(
            work_order.id,
            vendor_id=vendor_id,
            assigned_staff_id=assigned_staff_id,
            scheduled_date=scheduled_date,
            estimated_cost=estimated_cost,
            actual_cost=actual_cost,
            work_notes=work_notes,
        )

        # 4. Advance request to IN_PROGRESS if still at ASSIGNED
        if request.status == RequestStatus.ASSIGNED:
            await self._request_repo.update_status(request_id, RequestStatus.IN_PROGRESS)
            logger.info("Request id=%s advanced to IN_PROGRESS", request_id)

        logger.info("Work order id=%s updated for request id=%s", updated.id, request_id)
        return updated
