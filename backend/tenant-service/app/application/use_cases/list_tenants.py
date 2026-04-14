"""Use case: ListTenants — paginated, filterable by property_id and status."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Optional
from uuid import UUID

from app.domain.entities.tenant import Tenant, TenantStatus
from app.domain.repositories.abstract_tenant_repository import AbstractTenantRepository

logger = logging.getLogger(__name__)


@dataclass
class ListTenantsInput:
    property_id: Optional[UUID] = None
    status: Optional[TenantStatus] = None
    offset: int = 0
    limit: int = 20


@dataclass
class ListTenantsOutput:
    tenants: list[Tenant]
    total: int
    offset: int
    limit: int


class ListTenantsUseCase:
    """Return a paginated, optionally-filtered list of tenants."""

    def __init__(self, tenant_repo: AbstractTenantRepository) -> None:
        self._tenant_repo = tenant_repo

    async def execute(self, data: ListTenantsInput) -> ListTenantsOutput:
        if data.property_id is not None:
            tenants, total = await self._tenant_repo.list_by_property(
                property_id=data.property_id,
                status=data.status,
                offset=data.offset,
                limit=data.limit,
            )
        else:
            tenants, total = await self._tenant_repo.list_all(
                status=data.status,
                offset=data.offset,
                limit=data.limit,
            )

        logger.debug(
            "list_tenants property_id=%s status=%s count=%d",
            data.property_id,
            data.status,
            len(tenants),
        )
        return ListTenantsOutput(
            tenants=tenants,
            total=total,
            offset=data.offset,
            limit=data.limit,
        )
