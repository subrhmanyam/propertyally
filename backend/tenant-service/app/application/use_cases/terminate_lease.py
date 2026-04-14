"""Use case: TerminateLease — mark a lease TERMINATED and set unit VACANT."""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from uuid import UUID

import httpx

from app.config import get_settings
from app.domain.entities.tenant import Lease, LeaseStatus, TenantStatus
from app.domain.exceptions import (
    ExternalServiceError,
    InvalidLeaseTransitionError,
    LeaseNotFoundError,
    TenantNotFoundError,
)
from app.domain.repositories.abstract_lease_repository import AbstractLeaseRepository
from app.domain.repositories.abstract_tenant_repository import AbstractTenantRepository

logger = logging.getLogger(__name__)

_TERMINABLE_STATUSES = {LeaseStatus.ACTIVE, LeaseStatus.DRAFT}


class TerminateLeaseUseCase:
    """Terminate a lease and notify property-service to set the unit VACANT."""

    def __init__(
        self,
        tenant_repo: AbstractTenantRepository,
        lease_repo: AbstractLeaseRepository,
        http_client: httpx.AsyncClient,
    ) -> None:
        self._tenant_repo = tenant_repo
        self._lease_repo = lease_repo
        self._http = http_client

    async def execute(self, tenant_id: UUID, lease_id: UUID) -> Lease:
        tenant = await self._tenant_repo.get_by_id(tenant_id)
        if tenant is None:
            raise TenantNotFoundError(str(tenant_id))

        lease = await self._lease_repo.get_by_id(lease_id)
        if lease is None or lease.tenant_id != tenant_id:
            raise LeaseNotFoundError(str(lease_id))

        if lease.status not in _TERMINABLE_STATUSES:
            raise InvalidLeaseTransitionError(lease.status.value, LeaseStatus.TERMINATED.value)

        now = datetime.now(tz=timezone.utc)
        lease.status = LeaseStatus.TERMINATED
        lease.updated_at = now
        updated = await self._lease_repo.update(lease)

        # Update tenant status and move-out date
        tenant.status = TenantStatus.PAST
        tenant.move_out_date = now.date()
        tenant.updated_at = now
        await self._tenant_repo.update(tenant)

        logger.info("lease.terminated lease_id=%s tenant_id=%s", lease_id, tenant_id)

        await self._notify_property_service(lease.unit_id)
        return updated

    async def _notify_property_service(self, unit_id: UUID) -> None:
        settings = get_settings()
        url = f"{settings.property_service_url}/api/v1/units/{unit_id}/status"
        try:
            response = await self._http.patch(url, json={"status": "VACANT"}, timeout=10.0)
            response.raise_for_status()
            logger.info("property-service notified: unit %s set VACANT", unit_id)
        except httpx.HTTPStatusError as exc:
            logger.error(
                "property-service returned %s for unit %s: %s",
                exc.response.status_code,
                unit_id,
                exc.response.text,
            )
            raise ExternalServiceError(
                "property-service", f"HTTP {exc.response.status_code}"
            ) from exc
        except httpx.RequestError as exc:
            logger.error("property-service request failed for unit %s: %s", unit_id, exc)
            raise ExternalServiceError("property-service", str(exc)) from exc
