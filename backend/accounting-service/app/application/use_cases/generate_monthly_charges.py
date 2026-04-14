"""Use case: GenerateMonthlyRentCharges.

Fetches active leases from the Tenant Service and bulk-inserts RentCharge
records for the requested month/year.  Uses ON CONFLICT DO NOTHING semantics
at the repository layer to safely handle re-runs.
"""

from __future__ import annotations

import logging
import uuid
from datetime import date
from decimal import Decimal

import httpx

from app.config import get_settings
from app.domain.entities.accounting import ChargeStatus, RentCharge
from app.domain.exceptions import TenantServiceUnavailableError
from app.domain.repositories.abstract_charge_repository import AbstractChargeRepository

logger = logging.getLogger(__name__)


class GenerateMonthlyCharges:
    """Bulk-create rent charges for all active leases in a property for a given month."""

    def __init__(self, charge_repo: AbstractChargeRepository) -> None:
        self._charge_repo = charge_repo

    async def execute(
        self,
        property_id: uuid.UUID,
        month: int,
        year: int,
        token: str,
    ) -> list[RentCharge]:
        """
        1. Call Tenant Service to get active leases for the property.
        2. Bulk-insert RentCharge records (idempotent on tenant+month+year).
        3. Return the list of created/existing charges.
        """
        settings = get_settings()
        leases = await self._fetch_active_leases(
            settings.tenant_service_url, property_id, token
        )

        if not leases:
            logger.info(
                "No active leases found for property %s %d/%d", property_id, month, year
            )
            return []

        # Determine due date: first of the given month/year
        due_date = date(year, month, 1)

        charges: list[RentCharge] = []
        for lease in leases:
            charge = RentCharge(
                id=uuid.uuid4(),
                tenant_id=uuid.UUID(lease["tenant_id"]),
                unit_id=uuid.UUID(lease["unit_id"]),
                property_id=property_id,
                amount=Decimal(str(lease["monthly_rent"])),
                due_date=due_date,
                period_month=month,
                period_year=year,
                status=ChargeStatus.PENDING,
                created_at=date.today(),  # type: ignore[arg-type]
            )
            charges.append(charge)

        saved = await self._charge_repo.bulk_insert(charges)
        logger.info(
            "Generated %d rent charges for property %s %d/%d",
            len(saved),
            property_id,
            month,
            year,
        )
        return saved

    async def _fetch_active_leases(
        self,
        tenant_service_url: str,
        property_id: uuid.UUID,
        token: str,
    ) -> list[dict]:  # type: ignore[type-arg]
        url = f"{tenant_service_url}/api/v1/leases"
        params = {"property_id": str(property_id), "status": "ACTIVE"}
        headers = {"Authorization": f"Bearer {token}"}

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(url, params=params, headers=headers)
                response.raise_for_status()
                data = response.json()
                return data.get("items", data) if isinstance(data, dict) else data
        except httpx.HTTPStatusError as exc:
            logger.error("Tenant service returned %s: %s", exc.response.status_code, exc)
            raise TenantServiceUnavailableError() from exc
        except httpx.RequestError as exc:
            logger.error("Could not reach tenant service: %s", exc)
            raise TenantServiceUnavailableError() from exc
