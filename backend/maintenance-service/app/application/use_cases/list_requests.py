"""Use case: list maintenance requests with optional filters and pagination."""

from __future__ import annotations

import logging
from typing import Optional
from uuid import UUID

from app.domain.entities.maintenance import MaintenanceRequest, Priority, RequestStatus
from app.domain.repositories.abstract_request_repository import AbstractRequestRepository

logger = logging.getLogger(__name__)


class ListRequestsUseCase:
    """Return a paginated, filtered list of maintenance requests."""

    def __init__(self, request_repo: AbstractRequestRepository) -> None:
        self._request_repo = request_repo

    async def execute(
        self,
        *,
        property_id: Optional[UUID] = None,
        status: Optional[RequestStatus] = None,
        priority: Optional[Priority] = None,
        tenant_id: Optional[UUID] = None,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[MaintenanceRequest], int]:
        """
        Returns
        -------
        A tuple of (list of matching requests, total count ignoring pagination).
        """
        items, total = await self._request_repo.list_requests(
            property_id=property_id,
            status=status,
            priority=priority,
            tenant_id=tenant_id,
            offset=offset,
            limit=limit,
        )
        logger.debug(
            "ListRequests property=%s status=%s priority=%s — %d/%d returned",
            property_id,
            status,
            priority,
            len(items),
            total,
        )
        return items, total
