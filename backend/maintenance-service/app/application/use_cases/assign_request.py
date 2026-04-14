"""Use case: assign a maintenance request to a vendor or staff member.

Creates a WorkOrder and transitions the request status to ASSIGNED.
"""

from __future__ import annotations

import logging
from datetime import date
from decimal import Decimal
from typing import Optional
from uuid import UUID

from app.domain.entities.maintenance import MaintenanceRequest, RequestStatus, WorkOrder
from app.domain.exceptions import (
    RequestNotAssignableError,
    RequestNotFoundError,
    VendorNotFoundError,
    WorkOrderAlreadyExistsError,
)
from app.domain.repositories.abstract_request_repository import AbstractRequestRepository
from app.domain.repositories.abstract_vendor_repository import AbstractVendorRepository
from app.domain.repositories.abstract_work_order_repository import AbstractWorkOrderRepository

logger = logging.getLogger(__name__)

# Statuses that allow assignment
_ASSIGNABLE_STATUSES = {RequestStatus.OPEN}


class AssignRequestUseCase:
    """Assign an OPEN request to a vendor or staff member; creates a WorkOrder."""

    def __init__(
        self,
        request_repo: AbstractRequestRepository,
        work_order_repo: AbstractWorkOrderRepository,
        vendor_repo: AbstractVendorRepository,
    ) -> None:
        self._request_repo = request_repo
        self._work_order_repo = work_order_repo
        self._vendor_repo = vendor_repo

    async def execute(
        self,
        *,
        request_id: UUID,
        vendor_id: Optional[UUID],
        assigned_staff_id: Optional[UUID],
        scheduled_date: Optional[date],
        estimated_cost: Optional[Decimal],
        work_notes: str,
    ) -> tuple[MaintenanceRequest, WorkOrder]:
        """
        Returns
        -------
        A tuple of (updated MaintenanceRequest, new WorkOrder).
        """
        # 1. Verify the request exists and is assignable
        request = await self._request_repo.get_by_id(request_id)
        if request is None:
            raise RequestNotFoundError(str(request_id))
        if request.status not in _ASSIGNABLE_STATUSES:
            raise RequestNotAssignableError(request.status.value)

        # 2. Validate vendor exists when provided
        if vendor_id is not None:
            vendor = await self._vendor_repo.get_by_id(vendor_id)
            if vendor is None:
                raise VendorNotFoundError(str(vendor_id))

        # 3. Ensure no work order exists yet
        existing = await self._work_order_repo.get_by_request_id(request_id)
        if existing is not None:
            raise WorkOrderAlreadyExistsError(str(request_id))

        # 4. Create the work order
        work_order = await self._work_order_repo.create(
            request_id=request_id,
            vendor_id=vendor_id,
            assigned_staff_id=assigned_staff_id,
            scheduled_date=scheduled_date,
            estimated_cost=estimated_cost,
            work_notes=work_notes,
        )

        # 5. Transition request status → ASSIGNED
        updated_request = await self._request_repo.update_status(
            request_id, RequestStatus.ASSIGNED
        )

        logger.info(
            "Request id=%s assigned; work_order id=%s vendor=%s staff=%s",
            request_id,
            work_order.id,
            vendor_id,
            assigned_staff_id,
        )
        return updated_request, work_order
