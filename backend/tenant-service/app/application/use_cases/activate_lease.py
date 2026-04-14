"""Use case: ActivateLease — mark a DRAFT lease ACTIVE and set unit OCCUPIED."""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from uuid import UUID

import httpx

from app.config import get_settings
from app.domain.entities.tenant import Lease, LeaseStatus
from app.domain.exceptions import (
    ExternalServiceError,
    InvalidLeaseTransitionError,
    LeaseNotFoundError,
    TenantNotFoundError,
)
from app.domain.repositories.abstract_lease_repository import AbstractLeaseRepository
from app.domain.repositories.abstract_tenant_repository import AbstractTenantRepository

logger = logging.getLogger(__name__)


class ActivateLeaseUseCase:
    """Activate a DRAFT lease and notify property-service to set unit OCCUPIED."""

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

        if lease.status != LeaseStatus.DRAFT:
            raise InvalidLeaseTransitionError(lease.status.value, LeaseStatus.ACTIVE.value)

        now = datetime.now(tz=timezone.utc)
        lease.status = LeaseStatus.ACTIVE
        lease.signed_at = now
        lease.updated_at = now

        updated = await self._lease_repo.update(lease)
        logger.info("lease.activated lease_id=%s tenant_id=%s", lease_id, tenant_id)

        await self._notify_property_service(lease.unit_id)
        return updated

    async def _notify_property_service(self, unit_id: UUID) -> None:
        settings = get_settings()
        url = f"{settings.property_service_url}/api/v1/units/{unit_id}/status"
        try:
            response = await self._http.patch(url, json={"status": "OCCUPIED"}, timeout=10.0)
            response.raise_for_status()
            logger.info("property-service notified: unit %s set OCCUPIED", unit_id)
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
