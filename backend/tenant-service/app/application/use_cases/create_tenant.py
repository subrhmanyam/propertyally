"""Use case: CreateTenant — persist a new tenant profile."""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass
from datetime import date, datetime, timezone

from app.domain.entities.tenant import EmergencyContact, Tenant, TenantStatus
from app.domain.repositories.abstract_tenant_repository import AbstractTenantRepository

logger = logging.getLogger(__name__)


@dataclass
class CreateTenantInput:
    user_id: uuid.UUID
    unit_id: uuid.UUID
    property_id: uuid.UUID
    first_name: str
    last_name: str
    email: str
    phone: str
    date_of_birth: date
    ssn_last_four: str
    emergency_contact: EmergencyContact
    move_in_date: date


class CreateTenantUseCase:
    """Create a new tenant profile after application approval."""

    def __init__(self, tenant_repo: AbstractTenantRepository) -> None:
        self._tenant_repo = tenant_repo

    async def execute(self, data: CreateTenantInput) -> Tenant:
        now = datetime.now(tz=timezone.utc)
        tenant = Tenant(
            id=uuid.uuid4(),
            user_id=data.user_id,
            unit_id=data.unit_id,
            property_id=data.property_id,
            first_name=data.first_name,
            last_name=data.last_name,
            email=data.email,
            phone=data.phone,
            date_of_birth=data.date_of_birth,
            ssn_last_four=data.ssn_last_four,
            emergency_contact=data.emergency_contact,
            move_in_date=data.move_in_date,
            status=TenantStatus.ACTIVE,
            created_at=now,
            updated_at=now,
        )
        saved = await self._tenant_repo.create(tenant)
        logger.info("tenant.created tenant_id=%s user_id=%s", saved.id, saved.user_id)
        return saved
