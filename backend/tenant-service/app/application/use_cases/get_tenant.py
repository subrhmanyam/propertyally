"""Use case: GetTenant — fetch full tenant profile with current lease."""

from __future__ import annotations

import logging
from uuid import UUID

from app.domain.entities.tenant import TenantWithLease
from app.domain.exceptions import TenantNotFoundError
from app.domain.repositories.abstract_document_repository import AbstractDocumentRepository
from app.domain.repositories.abstract_lease_repository import AbstractLeaseRepository
from app.domain.repositories.abstract_tenant_repository import AbstractTenantRepository

logger = logging.getLogger(__name__)


class GetTenantUseCase:
    """Return a tenant's full profile including current active lease and documents."""

    def __init__(
        self,
        tenant_repo: AbstractTenantRepository,
        lease_repo: AbstractLeaseRepository,
        document_repo: AbstractDocumentRepository,
    ) -> None:
        self._tenant_repo = tenant_repo
        self._lease_repo = lease_repo
        self._document_repo = document_repo

    async def execute(self, tenant_id: UUID) -> TenantWithLease:
        tenant = await self._tenant_repo.get_by_id(tenant_id)
        if tenant is None:
            raise TenantNotFoundError(str(tenant_id))

        current_lease = await self._lease_repo.get_active_by_tenant(tenant_id)
        documents = await self._document_repo.list_by_tenant(tenant_id)

        logger.debug(
            "get_tenant tenant_id=%s has_active_lease=%s",
            tenant_id,
            current_lease is not None,
        )
        return TenantWithLease(
            tenant=tenant,
            current_lease=current_lease,
            documents=documents,
        )
