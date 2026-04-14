"""Use case: manager approves a completed work order.

Sets the request status to COMPLETED and notifies the accounting service to log
the actual cost as an expense entry.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from uuid import UUID

import httpx

from app.config import get_settings
from app.domain.entities.maintenance import RequestStatus, WorkOrder
from app.domain.exceptions import (
    AccountingServiceError,
    RequestNotFoundError,
    WorkOrderNotFoundError,
)
from app.domain.repositories.abstract_request_repository import AbstractRequestRepository
from app.domain.repositories.abstract_work_order_repository import AbstractWorkOrderRepository

logger = logging.getLogger(__name__)


class ApproveCompletionUseCase:
    """Approve a completed work order and log the expense in the accounting service."""

    def __init__(
        self,
        request_repo: AbstractRequestRepository,
        work_order_repo: AbstractWorkOrderRepository,
    ) -> None:
        self._request_repo = request_repo
        self._work_order_repo = work_order_repo

    async def execute(self, *, request_id: UUID, approved_by: UUID) -> WorkOrder:
        settings = get_settings()

        # 1. Verify request and work order
        request = await self._request_repo.get_by_id(request_id)
        if request is None:
            raise RequestNotFoundError(str(request_id))

        work_order = await self._work_order_repo.get_by_request_id(request_id)
        if work_order is None:
            raise WorkOrderNotFoundError(f"request_id={request_id}")

        now = datetime.now(tz=timezone.utc)

        # 2. Stamp approval on work order
        updated = await self._work_order_repo.update(
            work_order.id,
            approved_by=approved_by,
            approved_at=now,
        )

        # 3. Transition request → COMPLETED
        await self._request_repo.update_status(request_id, RequestStatus.COMPLETED)

        # 4. Notify accounting service to log actual cost as an expense
        if updated.actual_cost is not None:
            await self._log_expense_to_accounting(
                settings=settings,
                request=request,
                work_order=updated,
            )

        logger.info(
            "Work order id=%s approved by manager=%s; request id=%s COMPLETED",
            work_order.id,
            approved_by,
            request_id,
        )
        return updated

    @staticmethod
    async def _log_expense_to_accounting(
        settings: object,
        request: object,
        work_order: WorkOrder,
    ) -> None:
        """POST the maintenance expense to the accounting service."""
        from app.config import Settings  # avoid circular at module level

        cfg: Settings = settings  # type: ignore[assignment]
        payload = {
            "property_id": str(request.property_id),  # type: ignore[attr-defined]
            "unit_id": str(request.unit_id),  # type: ignore[attr-defined]
            "work_order_id": str(work_order.id),
            "request_id": str(work_order.request_id),
            "amount": str(work_order.actual_cost),
            "description": (
                f"Maintenance work order #{work_order.id} — "
                f"{request.title}"  # type: ignore[attr-defined]
            ),
            "category": "MAINTENANCE",
        }
        url = f"{cfg.accounting_service_url}/api/v1/expenses"
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.post(url, json=payload)
                response.raise_for_status()
            logger.info(
                "Logged maintenance expense amount=%s to accounting service",
                work_order.actual_cost,
            )
        except httpx.HTTPStatusError as exc:
            logger.error("Accounting service returned %s: %s", exc.response.status_code, exc)
            raise AccountingServiceError(
                f"HTTP {exc.response.status_code}: {exc.response.text}"
            ) from exc
        except httpx.RequestError as exc:
            logger.error("Could not reach accounting service: %s", exc)
            raise AccountingServiceError(str(exc)) from exc
