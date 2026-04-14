"""Use case: CreateLease — create a DRAFT lease for a tenant."""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass
from datetime import date, datetime, timezone
from decimal import Decimal
from typing import Optional
from uuid import UUID

from app.domain.entities.tenant import Lease, LeaseStatus
from app.domain.exceptions import ActiveLeaseExistsError, TenantNotFoundError
from app.domain.repositories.abstract_lease_repository import AbstractLeaseRepository
from app.domain.repositories.abstract_tenant_repository import AbstractTenantRepository

logger = logging.getLogger(__name__)


@dataclass
class CreateLeaseInput:
    tenant_id: UUID
    unit_id: UUID
    start_date: date
    end_date: date
    monthly_rent: Decimal
    deposit_paid: Decimal
    lease_document_url: Optional[str] = None


class CreateLeaseUseCase:
    """Create a DRAFT lease.  Rejects if an ACTIVE lease already exists."""

    def __init__(
        self,
        tenant_repo: AbstractTenantRepository,
        lease_repo: AbstractLeaseRepository,
    ) -> None:
        self._tenant_repo = tenant_repo
        self._lease_repo = lease_repo

    async def execute(self, data: CreateLeaseInput) -> Lease:
        tenant = await self._tenant_repo.get_by_id(data.tenant_id)
        if tenant is None:
            raise TenantNotFoundError(str(data.tenant_id))

        active_count = await self._lease_repo.count_active_by_tenant(data.tenant_id)
        if active_count > 0:
            raise ActiveLeaseExistsError(str(data.tenant_id))

        now = datetime.now(tz=timezone.utc)
        lease = Lease(
            id=uuid.uuid4(),
            tenant_id=data.tenant_id,
            unit_id=data.unit_id,
            start_date=data.start_date,
            end_date=data.end_date,
            monthly_rent=data.monthly_rent,
            deposit_paid=data.deposit_paid,
            status=LeaseStatus.DRAFT,
            lease_document_url=data.lease_document_url,
            created_at=now,
            updated_at=now,
        )
        saved = await self._lease_repo.create(lease)
        logger.info("lease.created lease_id=%s tenant_id=%s status=DRAFT", saved.id, saved.tenant_id)
        return saved
